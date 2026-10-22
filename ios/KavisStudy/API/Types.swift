import Foundation

/// A text in all four interface languages (same as `L10n` in web/src/api/types.ts).
struct L10n: Codable, Hashable {
    let tr: String
    let en: String
    let fa: String
    let ar: String

    subscript(lang: Lang) -> String {
        switch lang {
        case .tr: tr
        case .en: en
        case .fa: fa
        case .ar: ar
        }
    }
}

enum CourseColor: String, Codable {
    case red, amb, vio, grn, teal
}

struct Pdf: Codable, Identifiable, Hashable {
    let id: String
    let title: L10n
    /// Percent read, 0–100.
    let read: Int
    /// Minutes studied.
    let minutes: Int
    let pages: Int
}

struct Course: Codable, Identifiable, Hashable {
    let id: String
    let name: L10n
    /// Shorter name for tight places.
    let short: L10n?
    let color: CourseColor
    /// Language of the course PDFs (the teacher's material). Never translated unless the student asks.
    let language: Lang
    let exam: L10n
    /// ISO date of the next exam.
    let examDate: String?
    /// Rank among classmates.
    let rank: Int
    let pdfs: [Pdf]
}

/// A Premium plan. No price: Apple sets the local price per country and the app reads it from the App Store.
struct PremiumPlan: Codable, Identifiable, Hashable {
    let id: String
    let title: L10n
    let tag: L10n?
}

/// One row of the trial-vs-Premium table: feature, trial value, Premium value.
typealias CompareRow = [L10n]
