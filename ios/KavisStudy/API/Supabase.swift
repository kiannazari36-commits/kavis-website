import Foundation
import Supabase

extension Notification.Name {
    /// The server answered 401 `session_ended`: another device signed this phone out.
    static let sessionEnded = Notification.Name("kavis.sessionEnded")
}

/// Passes every request on and looks at the answer: a 401 with `session_ended` (the device was signed out from
/// another device, see docs/BACKEND.md) tells the app to go back to the login screen at once.
final class SessionGuardProtocol: URLProtocol {
    private static let handled = "kavis.guarded"
    private static let inner = URLSession(configuration: .ephemeral)
    private var loading: URLSessionDataTask?

    override class func canInit(with request: URLRequest) -> Bool {
        URLProtocol.property(forKey: handled, in: request) == nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let marked = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else { return }
        URLProtocol.setProperty(true, forKey: Self.handled, in: marked)
        loading = Self.inner.dataTask(with: marked as URLRequest) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode == 401,
               let data, String(data: data, encoding: .utf8)?.contains("session_ended") == true {
                NotificationCenter.default.post(name: .sessionEnded, object: nil)
            }
            if let response { self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed) }
            if let data { self.client?.urlProtocol(self, didLoad: data) }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        loading?.resume()
    }

    override func stopLoading() { loading?.cancel() }
}

private let guardedSession: URLSession = {
    let c = URLSessionConfiguration.default
    c.protocolClasses = [SessionGuardProtocol.self]
    return URLSession(configuration: c)
}()

/// The one Supabase client of the app: the same backend as the web (auth, tables with Row Level Security,
/// storage, Edge Functions). The session is kept in the Keychain by the client and refreshed by itself.
let supabase = SupabaseClient(
    supabaseURL: Config.supabaseURL,
    supabaseKey: Config.supabaseKey,
    options: SupabaseClientOptions(global: .init(session: guardedSession))
)
