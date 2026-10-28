import SwiftUI

/// The two bottom sheets of the upload design (design/ScrUpload.dc.html): "Deneme süresinde 2 ders hakkın doldu" when the
/// trial's lessons are used, and the Premium "adil kullanım" notice after the 40th lesson of the subscription month.
private struct LimitSheet<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0x140E0A, opacity: 0.45).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(Color.pair(0xE2D7C6, 0x4A403A)).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.bottom, 18)
                content
            }
            .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 26)
            .frame(maxWidth: 560)
            .background {
                let shape = UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous)
                shape.fill(KPhone.card).overlay(shape.stroke(KPhone.line, lineWidth: 1)).ignoresSafeArea(edges: .bottom)
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .transition(.opacity)
    }
}

struct TrialLimitSheet: View {
    @Environment(AppPrefs.self) private var prefs
    var onLater: () -> Void
    var onPremium: () -> Void

    var body: some View {
        let lang = prefs.lang
        let n = Format.num(TrialLimits.pdfs, lang)
        LimitSheet(onClose: onLater) {
            KIcon(name: .lock, size: 24).foregroundStyle(KPhone.tile1Text)
                .frame(width: 52, height: 52).background(KPhone.tile1, in: Circle()).padding(.bottom, 14)
            Text(prefs.t("trialSheetT", ["n": n])).font(KFont.ui(21, .bold, lang: lang)).foregroundStyle(KPhone.text).padding(.bottom, 6)
            Text(prefs.t("trialSheetD", ["n": n])).font(KFont.ui(14.5, lang: lang)).kLineHeight(1.5, size: 14.5, lang: lang)
                .foregroundStyle(KPhone.text2).padding(.bottom, 18)
            Button(action: onPremium) {
                Text(prefs.t("goPremium")).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                    .frame(maxWidth: .infinity, minHeight: 54).background(KPhone.cta, in: Capsule())
            }
            Button(action: onLater) {
                Text(prefs.t("trialLater")).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text2)
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
        }
    }
}

struct FairUseSheet: View {
    @Environment(AppPrefs.self) private var prefs
    let used: Int
    /// ISO day the count restarts ("2026-11-12").
    let resetsOn: String?
    var onClose: () -> Void
    @State private var infoOpen = false

    private var dateText: String {
        guard let resetsOn else { return "" }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: resetsOn) else { return resetsOn }
        let out = DateFormatter()
        out.locale = prefs.lang.locale
        out.setLocalizedDateFormatFromTemplate("d MMMM")
        return out.string(from: date)
    }

    var body: some View {
        let lang = prefs.lang
        LimitSheet(onClose: onClose) {
            Text(prefs.t("fairT", ["n": Format.num(TrialLimits.fairLessons, lang)])).font(KFont.ui(21, .bold, lang: lang)).foregroundStyle(KPhone.text).padding(.bottom, 6)
            Text(prefs.t("fairD", ["date": dateText])).font(KFont.ui(14.5, lang: lang)).kLineHeight(1.5, size: 14.5, lang: lang)
                .foregroundStyle(KPhone.text2).padding(.bottom, 12)
            Button { withAnimation(.easeOut(duration: 0.2)) { infoOpen.toggle() } } label: {
                HStack(spacing: 6) {
                    Text(prefs.t("fairWhat")).font(KFont.ui(14, .medium, lang: lang))
                    KIcon(name: .chevronDown, size: 14, width: 2).rotationEffect(.degrees(infoOpen ? 180 : 0))
                }
                .foregroundStyle(KPhone.brand)
            }
            .padding(.bottom, infoOpen ? 8 : 18)
            if infoOpen {
                Text(prefs.t("fairInfo", ["n": Format.num(TrialLimits.fairLessons, lang)])).font(KFont.ui(13, lang: lang)).kLineHeight(1.5, size: 13, lang: lang)
                    .foregroundStyle(KPhone.text2).padding(.bottom, 18)
            }
            Button(action: onClose) {
                Text(prefs.t("fairOk")).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                    .frame(maxWidth: .infinity, minHeight: 54).background(KPhone.cta, in: Capsule())
            }
        }
    }
}
