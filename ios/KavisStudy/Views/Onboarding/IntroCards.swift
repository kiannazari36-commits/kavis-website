import SwiftUI

// The three illustrations of the onboarding intro (design/ScrOnboarding.dc.html). Drawn in a 342 × 360 card.

/// "Hocanın metni, hiç değişmeden": a PDF page and the card made from it.
struct IntroPdfCard: View {
    @Environment(AppPrefs.self) private var prefs

    var body: some View {
        let lang = prefs.lang
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 9) {
                Text("PDF").font(KFont.mono(10, .semibold)).foregroundStyle(KPhone.ctaText)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(KOnb.pri, in: RoundedRectangle(cornerRadius: 4))
                ForEach([(8.0, 0.8), (6, 0.95), (6, 0.88), (6, 0.92), (6, 0.6)], id: \.1) { height, width in
                    GeometryReader { g in
                        RoundedRectangle(cornerRadius: height / 2).fill(KPhone.line).frame(width: g.size.width * width, height: height)
                    }
                    .frame(height: height)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.vertical, 18)
            .frame(width: 170, height: 230)
            .background(KPhone.sub, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(KPhone.line, lineWidth: 1))
            .rotationEffect(.degrees(-7))
            .offset(x: 34, y: 46)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(prefs.d("SAYFA 5")).font(KFont.mono(10, .regular)).foregroundStyle(KOnb.text3)
                    Spacer()
                    Text(prefs.d("Dikkat")).font(KFont.ui(10, .semibold, lang: lang)).foregroundStyle(KOnb.ambText)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(KOnb.ambSoft, in: RoundedRectangle(cornerRadius: 4))
                }
                (Text("\(prefs.d("Sistolik KB ≥140 mmHg ve/veya diyastolik KB ≥90 mmHg olması")) ")
                    + Text(prefs.d("hipertansiyon")).underline(pattern: .dot, color: KOnb.priText)
                    + Text(" \(prefs.d("olarak tanımlanır."))"))
                    .font(KFont.reading(13, lang: lang))
                    .kLineHeight(1.5, size: 13, lang: lang)
                    .foregroundStyle(KPhone.text)
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(14)
            .frame(width: 200)
            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(KPhone.line, lineWidth: 1))
            .shadow(color: Color(hex: 0x1B2430, opacity: 0.14), radius: 15, y: 12)
            .rotationEffect(.degrees(3))
            .offset(x: 342 - 200 - 26, y: 92)
        }
        .frame(width: 342, height: 360, alignment: .topLeading)
    }
}

/// "Dokun, anla, çevir": a hard term and its pop-up with the translations.
struct IntroTermCard: View {
    @Environment(AppPrefs.self) private var prefs

    var body: some View {
        let lang = prefs.lang
        VStack(alignment: .leading, spacing: 10) {
            (Text("\(prefs.d("Alfa-1 blokerlerin ilk dozundan sonra")) ")
                + Text(prefs.d("Ortostatik hipotansiyon")).underline(pattern: .dot, color: KOnb.priText).foregroundColor(KPhone.text)
                + Text(" \(prefs.d("görülebilir."))"))
                .font(KFont.reading(16, lang: lang))
                .kLineHeight(1.6, size: 16, lang: lang)
                .foregroundStyle(KPhone.text)
            VStack(alignment: .leading, spacing: 6) {
                Text(prefs.d("TERİM · KLİNİK BULGU")).font(KFont.mono(10, .regular)).tracking(0.8).foregroundStyle(KOnb.text3)
                Text(prefs.d("Ortostatik hipotansiyon")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                Text(prefs.d("Ayağa kalkınca kan basıncının ani düşmesi; baş dönmesi, bayılma."))
                    .font(KFont.ui(12, lang: lang)).kLineHeight(1.5, size: 12, lang: lang).foregroundStyle(KPhone.text2)
                HStack(spacing: 6) {
                    ForEach(["EN", "FA", "AR"], id: \.self) { code in
                        Text(code).font(KFont.mono(11, .regular)).foregroundStyle(KPhone.text)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(KPhone.sub, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(KPhone.line, lineWidth: 1))
            .shadow(color: Color(hex: 0x1B2430, opacity: 0.16), radius: 17, y: 14)
            .padding(.leading, 40)
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 24)
        .padding(.top, 34)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// "Sına, tekrar et, unutma": score ring, review calendar and the three answer buttons.
struct IntroProgressCard: View {
    @Environment(AppPrefs.self) private var prefs

    var body: some View {
        let lang = prefs.lang
        ZStack(alignment: .topLeading) {
            ZStack {
                Circle().stroke(KPhone.sub, lineWidth: 12)
                Circle().trim(from: 0, to: 306.0 / 364.0)
                    .stroke(KOnb.pri, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("84").font(KFont.ui(34, .bold, lang: .en)).foregroundStyle(KPhone.text)
                    Text("/100").font(KFont.mono(11, .regular)).foregroundStyle(KOnb.text3)
                }
            }
            .frame(width: 116, height: 116)
            .padding(12)
            .frame(width: 140, height: 140)
            .offset(x: 28, y: 40)

            Text("+13").font(KFont.ui(12, .semibold, lang: .en)).foregroundStyle(KOnb.ambText)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(KOnb.ambSoft, in: RoundedRectangle(cornerRadius: 6))
                .rotationEffect(.degrees(-6))
                .offset(x: 150, y: 44)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<21, id: \.self) { i in
                    let studied = [0, 1, 2, 4, 5, 6, 7, 8, 9, 11].contains(i)
                    Capsule().fill(i == 3 || i == 10 ? KColor.amb : (studied ? KOnb.text3 : KPhone.line))
                        .frame(height: 14)
                        .overlay(Capsule().stroke(i == 15 ? KOnb.bad : .clear, lineWidth: 2))
                }
            }
            .padding(12)
            .frame(width: 150)
            .background(KPhone.sub, in: RoundedRectangle(cornerRadius: 14))
            .rotationEffect(.degrees(4))
            .offset(x: 342 - 150 - 24, y: 70)

            HStack(spacing: 8) {
                answer(prefs.d("Bilmedim"), KOnb.badSoft, KOnb.bad, lang)
                answer(prefs.d("Zor"), KOnb.ambSoft, KOnb.ambText, lang)
                answer(prefs.d("Bildim"), KOnb.okSoft, KOnb.ok, lang)
            }
            .padding(.horizontal, 24)
            .frame(width: 342)
            .offset(y: 360 - 34 - 44)
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(width: 342, height: 360, alignment: .topLeading)
    }

    private func answer(_ text: String, _ bg: Color, _ fg: Color, _ lang: Lang) -> some View {
        Text(text).font(KFont.ui(13, .semibold, lang: lang)).foregroundStyle(fg)
            .lineLimit(1).minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(bg, in: RoundedRectangle(cornerRadius: 12))
    }
}
