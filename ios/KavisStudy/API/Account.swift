import Foundation
import Supabase

struct Profile: Codable, Equatable {
    var name: String
    var email: String
    var school: String
    /// Department as the design writes it in Turkish ("Eczacılık"); shown through `prefs.d(...)`.
    var department: String = ""
    var year: Int?
}

/// The student's profile (table profiles, the same as the web; the email comes from the login).
/// The phone keeps a copy so screens open at once; `fetchProfile` refreshes it from the server.
enum AccountAPI {
    private static let profileKey = "kavis.profile"

    /// The phone's copy, or one made from the login.
    static func loadProfile(for user: User?) -> Profile {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let saved = try? JSONDecoder().decode(Profile.self, from: data),
           saved.email == (user?.email ?? saved.email) { return saved }
        return Profile(name: user?.name ?? "", email: user?.email ?? "", school: "")
    }

    private static func cache(_ p: Profile) {
        if let data = try? JSONEncoder().encode(p) { UserDefaults.standard.set(data, forKey: profileKey) }
    }

    private struct Row: Codable { let full_name: String; let school: String?; let department: String?; let class_year: Int? }

    /// The profile from the server (kept on the phone), or the phone's copy when offline.
    static func fetchProfile(for user: User?) async -> Profile {
        guard let id = supabase.auth.currentUser?.id,
              let rows: [Row] = try? await supabase.from("profiles").select("full_name, school, department, class_year").eq("id", value: id).limit(1).execute().value,
              let r = rows.first
        else { return loadProfile(for: user) }
        let p = Profile(name: r.full_name, email: user?.email ?? "", school: r.school ?? "", department: r.department ?? "", year: r.class_year)
        cache(p)
        return p
    }

    /// Name, school, department and class year (the email is changed through the login, on the web for now).
    static func saveProfile(_ p: Profile) async -> Profile {
        cache(p)
        guard let id = supabase.auth.currentUser?.id else { return p }
        struct Update: Encodable { let full_name: String; let school: String?; let department: String?; let class_year: Int? }
        let name = p.name.trimmingCharacters(in: .whitespaces)
        let school = p.school.trimmingCharacters(in: .whitespaces)
        _ = try? await supabase.from("profiles")
            .update(Update(full_name: name, school: school.isEmpty ? nil : school, department: p.department.isEmpty ? nil : p.department, class_year: p.year))
            .eq("id", value: id).execute()
        // Keep the login's name in step, so the home screen shows it.
        _ = try? await supabase.auth.update(user: UserAttributes(data: ["full_name": .string(name)]))
        return p
    }

    /// The first steps are done (profiles.onboarding_done); also keeps the app language in the account.
    static func finishOnboarding(lang: Lang) async {
        guard let id = supabase.auth.currentUser?.id else { return }
        struct Update: Encodable { let onboarding_done: Bool; let app_lang: String }
        _ = try? await supabase.from("profiles").update(Update(onboarding_done: true, app_lang: lang.rawValue)).eq("id", value: id).execute()
    }

    /// The app language saved in the account (nil when offline).
    static func fetchLang() async -> Lang? {
        guard let id = supabase.auth.currentUser?.id else { return nil }
        struct Row: Decodable { let app_lang: String }
        let rows: [Row]? = try? await supabase.from("profiles").select("app_lang").eq("id", value: id).limit(1).execute().value
        return rows?.first.flatMap { Lang(rawValue: $0.app_lang) }
    }

    /// The app language in the account (notifications and emails use it).
    static func saveLang(_ lang: Lang) async {
        guard let id = supabase.auth.currentUser?.id else { return }
        struct Update: Encodable { let app_lang: String }
        _ = try? await supabase.from("profiles").update(Update(app_lang: lang.rawValue)).eq("id", value: id).execute()
    }

    /// Forget the phone's copy (after logging out).
    static func clear() { UserDefaults.standard.removeObject(forKey: profileKey) }

    /// "Hesap bilgilerimi iste": the account's data from the server (Edge Function export-data, the same as the web),
    /// saved as a JSON file the student can keep or send (share sheet). nil when it could not be made.
    static func requestMyData() async -> URL? {
        guard let data: Data = try? await supabase.functions.invoke("export-data", options: FunctionInvokeOptions(body: [String: String]()), decode: { data, _ in data })
        else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let day = f.string(from: Date())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kavis-study-\(day).json")
        guard (try? data.write(to: url)) != nil else { return nil }
        return url
    }

    /// The day the account will be deleted (a deletion was asked for), or nil.
    static func deletionDate() async -> Date? {
        guard let id = supabase.auth.currentUser?.id else { return nil }
        struct Row: Decodable { let scheduled_for: String }
        let rows: [Row] = (try? await supabase.from("account_requests").select("scheduled_for")
            .eq("user_id", value: id).eq("kind", value: "delete").eq("status", value: "confirmed").limit(1).execute().value) ?? []
        guard let iso = rows.first?.scheduled_for else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }

    /// "Vazgeç" within the 30 days: the account stays.
    static func cancelDeletion() async -> Bool {
        struct Body: Encodable { let action = "cancel" }
        struct Done: Decodable { let cancelled: Bool }
        let r: Done? = try? await supabase.functions.invoke("delete-account", options: FunctionInvokeOptions(body: Body()))
        return r?.cancelled == true
    }

    enum DeleteError: Error { case password, other }

    /// "Hesabı sil": the password is checked once more by the server (Edge Function delete-account), then the account
    /// is deleted in 30 days; until then it works as before and the deletion can be cancelled (the same as the web).
    /// Deleting the account does not cancel an Apple subscription; the student cancels it in the App Store.
    static func deleteAccount(password: String) async -> Result<Date, DeleteError> {
        struct Body: Encodable { let action = "request"; let password: String }
        struct Done: Decodable { let scheduled_for: String }
        do {
            let r: Done = try await supabase.functions.invoke("delete-account", options: FunctionInvokeOptions(body: Body(password: password)))
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return .success(f.date(from: r.scheduled_for) ?? Date().addingTimeInterval(30 * 86_400))
        } catch FunctionsError.httpError(code: 403, _) {
            return .failure(.password)
        } catch {
            return .failure(.other)
        }
    }
}
