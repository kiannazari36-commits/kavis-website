import UIKit
import Supabase

/// The profile photo: a small JPEG in the private bucket `avatars` (`<user id>/avatar.jpg`, path saved in
/// `profiles.avatar_path`). The phone keeps a copy so screens show it at once.
enum AvatarAPI {
    private static var cacheURL: URL? {
        guard let id = supabase.auth.currentUser?.id else { return nil }
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("avatar-\(id.uuidString.lowercased()).jpg")
    }

    /// The phone's copy.
    static func cached() -> UIImage? { cacheURL.flatMap { try? Data(contentsOf: $0) }.flatMap(UIImage.init(data:)) }

    /// The account's photo from the server (kept on the phone); the phone's copy when offline or none is set.
    static func fetch() async -> UIImage? {
        guard let id = supabase.auth.currentUser?.id else { return nil }
        struct Row: Decodable { let avatar_path: String? }
        let rows: [Row] = (try? await supabase.from("profiles").select("avatar_path").eq("id", value: id).limit(1).execute().value) ?? []
        guard let path = rows.first?.avatar_path, !path.isEmpty else {
            if let url = cacheURL { try? FileManager.default.removeItem(at: url) }
            return nil
        }
        guard let data = try? await supabase.storage.from("avatars").download(path: path), let image = UIImage(data: data) else { return cached() }
        if let url = cacheURL { try? data.write(to: url) }
        return image
    }

    /// Makes the photo square (center) and small (512 px), saves it and returns it; nil when it failed.
    static func upload(_ original: UIImage) async -> UIImage? {
        guard let id = supabase.auth.currentUser?.id else { return nil }
        let side = min(original.size.width, original.size.height)
        let target = CGSize(width: 512, height: 512)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let small = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            let scale = 512 / side
            let drawn = CGSize(width: original.size.width * scale, height: original.size.height * scale)
            original.draw(in: CGRect(x: (512 - drawn.width) / 2, y: (512 - drawn.height) / 2, width: drawn.width, height: drawn.height))
        }
        guard let data = small.jpegData(compressionQuality: 0.85) else { return nil }
        let path = "\(id.uuidString.lowercased())/avatar.jpg"
        do {
            _ = try await supabase.storage.from("avatars").upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
            struct Update: Encodable { let avatar_path: String }
            _ = try await supabase.from("profiles").update(Update(avatar_path: path)).eq("id", value: id).execute()
        } catch { return nil }
        if let url = cacheURL { try? data.write(to: url) }
        return small
    }
}
