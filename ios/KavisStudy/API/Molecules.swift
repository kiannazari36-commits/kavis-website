import Foundation

/// The molecule library of the reader (copied from the web by `ios/scripts/export-molecules.mjs`). A molecule
/// shows up under a page block when its name is in the page text.
struct Molecule: Decodable, Identifiable {
    struct Atom: Decodable {
        let x: Double, y: Double
        let element: String
        let label: String?

        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            x = try c.decode(Double.self)
            y = try c.decode(Double.self)
            element = try c.decode(String.self)
            label = c.isAtEnd ? nil : try c.decode(String.self)
        }
    }

    struct Bond: Decodable {
        let from: String, to: String
        /// 2 = double bond.
        let order: Int

        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            from = try c.decode(String.self)
            to = try c.decode(String.self)
            order = c.isAtEnd ? 1 : ((try? c.decode(Int.self)) ?? 1)
        }
    }

    struct Group: Decodable, Identifiable {
        let id: String
        let name: [String: String]
        let atoms: [String]
        let note: [String: String]
    }

    let id: String
    let name: [String: String]
    let formula: String
    let mw: [String: String]
    let cls: [String: String]
    let atoms: [String: Atom]
    let bonds: [Bond]
    let center: [Double]?
    let groups: [Group]
    let match: String
    let matchFlags: String

    func text(_ dict: [String: String], _ lang: Lang) -> String { dict[lang.rawValue] ?? dict["en"] ?? "" }
}

enum MoleculeLibrary {
    private final class BundleToken {}

    static let all: [Molecule] = {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "molecules", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Molecule].self, from: data) else { return [] }
        return list
    }()

    /// The molecules a page text talks about.
    static func find(in text: String) -> [Molecule] {
        all.filter { m in
            (try? NSRegularExpression(pattern: m.match, options: m.matchFlags.contains("i") ? [.caseInsensitive] : []))
                .map { $0.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil } ?? false
        }
    }
}
