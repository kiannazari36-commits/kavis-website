import Foundation
import Network
import Observation
import Supabase

/// Settings "Çalıştığım PDF'leri indir" (decided with Kian, 5 Nov 2026): while the app is open and the switch is on, the
/// lessons the student studies come to the phone ahead, newest first, so they open without internet: the lessons opened
/// at least once (on any device, the web too) and the ones uploaded in the last 14 days. Per lesson: the reading page and
/// hard words, the original PDF, the pen notes, the cards and the summary already made (no AI call, nothing paid).
/// Only on Wi-Fi without Low Data Mode, unless the student allows mobile data (kept on this device): then on any network.
/// Everything is written through OfflineStore (one copy, 1 GB limit); with the switch off nothing new comes.
@MainActor @Observable
final class OfflineSync {
    static let shared = OfflineSync()

    /// full: 1 GB or the phone is full; offline: no internet; metered: mobile data or Low Data Mode, not allowed.
    enum Pause: Equatable { case full, offline, metered }

    private(set) var running = false
    private(set) var done = 0
    private(set) var total = 0
    /// Why the last run stopped before every lesson was on the phone (nil: all there, or nothing to do).
    private(set) var paused: Pause?
    /// Goes up whenever lessons were added, so the screens showing "CİHAZDA" read the list again.
    private(set) var revision = 0

    /// "Mobil veriyle de indir": also download ahead on mobile data (off = only Wi-Fi). This phone only.
    var cellular = UserDefaults.standard.bool(forKey: "kavis.offlineCellular") {
        didSet { UserDefaults.standard.set(cellular, forKey: "kavis.offlineCellular"); start() }
    }

    private let monitor = NWPathMonitor()
    private var path: NWPath?

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.path = path
                self?.start()
            }
        }
        monitor.start(queue: DispatchQueue(label: "kavis.offlineSync"))
    }

    /// Download ahead may use this network: mobile data (expensive) or Low Data Mode (constrained) only when allowed.
    nonisolated static func networkAllows(connected: Bool, expensive: Bool, constrained: Bool, cellularAllowed: Bool) -> Bool {
        connected && (cellularAllowed || (!expensive && !constrained))
    }

    /// nil: this network may be used now; else why not.
    private var networkPause: Pause? {
        guard let path, path.status == .satisfied else { return .offline }
        return Self.networkAllows(connected: true, expensive: path.isExpensive, constrained: path.isConstrained,
                                  cellularAllowed: cellular) ? nil : .metered
    }

    /// Starts a run when allowed (sign-in, app back in front, network change, switch turned on); a second call while one
    /// runs does nothing.
    func start() {
        guard !running, supabase.auth.currentUser != nil else { return }
        let settings = SettingsAPI.loadNow()
        guard settings.autoDownload, !settings.offlineMode, MockFlag.value("offline") != "1" else { paused = nil; return }
        if let pause = networkPause { paused = pause; return }
        running = true
        Task { await run() }
    }

    private func run() async {
        defer { running = false }
        guard let ids = await Self.candidates() else { return }
        let missing = ids.filter { !OfflineStore.isComplete($0) }
        total = ids.count
        done = ids.count - missing.count
        paused = nil
        for id in missing {
            guard SettingsAPI.loadNow().autoDownload, supabase.auth.currentUser != nil else { return }
            if let pause = networkPause { paused = pause; return }
            if !OfflineStore.has(id),
               !OfflineStore.mayAddLesson(enabled: true, usedBytes: OfflineStore.totalBytes(), freeBytes: OfflineStore.freeBytes()) {
                paused = .full
                return
            }
            if await Self.download(id) {
                done += 1
                revision += 1
            }
        }
    }

    /// One lesson: false when the server did not answer (tried again on the next run).
    private static func download(_ id: String) async -> Bool {
        guard await ReaderAPI.getLesson(id: id, group: false) != nil else { return false }
        _ = await ReaderAPI.pdfData(materialId: id)
        _ = await InkAPI.load(materialId: id, surface: .card)
        _ = await InkAPI.load(materialId: id, surface: .pdf)
        await SummaryAPI.keepSaved(materialId: id)
        return await CardsAPI.keepDeck(materialId: id)
    }

    /// The student's lessons to keep, newest first; nil when the server cannot be reached.
    private static func candidates() async -> [String]? {
        guard let data = try? await supabase.from("materials")
            .select("id, kind, status, created_at, reading_progress(updated_at)").eq("status", value: "ready").execute().data,
              let rows = try? JSONDecoder().decode([Candidate].self, from: data) else { return nil }
        return pick(rows)
    }

    struct Candidate: Decodable {
        struct Progress: Decodable { let updated_at: String }
        let id: String
        let kind: String
        let created_at: String
        let reading_progress: [Progress]?
    }

    /// Opened lessons (by last reading) and PDF / photo lessons uploaded in the last 14 days (by upload), newest first.
    nonisolated static func pick(_ rows: [Candidate], now: Date = Date()) -> [String] {
        let recent = ISO8601DateFormatter.string(from: now.addingTimeInterval(-14 * 86_400), timeZone: .gmt,
                                                 formatOptions: [.withInternetDateTime])
        return rows.compactMap { r -> (id: String, at: String)? in
            if let read = r.reading_progress?.map(\.updated_at).max() { return (r.id.lowercased(), max(read, r.created_at)) }
            if ["pdf", "photo"].contains(r.kind), r.created_at >= recent { return (r.id.lowercased(), r.created_at) }
            return nil
        }
        .sorted { $0.at > $1.at }
        .map(\.id)
    }
}
