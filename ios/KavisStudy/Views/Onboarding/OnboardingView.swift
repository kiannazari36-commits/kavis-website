import SwiftUI

/// Design: design/ScrOnboarding.dc.html. After sign up: language, weekly study plan, department, three intro cards.
/// The last button goes on to the term courses; "Atla" (skip) in the intro cards goes straight home.
struct OnboardingView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app

    enum Step: Int, CaseIterable { case lang, plan, dept, intro1, intro2, intro3 }

    @State private var step: Step = {
        // Test switch: `-kavis.onboardingStep 0…5` opens a step.
        MockFlag.value("onboardingStep").flatMap(Int.init).flatMap(Step.init(rawValue:)) ?? .lang
    }()
    @State private var days = 4
    @State private var hours = 1.5
    @State private var dept = 0

    private var lang: Lang { prefs.lang }
    private func d(_ turkish: String) -> String { prefs.d(turkish) }
    private var isIntro: Bool { step.rawValue >= Step.intro1.rawValue }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Group {
                switch step {
                case .lang: languageStep
                case .plan: planStep
                case .dept: departmentStep
                default: introStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            footer
        }
        .background(KPhone.homeBg.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: step)
        .task {
            let saved = SettingsAPI.loadNow()
            days = saved.studyDays
            hours = saved.studyHours
        }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            Wordmark(size: 19)
            Spacer()
            if isIntro {
                Button(action: skip) {
                    Text(d("Atla")).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text2)
                        .frame(minHeight: 44).padding(.horizontal, 4)
                }
            } else {
                Text("\(Format.num(step.rawValue + 1, lang)) / \(Format.num(6, lang))")
                    .font(KFont.ui(13, .medium, lang: lang))
                    .foregroundStyle(KPhone.text2)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(KPhone.card, in: Capsule())
                    .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 44)
        .padding(.top, KLayout.top(54, minimum: 6) + 8)
    }

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Capsule().fill(s == step ? KOnb.pri : KPhone.line).frame(width: s == step ? 22 : 6, height: 6)
                }
            }
            .accessibilityHidden(true)
            Button(action: next) {
                Text(buttonLabel)
                    .font(KFont.ui(23, .medium, lang: lang))
                    .foregroundStyle(KPhone.ctaText)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(Color(hex: 0x9C2F3A), in: Capsule())
                    .shadow(color: Color(hex: 0x9C2F3A, opacity: 0.28), radius: 15, y: 12)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var buttonLabel: String {
        switch step {
        case .intro3: d("Başlayalım")
        case .intro1, .intro2: d("İleri")
        default: d("Devam")
        }
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(KFont.mono(11, .regular))
            .tracking(lang.isRTL ? 0 : 1.32)
            .foregroundStyle(KOnb.ambText)
    }

    private func title(_ text: String, size: CGFloat, lineHeight: CGFloat) -> some View {
        Text(text)
            .font(KFont.ui(size, .medium, lang: lang))
            .kTracking(-0.03, size: size, lang: lang)
            .kLineHeight(lineHeight, size: size, lang: lang)
            .foregroundStyle(KPhone.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func lead(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(KFont.ui(size, lang: lang))
            .kLineHeight(1.5, size: size, lang: lang)
            .foregroundStyle(KPhone.text2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Actions

    private func next() {
        if step == .intro3 {
            finish(then: .courseSetup)
        } else if let n = Step(rawValue: step.rawValue + 1) {
            step = n
        }
    }

    private func skip() { finish(then: .home) }

    /// Saves what the student chose (mock: on the phone) and moves on.
    private func finish(then route: Route) {
        var settings = SettingsAPI.loadNow()
        settings.studyDays = days
        settings.studyHours = hours
        var profile = AccountAPI.loadProfile(for: app.user)
        profile.department = Self.departments[dept]
        Task {
            _ = await SettingsAPI.save(settings)
            _ = await AccountAPI.saveProfile(profile)
        }
        UserDefaults.standard.set(true, forKey: "kavis.onboarded")
        if route == .home { app.reset(to: .home) } else { app.go(route) }
    }

    // MARK: Step 1: language

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow(Self.welcome(lang))
            title(d("Uygulama dilini seç"), size: 32, lineHeight: 1.12)
            lead(d("Bu, arayüzün dilidir. Hocanın PDF'i her zaman olduğu gibi kalır."), size: 15).padding(.bottom, 14)
            VStack(spacing: 10) {
                ForEach(Lang.allCases) { option in
                    let on = option == lang
                    Button { prefs.lang = option } label: {
                        HStack(spacing: 14) {
                            Text(option.rawValue.uppercased())
                                .font(KFont.mono(13, .semibold))
                                .foregroundStyle(on ? KOnb.priText : KPhone.text2)
                                .frame(width: 44, height: 44)
                                .background(on ? KOnb.priSoft : KPhone.sub, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.name).font(KFont.ui(17, .semibold, lang: option)).foregroundStyle(KPhone.text)
                                Text(option.isRTL ? "RTL" : "LTR").font(KFont.mono(11, .regular)).foregroundStyle(KOnb.text3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            ZStack {
                                Circle().stroke(on ? KOnb.pri : KOnb.text3, lineWidth: on ? 2 : 1.5)
                                Circle().fill(on ? KOnb.pri : .clear).frame(width: 10, height: 10)
                            }
                            .frame(width: 22, height: 22)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 68)
                        .background(KPhone.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(on ? KOnb.pri : KPhone.line, lineWidth: on ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
    }

    private static func welcome(_ lang: Lang) -> String {
        switch lang {
        case .tr: "HOŞ GELDİN · WELCOME · خوش آمدی · أهلاً"
        case .en: "WELCOME · HOŞ GELDİN · خوش آمدی · أهلاً"
        case .fa: "خوش آمدی · HOŞ GELDİN · WELCOME · أهلاً"
        case .ar: "أهلاً · HOŞ GELDİN · WELCOME · خوش آمدی"
        }
    }

    // MARK: Step 2: weekly plan

    private func hoursText(_ h: Double) -> String {
        let raw = h.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(h)) : String(h)
        switch lang {
        case .tr: return raw.replacingOccurrences(of: ".", with: ",") + " sa"
        case .en: return raw + " h"
        case .fa: return raw + " ساعت"
        case .ar: return raw + " ساعة"
        }
    }

    private var planSummary: String {
        let total = (Double(days) * hours * 10).rounded() / 10
        let totalText = total.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(total)) : String(total)
        let t = lang == .tr ? totalText.replacingOccurrences(of: ".", with: ",") : totalText
        switch lang {
        case .tr: return "Haftada \(days) gün × \(hoursText(hours)) ≈ \(t) saat"
        case .en: return "\(days) days × \(hoursText(hours)) ≈ \(t) h a week"
        case .fa: return "هفته‌ای \(days) روز × \(hoursText(hours)) ≈ \(t) ساعت"
        case .ar: return "\(days) أيام × \(hoursText(hours)) ≈ \(t) ساعة أسبوعيًا"
        }
    }

    private var planStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow("\(Format.num(2, lang)) / \(Format.num(6, lang))")
            title(d("Haftalık çalışma planın"), size: 28, lineHeight: 1.15)
            lead(d("Gerçekçi bir hedef seç; tekrar takvimi ve hatırlatmalar buna göre kurulur."), size: 14).padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 12) {
                Text(d("Haftada kaç gün çalışabilirsin?")).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { n in
                        let on = n == days
                        Button { days = n } label: {
                            Text(Format.num(n, lang))
                                .font(KFont.ui(16, .semibold, lang: lang))
                                .foregroundStyle(on ? KPhone.ctaText : KPhone.text)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(on ? KOnb.pri : KPhone.sub, in: Capsule())
                                .overlay(Capsule().stroke(on ? .clear : KPhone.line, lineWidth: 1))
                        }
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            .padding(14)
            .kPhoneCard(radius: 22)

            VStack(alignment: .leading, spacing: 10) {
                Text(d("Bir günde ortalama kaç saat?")).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                HStack(spacing: 12) {
                    Button { hours = max(0.5, hours - 0.5) } label: {
                        KIcon(name: .minus, size: 20, width: 2)
                            .foregroundStyle(KPhone.text)
                            .frame(width: 48, height: 48)
                            .background(KPhone.sub, in: Circle())
                            .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
                    }
                    .accessibilityLabel(d("Azalt"))
                    Text(hoursText(hours))
                        .font(KFont.ui(32, .bold, lang: lang))
                        .kTracking(-0.02, size: 32, lang: lang)
                        .foregroundStyle(KPhone.text)
                        .frame(maxWidth: .infinity)
                        .accessibilityAddTraits(.updatesFrequently)
                    Button { hours = min(8, hours + 0.5) } label: {
                        KIcon(name: .cross, size: 20, width: 2)
                            .foregroundStyle(KPhone.ctaText)
                            .frame(width: 48, height: 48)
                            .background(KOnb.pri, in: Circle())
                    }
                    .accessibilityLabel(d("Artır"))
                }
            }
            .padding(14)
            .kPhoneCard(radius: 22)

            HStack(alignment: .top, spacing: 12) {
                KIcon(name: .calendar, size: 17, width: 1.8)
                    .foregroundStyle(Color(hex: 0x2A2420))
                    .frame(width: 36, height: 36)
                    .background(KColor.amb, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(planSummary).font(KFont.ui(15, .bold, lang: lang)).foregroundStyle(KPhone.text)
                    Text(d("Planı birkaç hafta sonra Ayarlar › Çalışma planı bölümünden istediğin zaman değiştirebilirsin."))
                        .font(KFont.ui(12, lang: lang))
                        .kLineHeight(1.45, size: 12, lang: lang)
                        .foregroundStyle(KPhone.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(KOnb.ambSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    // MARK: Step 3: department

    /// Departments as the design writes them in Turkish; the same words are stored in the profile.
    static let departments = ["Eczacılık", "Tıp", "Diş Hekimliği", "Hemşirelik", "Sağlık Bilimleri", "Diğer"]
    private static let departmentIcons: [KIconName] = [.flask, .stethoscope, .tooth, .cross, .pulse, .dots]

    private var departmentStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow("\(Format.num(3, lang)) / \(Format.num(6, lang))")
            title(d("Hangi bölümde okuyorsun?"), size: 32, lineHeight: 1.12)
            lead(d("Terim açıklamalarını ve soru tarzını bölümüne göre ayarlarız."), size: 15).padding(.bottom, 14)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(Self.departments.enumerated()), id: \.offset) { i, name in
                    let on = i == dept
                    Button { dept = i } label: {
                        VStack(alignment: .leading) {
                            KIcon(name: Self.departmentIcons[i], size: 20, width: 1.6)
                                .foregroundStyle(on ? KPhone.ctaText : KPhone.text2)
                                .frame(width: 44, height: 44)
                                .background(on ? KOnb.pri : KPhone.sub, in: Circle())
                            Spacer(minLength: 0)
                            Text(d(name)).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                                .kLineHeight(1.2, size: 16, lang: lang)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .frame(height: 112)
                        .background(on ? KOnb.priSoft : KPhone.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(on ? KOnb.pri : KPhone.line, lineWidth: on ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
    }

    // MARK: Steps 4–6: intro cards

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous).fill(KPhone.card)
                switch step {
                case .intro1: IntroPdfCard()
                case .intro2: IntroTermCard()
                default: IntroProgressCard()
                }
            }
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: Color(light: Color(hex: 0x1B2430, opacity: 0.06), dark: Color(hex: 0x000000, opacity: 0.35)), radius: 10, y: 6)
            title(introTitle, size: 28, lineHeight: 1.15).padding(.top, 10)
            lead(introText, size: 15)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var introTitle: String {
        switch step {
        case .intro1: d("Hocanın metni, hiç değişmeden")
        case .intro2: d("Dokun, anla, çevir")
        default: d("Sına, tekrar et, unutma")
        }
    }

    private var introText: String {
        switch step {
        case .intro1: d("PDF'ini yükle; her slayt okunabilir bir karta dönüşür. Tek bir kelime bile değiştirilmez.")
        case .intro2: d("Bilmediğin terime dokun, açıklaması açılsın. Cümleyi seç; İngilizce, Farsça ya da Arapça oku. Asistan istersen sadece senin PDF'inden, istersen yapay zekâ araştırmasıyla da cevap verir.")
        default: d("Bölüm kontrolleri, ders sonu sınavı ve tekrar takvimi konuyu kalıcı hale getirir.")
        }
    }
}

/// Colors of the onboarding design (close to KPhone, a few values differ).
enum KOnb {
    static let pri = Color.pair(0x9C2F3A, 0xB23A47)
    static let priText = Color.pair(0x9C2F3A, 0xF09AA3)
    static let priSoft = Color.pair(0xF7E7E9, 0x3A2027)
    static let ambText = Color.pair(0x83560A, 0xF2C46E)
    static let ambSoft = Color.pair(0xFDF1D6, 0x3A2F1A)
    static let ok = Color.pair(0x1E7A4C, 0x5BC893)
    static let okSoft = Color.pair(0xE2F3E9, 0x173328)
    static let bad = Color.pair(0xC0352B, 0xF27A70)
    static let badSoft = Color.pair(0xFCE8E6, 0x3D1F1F)
    static let text3 = Color.pair(0x776C60, 0x9A8F82)
    static let cardShadow = Color(light: Color(hex: 0x1B2430, opacity: 0.14), dark: Color(hex: 0x000000, opacity: 0.4))
}
