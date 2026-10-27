import SwiftUI

/// Design: design/ScrCards.dc.html. Flip a card, then rate it (next review time). The cards due now are today's
/// round; "Bilmedim" and "Zor" come back at the end of the round (same as the web). Card text is in its deck's
/// language (the content language), the buttons in the app language.
struct CardsView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app

    var courseId: String?
    var materialId: String?

    @State private var queue: [FlashCard]?
    @State private var total = 0
    @State private var done = 0
    @State private var back = false
    @State private var stats = [0, 0, 0]

    private var lang: Lang { prefs.lang }
    private func t(_ key: String, _ vars: [String: String] = [:]) -> String { prefs.t(key, vars) }

    private enum C {
        static let bg = Color.pair(0xF4EFE6, 0x15120F)
        static let card = Color.pair(0xFFFCF6, 0x211C18)
        static let sub = Color.pair(0xF1EBE0, 0x2B2520)
        static let line = Color.pair(0xE6DDCF, 0x3A322B)
        static let text3 = Color.pair(0x776C60, 0x9A8F82)
        static let priText = Color.pair(0x9C2F3A, 0xF09AA3)
        static let ok = Color.pair(0x1E7A4C, 0x5BC893)
        static let okSoft = Color.pair(0xE2F3E9, 0x173328)
        static let bad = Color.pair(0xC0352B, 0xF27A70)
        static let badSoft = Color.pair(0xFCE8E6, 0x3D1F1F)
        static let amb = Color.pair(0x83560A, 0xF2C46E)
        static let ambSoft = Color.pair(0xFDF1D6, 0x3A2F1A)
    }

    private var card: FlashCard? { queue?.first }

    var body: some View {
        VStack(spacing: 0) {
            header
            if queue != nil {
                if let card { stage(card) } else { finished }
            } else {
                Spacer()
            }
        }
        .padColumn()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(C.bg.ignoresSafeArea())
        .task {
            guard queue == nil else { return }
            let cards = await CardsAPI.dueCards(courseId: courseId, materialId: materialId)
            queue = cards
            total = cards.count
        }
        .animation(.easeInOut(duration: 0.2), value: back)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button { app.back() } label: {
                    KIcon(name: .close, size: 22, width: 1.8).foregroundStyle(KPhone.text).frame(width: 44, height: 44)
                }
                .accessibilityLabel(prefs.d("Kapat"))
                .padding(.leading, -10)
                VStack(spacing: 1) {
                    Text(t("cardsTitle")).font(KFont.ui(15, .bold, lang: lang)).foregroundStyle(KPhone.text)
                    if let deck = card?.deck, !deck.isEmpty {
                        Text(deck.uppercased(with: card?.lang.locale)).font(KFont.mono(10, .regular)).tracking(0.8).foregroundStyle(C.text3).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                Text("\(Format.num(min(done + 1, total), lang))/\(Format.num(total, lang))")
                    .font(KFont.mono(12, .regular)).foregroundStyle(KPhone.text2).frame(minWidth: 34, alignment: .trailing)
            }
            .frame(height: 44)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(C.line)
                    Capsule().fill(Color(hex: 0x9C2F3A)).frame(width: g.size.width * (total > 0 ? CGFloat(done) / CGFloat(total) : 1))
                }
            }
            .frame(height: 6)
            .accessibilityLabel("\(done)/\(total)")
            HStack(spacing: 12) {
                Text("● \(t("rateNo")) \(Format.num(stats[0], lang))").foregroundStyle(C.bad)
                Text("● \(t("rateHard")) \(Format.num(stats[1], lang))").foregroundStyle(C.amb)
                Text("● \(t("rateYes")) \(Format.num(stats[2], lang))").foregroundStyle(C.ok)
            }
            .font(KFont.mono(11, .regular))
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
        .padding(.top, KLayout.top(54, minimum: 6))
    }

    // MARK: Card

    private func stage(_ card: FlashCard) -> some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous).fill(C.card).opacity(0.45)
                    .frame(maxWidth: 300, maxHeight: 420).rotationEffect(.degrees(4)).offset(y: 18)
                RoundedRectangle(cornerRadius: 26, style: .continuous).fill(C.card).opacity(0.7)
                    .frame(maxWidth: 318, maxHeight: 430).rotationEffect(.degrees(-2.5)).offset(y: 9)
                Button { back.toggle() } label: { face(card) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(prefs.d("Kartı çevir"))
            }
            .padding(.horizontal, 24).padding(.vertical, 8)
            .frame(maxHeight: .infinity)
            VStack(spacing: 10) {
                if back {
                    HStack(spacing: 10) {
                        rateButton(.again, label: t("rateNo"), next: t("rateNoT"), bg: C.badSoft, fg: C.bad)
                        rateButton(.hard, label: t("rateHard"), next: t("rateHardT"), bg: C.ambSoft, fg: C.amb)
                        rateButton(.good, label: t("rateYes"), next: t("daysN", ["n": Format.num(CardsAPI.goodInterval(card), lang)]), bg: C.okSoft, fg: C.ok)
                    }
                } else {
                    Button { back = true } label: {
                        Text(t("showAnswer")).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color(hex: 0x9C2F3A), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 12)
        }
    }

    private var pageText: String? {
        card?.page.map { "\(prefs.d("S.")) \(Format.num($0, lang))" }
    }

    private func face(_ card: FlashCard) -> some View {
        let cl = card.lang
        return VStack(spacing: 14) {
            if back {
                Text(t("sideA")).font(KFont.mono(11, .regular)).tracking(1.1).foregroundStyle(C.ok)
                Text(card.question).font(KFont.reading(15, lang: cl)).foregroundStyle(C.text3).multilineTextAlignment(.center)
                    .environment(\.layoutDirection, cl.layoutDirection)
                Rectangle().fill(C.line).frame(height: 1)
                VStack(spacing: 14) {
                    Text(card.a).font(KFont.ui(card.a.count > 40 ? 20 : 30, .bold, lang: cl)).foregroundStyle(C.priText)
                        .multilineTextAlignment(.center).minimumScaleFactor(0.6)
                    if !card.note.isEmpty {
                        Text(card.note).font(KFont.reading(16, lang: cl)).kLineHeight(1.55, size: 16, lang: cl).foregroundStyle(KPhone.text2)
                            .multilineTextAlignment(.center)
                    }
                }
                .environment(\.layoutDirection, cl.layoutDirection)
                .frame(maxHeight: .infinity)
                if let pageText {
                    Text("PDF · \(pageText)").font(KFont.mono(11, .regular)).foregroundStyle(KPhone.text2)
                        .padding(.horizontal, 10).padding(.vertical, 5).background(C.sub, in: RoundedRectangle(cornerRadius: 6))
                }
            } else {
                Text([t("sideQ"), pageText].compactMap { $0 }.joined(separator: " · "))
                    .font(KFont.mono(11, .regular)).tracking(1.1).foregroundStyle(C.text3)
                VStack(spacing: 12) {
                    Text(card.question).font(KFont.reading(23, .medium, lang: cl)).kLineHeight(1.45, size: 23, lang: cl)
                        .multilineTextAlignment(.center).minimumScaleFactor(0.6)
                    if !card.options.isEmpty {
                        Text(card.options).font(KFont.reading(16, lang: cl)).kLineHeight(1.5, size: 16, lang: cl)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .foregroundStyle(KPhone.text)
                .environment(\.layoutDirection, cl.layoutDirection)
                .frame(maxHeight: .infinity)
                HStack(spacing: 8) {
                    KIcon(name: .refresh, size: 18, width: 1.6)
                    Text(t("tapToSee")).font(KFont.ui(13, lang: lang))
                }
                .foregroundStyle(C.text3)
            }
        }
        .padding(24)
        .frame(maxWidth: 330, maxHeight: 440)
        .background(C.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(C.line, lineWidth: 1))
        .shadow(color: Color(hex: 0x1B2430, opacity: 0.12), radius: 20, y: 18)
    }

    private func rateButton(_ rating: CardRating, label: String, next: String, bg: Color, fg: Color) -> some View {
        Button { rate(rating) } label: {
            VStack(spacing: 2) {
                Text(label).font(KFont.ui(15, .bold, lang: lang))
                Text("\(next) \(t("later"))").font(KFont.mono(11, .regular)).opacity(0.85).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// Saves the rating; "Bilmedim" and "Zor" go to the end of today's round.
    private func rate(_ rating: CardRating) {
        guard var q = queue, !q.isEmpty else { return }
        var card = q.removeFirst()
        Task { await CardsAPI.rate(card, rating) }
        stats[rating == .again ? 0 : rating == .hard ? 1 : 2] += 1
        if rating == .good {
            done += 1
        } else {
            card.reps = 0
            if rating == .again { card.intervalDays = 0 }
            q.append(card)
        }
        queue = q
        back = false
    }

    private var finished: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(t("cardsDone")).font(KFont.reading(21, .medium, lang: lang)).foregroundStyle(KPhone.text)
                .multilineTextAlignment(.center)
                .padding(32).frame(maxWidth: 330)
                .background(C.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(C.line, lineWidth: 1))
            Spacer()
            Button { app.reset(to: .home) } label: {
                Text(t("k47")).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color(hex: 0x9C2F3A), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
    }
}
