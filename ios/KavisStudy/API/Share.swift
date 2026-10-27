import Foundation
import Supabase

/// A share link (`<web address>/s/<slug>`, or `kavis://s/<slug>`): what the app made of a lesson (summary, cards,
/// quiz), never the PDF. Premium only: the Edge Function `open-share` keeps the receipt and, for a Premium
/// receiver, copies the lesson into their account.
enum ShareAPI {
    enum Result: Equatable {
        case opened(materialId: String)
        case needsPremium
        case notFound
        case failed
    }

    /// The slug of a share link, or nil when the address is something else.
    static func slug(in url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        let viaScheme = url.scheme == "kavis" && url.host == "s" ? parts.first : nil
        let viaWeb = parts.count == 2 && parts[0] == "s" && url.host?.contains("kavis") == true ? parts[1] : nil
        return viaScheme ?? viaWeb
    }

    static func open(slug: String) async -> Result {
        struct Body: Encodable { let slug: String }
        struct Answer: Decodable { let premium: Bool?; let own: Bool?; let material_id: String? }
        do {
            let a: Answer = try await supabase.functions.invoke("open-share", options: FunctionInvokeOptions(body: Body(slug: slug)))
            if a.premium == false { return .needsPremium }
            if let id = a.material_id { return .opened(materialId: id) }
            return .failed
        } catch let FunctionsError.httpError(code, _) where code == 404 {
            return .notFound
        } catch {
            return .failed
        }
    }
}
