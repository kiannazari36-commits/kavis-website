import SwiftUI
import PhotosUI

/// Design: design/NewProfile.dc.html. Profile (photo, name, stats, plan, menu, log out) and "Hesap bilgilerim" (edit).
struct ProfileView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(\.openURL) private var openURL
    @Environment(ToastCenter.self) private var toast
    @Environment(TrialModel.self) private var trial
    @Environment(\.colorScheme) private var scheme

    private enum Mode { case view, edit }

    // Test switch: `-kavis.route profileEdit` opens the edit page.
    @State private var mode: Mode = MockFlag.value("route") == "profileEdit" ? .edit : .view
    @State private var profile = Profile(name: "", email: "", school: "")
    @State private var saved = false
    @State private var loaded = false
    @State private var photo: UIImage? = AvatarAPI.cached()
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var profileStats: ProfileStats?
    @State private var notifyTime = SettingsAPI.loadNow().notifyTime

    private var lang: Lang { prefs.lang }
    private func d(_ turkish: String) -> String { prefs.d(turkish) }
    private func soon() { toast.show(prefs.t("k165")) }

    /// "Yardım ve geri bildirim": the web's help page (questions answered by the help chat, e-mail button).
    private func openHelp() {
        if let url = URL(string: "\(Config.webBaseURL)/help?lang=\(lang.rawValue)") { openURL(url) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if mode == .view { viewContent } else { editContent }
        }
        .padColumn()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background.ignoresSafeArea())
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data),
                      let saved = await AvatarAPI.upload(image) else { return toast.show(prefs.t("errOther")) }
                photo = saved
                toast.show(d("Fotoğraf seçildi"))
            }
        }
        .task {
            Task { photo = await AvatarAPI.fetch() }
            if !loaded {
                // The phone's copy at once, then the account's profile from the server.
                profile = AccountAPI.loadProfile(for: app.user)
                loaded = true
                profile = await AccountAPI.fetchProfile(for: app.user)
            }
            async let s = ProgressAPI.profileStats()
            async let st = SettingsAPI.fetch()
            profileStats = await s
            if let st = await st { notifyTime = st.notifyTime }
        }
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    private var background: some View {
        ZStack {
            KPhone.authBg
            if scheme == .dark {
                RadialGradient(colors: [KPhone.authTop, .clear], center: .top, startRadius: 0, endRadius: 480)
            } else {
                LinearGradient(colors: [KPhone.authTop, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.45))
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                if mode == .edit { mode = .view } else { app.back() }
            } label: {
                KIcon(name: .back, size: 20, width: 1.8, flipsInRTL: true)
                    .foregroundStyle(KPhone.text)
                    .frame(width: 46, height: 46)
                    .background(KPhone.card, in: Circle())
                    .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
            }
            .accessibilityLabel(prefs.t("signup.k1052"))
            Text(d(mode == .edit ? "Hesap bilgilerim" : "Profilim"))
                .font(KFont.ui(16, .semibold, lang: lang))
                .foregroundStyle(KPhone.text)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            Color.clear.frame(width: 46, height: 46)
        }
        .padding(.horizontal, 20)
        .padding(.top, KLayout.top(60, minimum: 6))
        .padding(.bottom, 6)
    }

    // MARK: Profile

    private var initials: String {
        profile.name.split(separator: " ").prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
    }

    private func avatar(size: CGFloat, font: CGFloat) -> some View {
        Group {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
            } else { initialsAvatar(size: size, font: font) }
        }
    }

    private func initialsAvatar(size: CGFloat, font: CGFloat) -> some View {
        Text(initials)
            .font(KFont.ui(font, .semibold, lang: .en))
            .foregroundStyle(KPhone.ctaText)
            .frame(width: size, height: size)
            .background(
                Circle().fill(RadialGradient(
                    colors: [Color(hex: 0xF9D28E), Color(hex: 0xE8925A), Color(hex: 0x9C2F3A)],
                    center: UnitPoint(x: 0.35, y: 0.30), startRadius: 0, endRadius: size * 0.85
                ))
            )
    }

    private var viewContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                if saved {
                    HStack(spacing: 8) {
                        KIcon(name: .check, size: 16, width: 2.4)
                        Text(d("Bilgilerin kaydedildi")).font(KFont.ui(13, .medium, lang: lang))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(KPhone.good)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.pair(0xE3F1E7, 0x1F3328), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
                identity
                stats
                planCard
                menu
                Button { Task { await app.signOut() } } label: {
                    Text(d("Çıkış yap"))
                        .font(KFont.ui(15, .medium, lang: lang))
                        .foregroundStyle(KPhone.brand)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
                }
                Text(d("KAVIS STUDY · 1.0 (12) · Üyelik: Eylül 2026"))
                    .font(KFont.mono(10, .regular))
                    .foregroundStyle(KPhone.text3)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
    }

    private var identity: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(Color(light: Color(hex: 0xF2B33D, opacity: 0.2), dark: Color(hex: 0xF2B33D, opacity: 0.10)))
                    .frame(width: 112, height: 112)
                avatar(size: 96, font: 34)
                    .overlay(alignment: .bottomTrailing) {
                        Button { enterEdit() } label: {
                            KIcon(name: .camera, size: 16, width: 1.8)
                                .foregroundStyle(KPhone.text)
                                .frame(width: 36, height: 36)
                                .background(KPhone.card, in: Circle())
                                .overlay(Circle().stroke(KPhone.authBg, lineWidth: 3))
                        }
                        .offset(x: 4, y: 4)
                        .accessibilityLabel(d("Fotoğrafı değiştir"))
                    }
            }
            .padding(.top, 4)
            Text(profile.name)
                .font(KFont.ui(26, .semibold, lang: lang))
                .kTracking(-0.02, size: 26, lang: lang)
                .foregroundStyle(KPhone.text)
                .padding(.top, 10)
            Text(profile.email).font(KFont.ui(13, lang: lang)).foregroundStyle(KPhone.text2)
            FlowLayout(spacing: 6, rowSpacing: 6, alignment: .center) {
                let dept = [profile.department.isEmpty ? nil : d(profile.department), profile.year.map { Format.yearLabel($0, lang) }].compactMap { $0 }
                if !dept.isEmpty { chip(dept.joined(separator: " · ")) }
                if !profile.school.isEmpty { chip(profile.school) }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(KFont.ui(12, lang: lang))
            .foregroundStyle(KPhone.text)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(KPhone.card, in: Capsule())
            .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
    }

    private var stats: some View {
        HStack(spacing: 8) {
            ForEach(statItems, id: \.label) { value, label, action in
                Button(action: action) {
                    VStack(spacing: 2) {
                        Text(value).font(KFont.ui(20, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                        Text(d(label)).font(KFont.ui(11, lang: lang)).foregroundStyle(KPhone.text2).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12).padding(.horizontal, 6)
                    .kPhoneCard(radius: 20)
                }
            }
        }
    }

    /// Study time, streak and number of courses (design samples "42 sa", "6 gün", "5"); under an hour it shows minutes.
    private var statItems: [(value: String, label: String, action: () -> Void)] {
        let st = profileStats ?? ProfileStats()
        let time = st.minutes >= 60
            ? prefs.d("42 sa", numbers: [("42", Int((Double(st.minutes) / 60).rounded()))])
            : prefs.d("33 dk", numbers: [("33", st.minutes)])
        return [(time, "çalışma", { app.go(.progress) }),
                (prefs.d("6 gün", numbers: [("6", st.streak)]), "çalışma serisi", { app.go(.progress) }),
                (Format.num(st.courses, lang), "ders sayısı", { app.go(.courses) })]
    }

    /// Plan card. The design still shows the old "this month 1 of 2 courses" plan; the rules are now the 3-day trial.
    private var planCard: some View {
        let s = trial.status
        let title: String
        let sub: String
        if s.premium {
            title = "Premium"
            if s.premiumSource == "promo", let until = s.premiumUntil {
                sub = prefs.t("codeActive", ["date": RedeemCodeView.dateText(until, lang: lang)])
            } else {
                sub = prefs.t("pwIphoneSub")
            }
        } else if s.ended {
            title = prefs.t("trialEnded")
            sub = prefs.t("trialKeep")
        } else {
            title = prefs.t("trialTitle")
            let limits = ["\(Format.num(s.pdfsUsed, lang))/\(Format.num(TrialLimits.pdfs, lang)) PDF",
                          "\(Format.num(s.questionsUsed, lang))/\(Format.num(TrialLimits.questions, lang)) \(prefs.t("trialQuestions"))"]
            sub = prefs.t("trialDaysLeft", ["n": Format.num(s.daysLeft, lang)]) + "\n" + limits.joined(separator: " · ")
        }
        return Button { app.go(.paywall(nil)) } label: {
            HStack(spacing: 12) {
                KIcon(name: .spark, size: 20, width: 1.7)
                    .frame(width: 42, height: 42)
                    .background(KPhone.heroChip, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(KFont.ui(15, .semibold, lang: lang))
                    Text(sub).font(KFont.ui(12, lang: lang)).opacity(0.8).multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                KIcon(name: .arrowRight, size: 16, width: 2, flipsInRTL: true)
            }
            .foregroundStyle(KColor.onHero)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(KGradient.hero, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color(light: Color(hex: 0xE8925A, opacity: 0.25), dark: .clear), radius: 15, y: 14)
        }
        .buttonStyle(.plain)
    }

    private struct MenuRow {
        let title: String, sub: String
        let icon: KIconName
        let chip: Color, fg: Color
        let action: () -> Void
    }

    private var menu: some View {
        let red = (Color.pair(0xF5E3E2, 0x3A2224), Color.pair(0x9C2F3A, 0xF09AA3))
        let amb = (Color.pair(0xFBEBC8, 0x3A2E18), Color.pair(0xA86F0E, 0xF2C66D))
        let vio = (Color.pair(0xE8E6F6, 0x2C2A3A), Color.pair(0x4A3F9A, 0xB9B4F0))
        let grn = (Color.pair(0xE3F1E7, 0x1F3328), Color.pair(0x2E7D4F, 0x8FD3A8))
        let gray = (Color.pair(0xEFE8DC, 0x2B2520), Color.pair(0x6E645A, 0xBDB2A4))
        let st = profileStats ?? ProfileStats()
        let rows = [
            MenuRow(title: "Hesap bilgilerim", sub: d("Ad, e-posta, üniversite, sınıf"), icon: .person, chip: red.0, fg: red.1, action: { enterEdit() }),
            MenuRow(title: "Derslerim klasörü", sub: prefs.d("Bu dönem 5 ders · 13 PDF", numbers: [("13", st.pdfs), ("5", st.courses)]), icon: .folder, chip: amb.0, fg: amb.1, action: { app.go(.courses) }),
            MenuRow(title: "İlerleme ve takvim", sub: d("Haftalık süre, seviye, sınav haftası"), icon: .chart, chip: grn.0, fg: grn.1, action: { app.go(.progress) }),
            MenuRow(title: "Soru örneklerim", sub: prefs.d("35 soru · hocanın tarzı çıkarıldı", numbers: [("35", st.sampleQuestions)]), icon: .help, chip: vio.0, fg: vio.1, action: { app.go(.samples(nil)) }),
            MenuRow(title: "Bildirimler", sub: prefs.d("Hatırlatma 09:00 · 1 saat önce").components(separatedBy: " · ")[0].replacingOccurrences(of: "09:00", with: Format.num(notifyTime, lang)), icon: .bellSmall, chip: gray.0, fg: gray.1, action: { app.go(.settings) }),
            MenuRow(title: "Ayarlar", sub: d("Çalışma planı, dil, tema"), icon: .sliders, chip: gray.0, fg: gray.1, action: { app.go(.settings) }),
            MenuRow(title: "Yardım ve geri bildirim", sub: d("Sık sorulanlar, bize yaz"), icon: .chat, chip: gray.0, fg: gray.1, action: { openHelp() }),
        ]
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                Button(action: row.action) {
                    HStack(spacing: 12) {
                        KIcon(name: row.icon, size: 18, width: 1.6)
                            .foregroundStyle(row.fg)
                            .frame(width: 38, height: 38)
                            .background(row.chip, in: Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(d(row.title)).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text)
                            Text(row.sub).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        KIcon(name: .arrowRight, size: 14, width: 2, flipsInRTL: true).foregroundStyle(KPhone.text3)
                    }
                    .padding(.vertical, 8)
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { if i > 0 { Rectangle().fill(KPhone.line).frame(height: 1) } }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
        .kPhoneCard()
    }

    // MARK: Edit

    private var editContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        avatar(size: 72, font: 26)
                        VStack(alignment: .leading, spacing: 6) {
                            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                                Text(d("Fotoğraf seç"))
                                    .font(KFont.ui(13, lang: lang)).foregroundStyle(KPhone.text)
                                    .padding(.horizontal, 14).frame(height: 38)
                                    .background(KPhone.card, in: Capsule())
                                    .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
                            }
                            Text(d("İstersen baş harflerin kalsın")).font(KFont.ui(11, lang: lang)).foregroundStyle(KPhone.text3)
                        }
                    }
                    field(d("Ad soyad"), $profile.name, content: .name)
                    field(d("E-posta"), $profile.email, content: .emailAddress)
                    field(d("Üniversite"), $profile.school, content: .organizationName)
                    field(d("Bölüm"), $profile.department, content: nil)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(d("Sınıf")).font(KFont.ui(13, lang: lang)).foregroundStyle(KPhone.text2).padding(.leading, 6)
                        HStack(spacing: 6) {
                            ForEach(1...6, id: \.self) { n in
                                let on = profile.year == n
                                Button { profile.year = n } label: {
                                    Text(Format.num(n, lang))
                                        .font(KFont.ui(15, .semibold, lang: lang))
                                        .foregroundStyle(on ? KPhone.ctaText : KPhone.text)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(on ? KPhone.cta : .clear, in: Capsule())
                                        .overlay(Capsule().stroke(on ? .clear : KPhone.line, lineWidth: 1))
                                }
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                    Button {
                        // The same e-mail as "Şifremi unuttum": the new password is set on the web page.
                        Task {
                            let email = AuthAPI.currentUser()?.email ?? profile.email
                            toast.show(await AuthAPI.sendPasswordReset(email: email) ? d("Şifre değiştirme bağlantısı e-postana gönderildi") : prefs.t("errOther"))
                        }
                    } label: {
                        Text(d("Şifreyi değiştir"))
                            .font(KFont.ui(14, lang: lang)).foregroundStyle(KPhone.text)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(KPhone.card, in: Capsule())
                            .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
                    }
                    Text(d("Hesabını silmek istersen Ayarlar › Gizlilik bölümünden tüm PDF'lerinle birlikte silebilirsin."))
                        .font(KFont.ui(12, lang: lang))
                        .kLineHeight(1.5, size: 12, lang: lang)
                        .foregroundStyle(KPhone.text3)
                        .padding(.horizontal, 6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button { Task { await save() } } label: {
                    Text(d("Kaydet"))
                        .font(KFont.ui(17, .medium, lang: lang))
                        .foregroundStyle(KPhone.ctaText)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(KPhone.cta, in: Capsule())
                        .shadow(color: Color(hex: 0x9C2F3A, opacity: 0.28), radius: 15, y: 12)
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
            }
        }
    }

    private func field(_ label: String, _ text: Binding<String>, content: UITextContentType?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(KFont.ui(13, lang: lang)).foregroundStyle(KPhone.text2).padding(.leading, 6)
            TextField("", text: text)
                .textContentType(content)
                .keyboardType(content == .emailAddress ? .emailAddress : .default)
                .textInputAutocapitalization(content == .emailAddress ? .never : .words)
                .font(KFont.ui(15, lang: lang))
                .foregroundStyle(KPhone.text)
                .padding(.horizontal, 20)
                .frame(height: 52)
                .background(KPhone.card, in: Capsule())
                .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
        }
    }

    /// The department and university are the student's own words: edited as they are saved in the account.
    private func enterEdit() {
        saved = false
        mode = .edit
    }

    private func save() async {
        profile = await AccountAPI.saveProfile(profile)
        saved = true
        mode = .view
    }
}
