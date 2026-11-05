import Foundation
import Supabase

/// The phone's own copy of what a lesson needs without internet (CLAUDE.md: offline use in every plan): the original
/// PDF, the reader's lesson data, the handwritten notes and the highlights. Kept per account in Application Support
/// (`offline/<user id>/`, not in the iCloud backup); written when a lesson is opened online or downloaded ahead
/// (`OfflineSync`, Settings "Çalıştığım PDF'leri indir"), read when the server cannot be reached, and removed at sign-out.
/// With that switch off no new lesson is kept; the lessons already on the phone stay and keep their copy up to date.
enum OfflineStore {
    /// At most this much for all kept lessons together (decided 5 Nov 2026), and never when the phone has less free space.
    static let limitBytes = 1_000_000_000
    static let reserveBytes: Int64 = 1_000_000_000

    private static var folder: URL? {
        guard let uid = supabase.auth.currentUser?.id.uuidString.lowercased() else { return nil }
        return root.appendingPathComponent(uid, isDirectory: true)
    }

    private static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("offline", isDirectory: true)
    }

    private static func url(_ name: String) -> URL? { folder?.appendingPathComponent(name) }

    static func read(_ name: String) -> Data? {
        guard let url = url(name) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Every kept file whose name starts with `prefix` ("cards-": the card decks of all kept lessons).
    static func readAll(prefix: String) -> [Data] {
        guard let folder, let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.lastPathComponent.hasPrefix(prefix) }.compactMap { try? Data(contentsOf: $0) }
    }

    static func write(_ data: Data, _ name: String) {
        guard let folder, let url = url(name) else { return }
        if let id = lessonId(name), !has(id),
           !mayAddLesson(enabled: SettingsAPI.loadNow().autoDownload, usedBytes: totalBytes(), freeBytes: freeBytes()) { return }
        do {
            if !FileManager.default.fileExists(atPath: folder.path) {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                var top = root
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try? top.setResourceValues(values)
            }
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            // No room or no account: the lesson simply needs internet next time.
        }
    }

    /// The original PDF of a lesson, kept after its first download (the teacher's file does not change).
    static func pdf(_ materialId: String) -> Data? { read("pdf-\(materialId).pdf") }
    static func savePdf(_ data: Data, _ materialId: String) { write(data, "pdf-\(materialId).pdf") }

    /// The lessons that open on this phone without internet (their reading page is kept), and what each takes in bytes.
    static func lessons() -> [(id: String, bytes: Int)] {
        let all = sizes()
        return all.keys.filter { read("lesson-\($0).json") != nil }.sorted().map { ($0, all[$0] ?? 0) }
    }

    /// Bytes per lesson id of every kept file (a summary or note may be kept before the reading page).
    private static func sizes() -> [String: Int] {
        guard let folder,
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey]) else { return [:] }
        var sizes: [String: Int] = [:]
        for f in files {
            guard let id = lessonId(f.lastPathComponent) else { continue }
            sizes[id, default: 0] += (try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        return sizes
    }

    /// A new lesson may be kept only with the switch on, under the 1 GB limit and with enough free space on the phone.
    static func mayAddLesson(enabled: Bool, usedBytes: Int, freeBytes: Int64?) -> Bool {
        enabled && usedBytes < limitBytes && (freeBytes ?? .max) >= reserveBytes
    }

    /// Some copy of this lesson is on the phone.
    static func has(_ materialId: String) -> Bool {
        sizes()[materialId.lowercased()] != nil
    }

    /// The lesson is fully downloaded ahead: reading page and cards (the PDF and notes come in the same step).
    static func isComplete(_ materialId: String) -> Bool {
        read("lesson-\(materialId).json") != nil && read("cards-\(materialId).json") != nil
    }

    /// Bytes of every kept lesson of this account.
    static func totalBytes() -> Int { sizes().values.reduce(0, +) }

    /// Free space on the phone for important data (nil when unknown).
    static func freeBytes() -> Int64? {
        try? root.deletingLastPathComponent().resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
    }

    /// "pdf-<id>.pdf", "lesson-<id>.json", "ink-<id>.json", "ink-<id>-pdf.json", "marks-<id>…", "cards-<id>.json",
    /// "summary-<id>.json" → the lesson id.
    static func lessonId(_ name: String) -> String? {
        for prefix in ["pdf-", "lesson-", "ink-", "marks-", "cards-", "summary-"] where name.hasPrefix(prefix) {
            let rest = name.dropFirst(prefix.count)
            guard rest.count >= 36 else { return nil }
            return String(rest.prefix(36)).lowercased()
        }
        return nil
    }

    /// Removes one lesson's copy (the lesson itself stays in the account and opens again online).
    static func remove(_ materialId: String) {
        guard let folder, let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        for f in files where lessonId(f.lastPathComponent) == materialId.lowercased() { try? FileManager.default.removeItem(at: f) }
    }

    /// Removes the copies of every lesson of this account (sign-out of other accounts is `removeAll`).
    static func removeLessons() {
        guard let folder else { return }
        try? FileManager.default.removeItem(at: folder)
    }

    /// Every account's copies (sign-out, account deleted): the next person on this device sees nothing.
    static func removeAll() {
        try? FileManager.default.removeItem(at: root)
    }
}
