import Foundation
import PencilKit
import Supabase

/// Handwritten notes on the PDF pages (Apple Pencil or finger): one drawing per page, saved as an `annotations` row
/// of kind `ink`; the drawing itself is a small JSON file in the private bucket `ink` (`<user id>/<lesson>/<page>.json`).
enum InkAPI {
    private struct Row: Decodable { let id: String; let page: Int; let ink_path: String? }
    private struct File: Codable { let drawing: Data }

    /// Every saved drawing of a lesson, by page.
    static func load(materialId: String) async -> [Int: PKDrawing] {
        let rows: [Row] = (try? await supabase.from("annotations").select("id, page, ink_path")
            .eq("material_id", value: materialId).eq("kind", value: "ink").execute().value) ?? []
        var result: [Int: PKDrawing] = [:]
        for row in rows {
            guard let path = row.ink_path,
                  let data = try? await supabase.storage.from("ink").download(path: path),
                  let file = try? JSONDecoder().decode(File.self, from: data),
                  let drawing = try? PKDrawing(data: file.drawing) else { continue }
            result[row.page] = drawing
        }
        return result
    }

    /// Saves (or replaces) the drawing of one page; an empty drawing removes the row.
    static func save(materialId: String, page: Int, drawing: PKDrawing) async {
        guard let uid = supabase.auth.currentUser?.id.uuidString.lowercased() else { return }
        let existing: [Row] = (try? await supabase.from("annotations").select("id, page, ink_path")
            .eq("material_id", value: materialId).eq("kind", value: "ink").eq("page", value: page).limit(1).execute().value) ?? []
        if drawing.strokes.isEmpty {
            if let row = existing.first {
                _ = try? await supabase.from("annotations").delete().eq("id", value: row.id).execute()
                if let path = row.ink_path { _ = try? await supabase.storage.from("ink").remove(paths: [path]) }
            }
            return
        }
        let path = "\(uid)/\(materialId)/\(page).json"
        guard let body = try? JSONEncoder().encode(File(drawing: drawing.dataRepresentation())) else { return }
        guard (try? await supabase.storage.from("ink").upload(path, data: body, options: FileOptions(contentType: "application/json", upsert: true))) != nil else { return }
        if let row = existing.first {
            struct Touch: Encodable { let ink_path: String }
            _ = try? await supabase.from("annotations").update(Touch(ink_path: path)).eq("id", value: row.id).execute()
        } else {
            struct New: Encodable { let user_id: String; let material_id: String; let page: Int; let kind = "ink"; let ink_path: String }
            _ = try? await supabase.from("annotations").insert(New(user_id: uid, material_id: materialId, page: page, ink_path: path)).execute()
        }
    }
}
