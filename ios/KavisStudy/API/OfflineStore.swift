import Foundation
import Supabase

/// The phone's own copy of what a lesson needs without internet (CLAUDE.md: offline use in every plan): the original
/// PDF, the reader's lesson data and the handwritten notes. Kept per account in Application Support
/// (`offline/<user id>/`, not in the iCloud backup); written when a lesson is opened online, read when the server
/// cannot be reached, and removed at sign-out.
enum OfflineStore {
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

    static func write(_ data: Data, _ name: String) {
        guard let folder, let url = url(name) else { return }
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

    /// Every account's copies (sign-out, account deleted): the next person on this device sees nothing.
    static func removeAll() {
        try? FileManager.default.removeItem(at: root)
    }
}
