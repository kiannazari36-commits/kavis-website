import SwiftUI

/// The assistant's answer: plain text, and markdown tables ("| a | b |" lines) the assistant writes when the student
/// asks for a table or "cetvel". Same rules as the web (`web/src/components/AnswerText.tsx`): a table is shown as a
/// real table (sideways scroll when it is wide); the |---| line is dropped.
enum AnswerPart: Equatable {
    case text(String)
    case table(head: [String], rows: [[String]])

    static func split(_ text: String) -> [AnswerPart] {
        let isRow = { (l: Substring) in l.trimmingCharacters(in: .whitespaces).hasPrefix("|") }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var parts: [AnswerPart] = []
        var i = 0
        while i < lines.count {
            var block: [Substring] = []
            if isRow(lines[i]) {
                while i < lines.count, isRow(lines[i]) { block.append(lines[i]); i += 1 }
                let rows = block.filter { $0.range(of: #"^\s*\|?\s*:?-{2,}"#, options: .regularExpression) == nil }.map(cells)
                if rows.count >= 2 {
                    parts.append(.table(head: rows[0], rows: Array(rows.dropFirst())))
                } else {
                    parts.append(.text(block.joined(separator: "\n")))
                }
            } else {
                while i < lines.count, !isRow(lines[i]) { block.append(lines[i]); i += 1 }
                let t = block.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { parts.append(.text(t)) }
            }
        }
        return parts
    }

    private static func cells(_ line: Substring) -> [String] {
        var s = line.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("|") { s.removeFirst() }
        if s.hasSuffix("|") { s.removeLast() }
        return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

struct AnswerText: View {
    let text: String
    let lang: Lang

    var body: some View {
        let parts = AnswerPart.split(text)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                switch part {
                case .text(let s):
                    Text(s).font(KFont.ui(14, lang: lang)).kLineHeight(1.55, size: 14, lang: lang)
                case .table(let head, let rows):
                    table(head, rows)
                }
            }
        }
    }

    private func table(_ head: [String], _ rows: [[String]]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(head.indices, id: \.self) { k in
                        cell(head[k], bold: true).background(KPhone.line.opacity(0.55))
                    }
                }
                ForEach(rows.indices, id: \.self) { j in
                    Divider().overlay(KPhone.line)
                    GridRow {
                        ForEach(head.indices, id: \.self) { k in cell(k < rows[j].count ? rows[j][k] : "", bold: false) }
                    }
                }
            }
            .background(KPhone.card)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(KPhone.line, lineWidth: 1))
        }
    }

    private func cell(_ s: String, bold: Bool) -> some View {
        Text(s).font(KFont.ui(13, bold ? .semibold : .regular, lang: lang))
            .frame(minWidth: 70, maxWidth: 200, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10).padding(.vertical, 7)
    }
}
