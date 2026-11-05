import SwiftUI

/// True inside the iPad shell: the left rail replaces the phone's floating tab bar.
private struct PadRailKey: EnvironmentKey { static let defaultValue = false }

private struct PadFlowKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// True inside the iPad first-steps frame (PadFlowFrame).
    var padFlow: Bool {
        get { self[PadFlowKey.self] }
        set { self[PadFlowKey.self] = newValue }
    }

    var padRail: Bool {
        get { self[PadRailKey.self] }
        set { self[PadRailKey.self] = newValue }
    }
}

extension Route {
    /// Screens of the signed-in app that show the iPad rail (not the start, sign-in, first steps or full-screen sheets).
    var showsPadRail: Bool {
        switch self {
        case .splash, .welcome, .auth, .onboarding, .courseSetup, .deviceLimit, .paywall: false
        default: true
        }
    }

    /// Which rail button is lit (design NewIPad: "Derslerim" for everything under the lessons).
    var padTab: PadRail.Tab {
        switch self {
        case .weekPlan: .plan
        case .progress: .progress
        case .settings, .profile, .timetable: .settings
        // The assistant is not under a rail button (design NewIPad: none is lit there).
        case .assistant, .assistantChat: .none
        default: .home
        }
    }
}

/// Design: design/NewIPad.dc.html, the 88 pt left rail: the logotype, "Derslerim", "Ders planım", "İlerleme",
/// "Ayarlar", and the light / dark button at the bottom.
struct PadRail: View {
    enum Tab { case home, plan, progress, settings, none }

    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme

    private static let bg = Color.pair(0xFFFCF6, 0x2B2520)
    private static let line = Color.pair(0xE6DDCF, 0x3A322B)
    private static let text2 = Color.pair(0x6E645A, 0xBDB2A4)

    private var items: [(Tab, KIconName, String, Route)] {
        [(.home, .book, prefs.d("Derslerim"), .home),
         (.plan, .calendar, prefs.d("Ders planım"), .weekPlan),
         (.progress, .chart, prefs.d("İlerleme"), .progress),
         (.settings, .sliders, prefs.d("Ayarlar"), .settings)]
    }

    var body: some View {
        let dark = scheme == .dark
        VStack(spacing: 10) {
            Wordmark(size: 17).padding(.bottom, 14).environment(\.layoutDirection, .leftToRight)
            ForEach(items, id: \.2) { tab, icon, label, route in
                let on = app.route.padTab == tab
                Button {
                    if app.route != route { app.reset(to: route) }
                } label: {
                    KIcon(name: icon, size: 22, width: 1.6)
                        .foregroundStyle(on ? KPhone.ctaText : Self.text2)
                        .frame(width: 56, height: 56)
                        .background(on ? Color(hex: 0x9C2F3A) : Self.bg, in: Circle())
                        .overlay(Circle().stroke(on ? .clear : Self.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            Spacer()
            Button { toggleTheme(dark) } label: {
                KIcon(name: dark ? .sun : .moon, size: 20, width: 1.7)
                    .foregroundStyle(Self.text2)
                    .frame(width: 48, height: 48)
                    .background(Self.bg, in: Circle())
                    .overlay(Circle().stroke(Self.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(prefs.t(dark ? "padLight" : "padDark"))
            .padding(.bottom, 4)
        }
        .padding(.top, 40).padding(.bottom, 24)
        .frame(width: 88)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(prefs.t("home.k361"))
    }

    /// Same as Settings' appearance choice: kept on this device and saved to the account.
    private func toggleTheme(_ dark: Bool) {
        let next: ThemeChoice = dark ? .light : .dark
        prefs.theme = next
        Task {
            var s = SettingsAPI.loadNow()
            s.appTheme = next
            _ = await SettingsAPI.save(s)
        }
    }
}

/// iPad: a phone-style screen keeps its content in a readable column in the middle (design NewIPad: quiz, cards and
/// exam pages are at most 760 pt wide); the background stays full width. On the phone it changes nothing.
private struct PadColumn: ViewModifier {
    @Environment(\.padRail) private var wide
    let width: CGFloat

    func body(content: Content) -> some View {
        content.frame(maxWidth: wide ? width : .infinity).frame(maxWidth: .infinity)
    }
}

/// Design NewIPad: the header row of the wide pages (courses, exam, cards, upload, review, recording, notifications…):
/// a 46 pt round back button, a 36 pt title with a small line under it, and the page's own buttons at the end.
struct PadHeader<Trailing: View>: View {
    @Environment(AppPrefs.self) private var prefs
    let title: String
    var sub: String? = nil
    var onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                KIcon(name: .back, size: 20, width: 1.8, flipsInRTL: true)
                    .foregroundStyle(KPhone.text)
                    .frame(width: 46, height: 46)
                    .background(KPhone.card, in: Circle())
                    .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(prefs.t("signup.k1052"))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(KFont.ui(36, .medium, lang: prefs.lang)).kTracking(-0.03, size: 36, lang: prefs.lang)
                    .foregroundStyle(KPhone.text).lineLimit(1).minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
                if let sub { Text(sub).font(KFont.ui(13, lang: prefs.lang)).foregroundStyle(KPhone.text2).lineLimit(2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
    }
}

extension PadHeader where Trailing == EmptyView {
    init(title: String, sub: String? = nil, onBack: @escaping () -> Void) {
        self.init(title: title, sub: sub, onBack: onBack) { EmptyView() }
    }
}

/// Design NewIPad: the bordo pill of the wide headers ("Ders ekle", "PDF ekle").
struct PadPill: View {
    @Environment(AppPrefs.self) private var prefs
    let label: String
    var icon: KIconName? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { KIcon(name: icon, size: 16, width: 1.9) }
                Text(label).font(KFont.ui(14, .medium, lang: prefs.lang))
            }
            .foregroundStyle(Color(hex: 0xFFFCF6))
            .padding(.horizontal, 18).frame(height: 44)
            .background(Color(hex: 0x9C2F3A), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// Design NewIPad: a wide page's margins next to the rail (`padding: 32px 32px 32px 8px`).
    func padPage() -> some View {
        padding(.leading, 8).padding(.trailing, 32)
            .padding(.top, KLayout.top(54, minimum: 10) + 8).padding(.bottom, 32)
    }

    func padColumn(_ width: CGFloat = 760) -> some View { modifier(PadColumn(width: width)) }
}

/// Which first-steps step a screen shows (for the iPad side panel): 0 account … 5 courses.
struct PadFlowStepKey: PreferenceKey {
    static let defaultValue = 0
    static func reduce(value: inout Int, nextValue: () -> Int) { value = max(value, nextValue()) }
}

/// Design NewIPad "flow": sign up, first steps and course setup on the iPad. A 400 pt brand panel on the left with
/// the step list, the screen itself in a 600 pt column on the right.
struct PadFlowFrame<Content: View>: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(\.colorScheme) private var scheme
    @State private var step = 0
    @ViewBuilder var content: () -> Content

    private static var titles: [(String, String)] { [("Hesabını", "oluşturalım."), ("Dilini", "seçelim."), ("Planını", "kuralım."),
                                 ("Bölümünü", "tanıyalım."), ("Nasıl", "çalışır?"), ("Derslerini", "ekleyelim.")] }
    private static var steps: [String] { ["Hesap", "Dil", "Çalışma planı", "Bölüm", "Tanıtım", "Derslerin"] }

    var body: some View {
        let lang = prefs.lang
        let i = min(max(step, 0), 5)
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Wordmark(size: 19).environment(\.layoutDirection, .leftToRight)
                Image("BrandIcon").resizable().frame(width: 150, height: 150)
                    .shadow(color: Color(hex: 0x7A5208, opacity: 0.32), radius: 17, y: 20)
                    .padding(.top, 40)
                    .accessibilityHidden(true)
                (Text(i == 3 ? prefs.t("padSideDept") : prefs.d(Self.titles[i].0)) + Text("\n") + Text(prefs.d(Self.titles[i].1)).foregroundColor(KPhone.brand).fontWeight(.regular))
                    .font(KFont.ui(30, .medium, lang: lang)).kTracking(-0.03, size: 30, lang: lang)
                    .foregroundStyle(KPhone.text)
                    .padding(.top, 28)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(Self.steps.enumerated()), id: \.offset) { n, label in
                        let done = n < i, cur = n == i
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(done ? KPhone.brand : cur ? KPhone.card : .clear)
                                Circle().stroke(done ? .clear : cur ? KPhone.brand : KPhone.line, lineWidth: 1.5)
                                if done { KIcon(name: .check, size: 13, width: 2.4).foregroundStyle(Color(hex: 0xFFFCF6)) }
                                else { Text(Format.num(n + 1, lang)).font(KFont.mono(12, .semibold)).foregroundStyle(cur ? KPhone.brand : KPhone.text2) }
                            }
                            .frame(width: 30, height: 30)
                            Text(n == 3 ? prefs.t("padStepDept") : prefs.d(label)).font(KFont.ui(15, cur ? .semibold : .regular, lang: lang))
                                .foregroundStyle(cur ? KPhone.text : KPhone.text2)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(cur ? .isSelected : [])
                    }
                }
                .padding(.top, 30)
                Spacer()
                Text(prefs.d("PDF'lerin ve soruların yalnızca senin hesabında saklanır."))
                    .font(KFont.ui(12, lang: lang)).kLineHeight(1.5, size: 12, lang: lang).foregroundStyle(KPhone.text2)
            }
            .padding(.horizontal, 40).padding(.top, 44).padding(.bottom, 36)
            .frame(width: 400, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(KPhone.welcomeBg.ignoresSafeArea())
            content()
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KPhone.authBg.ignoresSafeArea())
        }
        .onPreferenceChange(PadFlowStepKey.self) { step = $0 }
    }
}

/// Design NewIPad: Premium opens as a 620 pt window over the dimmed app on the iPad, not as a full page.
struct PadDialog<Content: View>: View {
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            KPhone.authBg.ignoresSafeArea()
            Color(hex: 0x2A2420).opacity(0.35).ignoresSafeArea().onTapGesture(perform: onClose)
            content()
                .frame(width: 620)
                .frame(maxHeight: 880)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(KPhone.line, lineWidth: 1))
                .shadow(color: Color(hex: 0x2A2420, opacity: 0.3), radius: 35, y: 30)
                .padding(.vertical, 40)
        }
    }
}
