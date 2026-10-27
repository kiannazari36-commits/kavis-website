import SwiftUI

/// Design: design/ScrSettings.dc.html (iPhone). Study plan, language, voice, notifications, appearance, offline use,
/// school timetable, help, privacy and "Hesabı sil". Saved in the account (user_settings, profiles.app_lang) like the web.
/// New next to the design (CLAUDE.md, same as the web's Settings): "System" theme, "Content language", "My devices"
/// and "Log out".
struct SettingsView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    /// iPad (design NewIPad, "settings"): account and plan on top, the other sections in two columns.
    @Environment(\.padRail) private var wide
    @Environment(ToastCenter.self) private var toast
    @Environment(TrialModel.self) private var trial
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL

    @State private var settings = SettingsAPI.loadNow()
    @State private var profile = Profile(name: "", email: "", school: "")
    @State private var devices: [Device] = []
    @State private var weekMinutes = 0
    @State private var pdfCount = 0
    @State private var deleteOpen = false
    @State private var exportFile: ExportFile?
    @State private var timeOpen = false
    /// The day the account will be deleted, when a deletion was asked for.
    @State private var deletionDate: Date?
    @State private var pickedTime = Date()

    /// The design's own colours for this screen (c.* in ScrSettings).
    private enum C {
        static let bg = Color.pair(0xF4EFE6, 0x15120F)
        static let card = Color.pair(0xFFFCF6, 0x211C18)
        static let sub = Color.pair(0xF4EFE6, 0x2B2520)
        static let seg = Color.pair(0xFFFCF6, 0x463D35)
        static let text = Color.pair(0x2A2420, 0xEFE8DC)
        static let text2 = Color.pair(0x6E645A, 0xBDB2A4)
        static let text3 = Color.pair(0x776C60, 0x9A8F82)
        static let line = Color.pair(0xE6DDCF, 0x3A322B)
        static let pri = Color.pair(0x9C2F3A, 0xB23A47)
        static let priText = Color.pair(0x9C2F3A, 0xF09AA3)
        static let priSoft = Color.pair(0xF7E7E9, 0x3A2027)
        static let amb = Color(hex: 0xF2B33D)
        static let ambText = Color.pair(0x83560A, 0xF2C46E)
        static let ambSoft = Color.pair(0xFDF1D6, 0x3A2F1A)
        static let ok = Color.pair(0x1E7A4C, 0x5BC893)
        static let bad = Color.pair(0xC0352B, 0xF27A70)
        static let switchOff = Color.pair(0xDDD2C1, 0x463D35)
    }

    /// Where students write for help (the same address as the web).
    private static let supportEmail = "kavisstudy@gmail.com"

    private var lang: Lang { prefs.lang }
    private func d(_ s: String) -> String { prefs.d(s) }
    private func soon() { toast.show(prefs.t("k165")) }

    var body: some View {
        ZStack {
            C.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Text(d("Ayarlar"))
                    .font(KFont.ui(wide ? 40 : 32, wide ? .medium : .bold, lang: lang))
                    .kTracking(wide ? -0.03 : -0.02, size: wide ? 40 : 32, lang: lang)
                    .foregroundStyle(C.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, wide ? 8 : 20).padding(.trailing, 20)
                    .padding(.top, wide ? KLayout.top(54, minimum: 10) + 8 : KLayout.top(58, minimum: 8)).padding(.bottom, 10)
                    .accessibilityAddTraits(.isHeader)
                ScrollView {
                    VStack(spacing: 8) {
                        if wide {
                            accountCard
                            heading(d("Çalışma planı"))
                            planCard
                            HStack(alignment: .top, spacing: 16) {
                                VStack(spacing: 8) {
                                    heading(d("Dil ve bölüm"))
                                    langCard
                                    heading(d("Ses"))
                                    voiceCard
                                    heading(d("Bildirimler"))
                                    notifCard
                                    heading(d("Okul ders programı"))
                                    scheduleCard
                                }
                                .frame(maxWidth: .infinity, alignment: .top)
                                VStack(spacing: 8) {
                                    heading(d("Görünüm"))
                                    lookCard
                                    heading(d("Çevrimdışı kullanım"))
                                    offlineCard
                                    heading(prefs.t("devTitle"))
                                    devicesCard
                                    heading(d("Yardım ve destek"))
                                    helpCard
                                    heading(d("Hesap ve gizlilik"))
                                    privacyCard
                                }
                                .frame(maxWidth: .infinity, alignment: .top)
                            }
                        } else {
                            accountCard
                            heading(d("Çalışma planı"))
                            planCard
                            heading(d("Dil ve bölüm"))
                            langCard
                            heading(d("Ses"))
                            voiceCard
                            heading(d("Bildirimler"))
                            notifCard
                            heading(d("Görünüm"))
                            lookCard
                            heading(d("Çevrimdışı kullanım"))
                            offlineCard
                            heading(prefs.t("devTitle"))
                            devicesCard
                            heading(d("Okul ders programı"))
                            scheduleCard
                            heading(d("Yardım ve destek"))
                            helpCard
                            heading(d("Hesap ve gizlilik"))
                            privacyCard
                        }
                        Button { Task { await app.signOut() } } label: {
                            Text(prefs.t("logout"))
                                .font(KFont.ui(15, .medium, lang: lang))
                                .foregroundStyle(C.priText)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .overlay(Capsule().stroke(C.line, lineWidth: 1))
                        }
                        .padding(.top, 14)
                        Text("KAVIS STUDY · \(Self.version)")
                            .font(KFont.mono(10, .regular))
                            .foregroundStyle(C.text3)
                            .padding(.top, 10)
                    }
                    .frame(maxWidth: wide ? .infinity : nil)
                    .padding(.leading, wide ? 8 : 16).padding(.trailing, wide ? 32 : 16).padding(.bottom, wide ? 32 : 120)
                }
                .scrollIndicators(.hidden)
                .refreshable { await load() }
            }
            FloatingTabBar(active: .settings, onCourses: { app.go(.courses) }, onProgress: { app.go(.progress) }, onSettings: {})
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 8)
            if timeOpen { timeSheet.transition(.opacity) }
            if deleteOpen {
                DeleteAccountSheet(onClose: { deleteOpen = false }) { date in
                    deleteOpen = false
                    deletionDate = date
                    toast.show(prefs.t("delScheduled", ["date": dayText(date)]))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: deleteOpen)
        .animation(.easeInOut(duration: 0.2), value: timeOpen)
        .sheet(item: $exportFile) { ShareSheet(items: [$0.url]) }
        .task { await load() }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "1.0") (\(info?["CFBundleVersion"] as? String ?? "1"))"
    }

    private func load() async {
        profile = AccountAPI.loadProfile(for: app.user)
        async let s = SettingsAPI.fetch()
        async let p = AccountAPI.fetchProfile(for: app.user)
        async let list = DevicesAPI.listDevices()
        async let progress = ProgressAPI.load()
        async let courses = CoursesAPI.listCourses()
        if let fresh = await s { settings = fresh }
        profile = await p
        devices = await list
        weekMinutes = await progress.weekMinutes.reduce(0, +)
        pdfCount = await courses.reduce(0) { $0 + $1.pdfs.count }
        deletionDate = await AccountAPI.deletionDate()
    }

    /// Changes a setting here at once and saves it in the account.
    /// `reminder`: the reminder switch or time changed, so the phone's daily reminder is set again.
    private func update(reminder: Bool = false, _ change: (inout Settings) -> Void) {
        change(&settings)
        let s = settings
        let l = lang
        Task {
            _ = await SettingsAPI.save(s)
            if reminder { await ReminderService.refresh(s, lang: l) }
        }
    }

    private func dayText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = lang.locale
        f.setLocalizedDateFormatFromTemplate("d MMMM")
        return f.string(from: date)
    }

    // MARK: Pieces

    private func heading(_ title: String) -> some View {
        Text(title.uppercased(with: lang.locale))
            .font(KFont.ui(12, .medium, lang: lang))
            .kTracking(0.04, size: 12, lang: lang)
            .foregroundStyle(C.text3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4).padding(.top, 14).padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
    }

    private func card<Content: View>(padding: EdgeInsets = EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14),
                                      @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(C.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// JetBrains Mono for numbers; Persian and Arabic words read better in the UI font (Vazirmatn).
    private func mono(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        lang.isRTL ? KFont.ui(size, weight, lang: lang) : KFont.mono(size, weight)
    }

    private var divider: some View { Rectangle().fill(C.line).frame(height: 1) }

    private func chevron() -> some View {
        KIcon(name: .arrowRight, size: 16, width: 2, flipsInRTL: true).foregroundStyle(C.text3)
    }

    /// The design's segmented control (radio group): `columns` nil = the items side by side at their own width.
    private func segmented<T: Hashable>(_ label: String, _ items: [(T, String)], selected: T, height: CGFloat = 36,
                                        columns: Int? = nil, pick: @escaping (T) -> Void) -> some View {
        let buttons = ForEach(items, id: \.0) { value, name in
            let on = value == selected
            Button { pick(value) } label: {
                Text(name)
                    .font(KFont.ui(13, on ? .semibold : .medium, lang: lang))
                    .foregroundStyle(on ? C.text : C.text2)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.horizontal, columns == nil ? 14 : 4)
                    .frame(maxWidth: columns == nil ? nil : .infinity, minHeight: height, maxHeight: height)
                    .background(on ? C.seg : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: on ? Color.black.opacity(0.12) : .clear, radius: 1.5, y: 1)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(on ? [.isSelected] : [])
        }
        return Group {
            if let columns {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: 4) { buttons }
            } else {
                HStack(spacing: 4) { buttons }
            }
        }
        .padding(3)
        .background(C.sub, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    /// iOS switch drawn as the design (51 × 31, bordo when on).
    private func toggle(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Capsule()
                .fill(on ? C.pri : C.switchOff)
                .frame(width: 51, height: 31)
                .overlay(alignment: on ? .trailing : .leading) {
                    Circle().fill(Color(hex: 0xFFFCF6)).frame(width: 27, height: 27)
                        .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
                        .padding(2)
                }
                .animation(.easeInOut(duration: 0.15), value: on)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(on ? "1" : "0")
        .accessibilityAddTraits(.isToggle)
    }

    private func switchRow(_ title: String, _ sub: String, on: Bool, minHeight: CGFloat = 56, last: Bool = false,
                           action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(KFont.ui(15, lang: lang)).foregroundStyle(C.text)
                    Text(sub).font(KFont.ui(12, lang: lang)).foregroundStyle(C.text3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                toggle(title, on: on, action: action)
            }
            .padding(.vertical, 8)
            .frame(minHeight: minHeight)
            if !last { divider }
        }
    }

    // MARK: Account

    private var accountCard: some View {
        Button { app.go(.paywall(nil)) } label: {
            HStack(spacing: 12) {
                KIcon(name: .person, size: 24, width: 1.6)
                    .foregroundStyle(C.priText)
                    .frame(width: 48, height: 48)
                    .background(C.priSoft, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(d("Hesabım")).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(C.text)
                    Text(profile.email).font(KFont.ui(13, lang: .en)).foregroundStyle(C.text3)
                        .lineLimit(1).truncationMode(.middle)
                        .environment(\.layoutDirection, .leftToRight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(trial.status.premium ? "PREMIUM" : d("ÜCRETSİZ"))
                    .font(mono(10, .semibold))
                    .foregroundStyle(C.ambText)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(C.ambSoft, in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(14)
            .background(C.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Study plan

    /// "1,5 sa" in the design's words.
    private func hoursText(_ x: Double) -> String {
        var s = x == x.rounded() ? String(Int(x)) : String(format: "%.1f", x)
        if lang == .tr { s = s.replacingOccurrences(of: ".", with: ",") }
        return Format.num(s, lang)
    }

    private var planCard: some View {
        let target = (Double(settings.studyDays) * settings.studyHours * 10).rounded() / 10
        let pct = target > 0 ? min(1, Double(weekMinutes) / (target * 60)) : 0
        return card(padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)) {
            VStack(alignment: .leading, spacing: 12) {
                Text(d("Haftada kaç gün")).font(KFont.ui(14, lang: lang)).foregroundStyle(C.text2)
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { n in
                        let on = n == settings.studyDays
                        Button { update { $0.studyDays = n } } label: {
                            Text(Format.num(n, lang))
                                .font(KFont.ui(15, .semibold, lang: lang))
                                .foregroundStyle(on ? Color(hex: 0xFFFCF6) : C.text)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(on ? C.pri : C.sub, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(on ? .clear : C.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? [.isSelected] : [])
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(d("Haftada kaç gün"))
                HStack(spacing: 10) {
                    Text(d("Günde ortalama")).font(KFont.ui(14, lang: lang)).foregroundStyle(C.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button { update { $0.studyHours = max(0.5, $0.studyHours - 0.5) } } label: {
                        KIcon(name: .minus, size: 16, width: 2.2).foregroundStyle(C.text)
                            .frame(width: 40, height: 40)
                            .background(C.sub, in: Circle())
                            .overlay(Circle().stroke(C.line, lineWidth: 1))
                    }
                    .accessibilityLabel(d("Azalt"))
                    Text(hoursText(settings.studyHours) + d(" sa"))
                        .font(KFont.ui(18, .bold, lang: lang)).foregroundStyle(C.text)
                        .frame(minWidth: 64)
                    Button { update { $0.studyHours = min(8, $0.studyHours + 0.5) } } label: {
                        KIcon(name: .plus, size: 16, width: 2.2).foregroundStyle(Color(hex: 0xFFFCF6))
                            .frame(width: 40, height: 40)
                            .background(C.pri, in: Circle())
                    }
                    .accessibilityLabel(d("Artır"))
                }
                divider
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(d("Bu hafta")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(C.text)
                        Spacer(minLength: 0)
                        Text(studyDuration(weekMinutes, prefs) + " / " + hoursText(target) + d(" sa hedef"))
                            .font(mono(12, .regular)).foregroundStyle(C.text2)
                    }
                    GeometryReader { g in
                        Capsule().fill(C.sub)
                            .overlay(alignment: .leading) { Capsule().fill(C.amb).frame(width: g.size.width * pct) }
                    }
                    .frame(height: 8)
                    .environment(\.layoutDirection, lang.layoutDirection)
                    Button { app.go(.progress) } label: {
                        Text(d("Haftalık çalışma raporu") + (lang.isRTL ? " ←" : " →"))
                            .font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(C.priText)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Language

    private var langCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text(d("Uygulama dili")).font(KFont.ui(15, lang: lang)).foregroundStyle(C.text)
                segmented(d("Uygulama dili"), Lang.allCases.map { ($0, $0.name) }, selected: lang, columns: 4) { l in
                    prefs.lang = l
                    Task { await AccountAPI.saveLang(l) }
                }
            }
            .padding(.vertical, 12)
            divider
            HStack(spacing: 10) {
                Text(d("Çeviri dilleri")).font(KFont.ui(15, lang: lang)).foregroundStyle(C.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Separate texts in a left-to-right row keep the order English · فارسی · العربية (a dot written together
                // with a right-to-left name jumps to its other side).
                HStack(spacing: 0) {
                    ForEach(Array(["English", "فارسی", "العربية"].enumerated()), id: \.offset) { i, name in
                        if i > 0 { Text(" · ") }
                        Text(name)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                .font(KFont.ui(14, lang: .fa)).foregroundStyle(C.text3)
            }
            .frame(minHeight: 52)
            divider
            VStack(alignment: .leading, spacing: 8) {
                Text(d("Çeviri tarzı")).font(KFont.ui(15, lang: lang)).foregroundStyle(C.text)
                segmented(d("Çeviri tarzı"), [(TranslationStyle.literal, d("Düz çeviri")), (.natural, d("Doğal anlatım"))],
                          selected: settings.translationStyle, columns: 2) { v in update { $0.translationStyle = v } }
                Text(d(settings.translationStyle == .literal
                       ? "Hocanın cümlesi kelimesi kelimesine çevrilir; terimleri aynen öğrenmek için."
                       : "Aynı anlam o dilde doğal konuşulduğu gibi anlatılır; daha kolay anlaşılır."))
                    .font(KFont.ui(12, lang: lang)).kLineHeight(1.4, size: 12, lang: lang).foregroundStyle(C.text3)
            }
            .padding(.vertical, 10)
            divider
            // "Content language" (CLAUDE.md): quiz questions, cards and summaries; the interface stays in the app language.
            VStack(alignment: .leading, spacing: 8) {
                Text(prefs.t("contentLang")).font(KFont.ui(15, lang: lang)).foregroundStyle(C.text)
                let options: [(ContentLangChoice, String)] = [(.pdf, prefs.t("clSamePdf")), (.app, prefs.t("clSameApp"))]
                    + [(.tr, Lang.tr.name), (.en, Lang.en.name), (.fa, Lang.fa.name), (.ar, Lang.ar.name)]
                segmented(prefs.t("contentLang"), options, selected: settings.contentLang, columns: 3) { v in update { $0.contentLang = v } }
                Text(prefs.t("contentLangHint"))
                    .font(KFont.ui(12, lang: lang)).kLineHeight(1.4, size: 12, lang: lang).foregroundStyle(C.text3)
            }
            .padding(.vertical, 10)
            divider
            Button { app.go(.profile) } label: {
                HStack(spacing: 10) {
                    Text(d("Bölüm")).font(KFont.ui(15, lang: lang)).foregroundStyle(C.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(profile.department.isEmpty ? "—" : d(profile.department)).font(KFont.ui(14, lang: lang)).foregroundStyle(C.text3)
                    chevron()
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Voice

    private var voiceCard: some View {
        card {
            HStack(spacing: 10) {
                Text(d("Okuyan ses")).font(KFont.ui(15, lang: lang)).foregroundStyle(C.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                segmented(d("Okuyan ses"), [(TTSVoice.female, d("Kadın")), (.male, d("Erkek"))], selected: settings.ttsVoice, height: 34) { v in
                    update { $0.ttsVoice = v }
                }
            }
            .frame(minHeight: 56)
            divider
            VStack(spacing: 8) {
                HStack {
                    Text(d("Okuma hızı")).font(KFont.ui(15, lang: lang)).foregroundStyle(C.text)
                    Spacer()
                    Text(rateText(settings.ttsRate)).font(KFont.mono(13, .semibold)).foregroundStyle(C.priText)
                }
                Slider(value: Binding(get: { settings.ttsRate }, set: { settings.ttsRate = ($0 * 10).rounded() / 10 }), in: 0.5...2, step: 0.1) { editing in
                    if !editing { update { _ in } }
                }
                .tint(C.pri)
                .accessibilityLabel(d("Okuma hızı"))
                HStack {
                    ForEach([0.5, 1.0, 2.0], id: \.self) { v in
                        Text(rateText(v)).font(KFont.mono(10, .regular)).foregroundStyle(C.text3)
                        if v != 2.0 { Spacer() }
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    /// "1,0×" as the design writes it.
    private func rateText(_ v: Double) -> String {
        let s = String(format: "%.1f", v)
        return (lang == .en ? s : s.replacingOccurrences(of: ".", with: ",")) + "×"
    }

    // MARK: Notifications

    private var notifyDate: Binding<Date> {
        Binding(
            get: {
                let parts = settings.notifyTime.split(separator: ":").compactMap { Int($0) }
                return Calendar.current.date(bySettingHour: parts.first ?? 9, minute: parts.dropFirst().first ?? 0, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                let text = String(format: "%02d:%02d", c.hour ?? 9, c.minute ?? 0)
                if text != settings.notifyTime { update(reminder: true) { $0.notifyTime = text } }
            }
        )
    }

    private var notifCard: some View {
        card {
            switchRow(d("Tekrar hatırlatıcısı"), d("Tekrar günlerinde bildirim gönder"), on: settings.reviewReminder) {
                update(reminder: true) { $0.reviewReminder.toggle() }
            }
            switchRow(d("Tebrik bildirimleri"), d("Bir dersinde ortalaman %10'dan fazla artınca"), on: settings.cheerNotifications) {
                update { $0.cheerNotifications.toggle() }
                toast.show(d(settings.cheerNotifications ? "Tebrik bildirimleri açık" : "Tebrik bildirimleri kapatıldı"))
            }
            HStack(spacing: 10) {
                Text(d("Bildirim saati")).font(KFont.ui(15, lang: lang)).foregroundStyle(C.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // The design's time chip; a small sheet with the time wheel opens from it.
                Button { pickedTime = notifyDate.wrappedValue; timeOpen = true } label: {
                    Text(Format.num(settings.notifyTime, lang))
                        .font(KFont.mono(14, .regular)).foregroundStyle(C.text)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(C.sub, in: RoundedRectangle(cornerRadius: 8))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(d("Bildirim saati"))
                .accessibilityValue(settings.notifyTime)
            }
            .frame(minHeight: 52)
        }
    }

    /// The time wheel opened from the "Bildirim saati" chip (a bottom sheet like the design's dialogs).
    private var timeSheet: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0x140E0A, opacity: 0.45).ignoresSafeArea().onTapGesture { timeOpen = false }
            VStack(spacing: 8) {
                Capsule().fill(Color.pair(0xE2D7C6, 0x4A403A)).frame(width: 40, height: 5)
                Text(d("Bildirim saati")).font(KFont.ui(17, .semibold, lang: lang)).foregroundStyle(C.text).padding(.top, 8)
                DatePicker(d("Bildirim saati"), selection: $pickedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                Button {
                    notifyDate.wrappedValue = pickedTime
                    timeOpen = false
                } label: {
                    Text(prefs.t("save"))
                        .font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(Color(hex: 0xFFFCF6))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(C.pri, in: Capsule())
                }
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 34)
            .background(Color.pair(0xFFFBF4, 0x221C18), in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
            .accessibilityAddTraits(.isModal)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Appearance

    private var lookCard: some View {
        card(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)) {
            segmented(d("Görünüm"), [(ThemeChoice.light, d("Açık")), (.dark, d("Koyu")), (.system, prefs.t("k141"))],
                      selected: prefs.theme, height: 38, columns: 3) { v in
                prefs.theme = v
                update { $0.appTheme = v }
            }
            Button {
                UserDefaults.standard.removeObject(forKey: "kavis.pdfPos")
                toast.show(d("Düğmeler eski yerine döndü"))
            } label: {
                HStack(spacing: 10) {
                    KIcon(name: .refresh, size: 18, width: 1.7)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d("Düğmelerin yerini sıfırla")).font(KFont.ui(14, .medium, lang: lang))
                        Text(d("Tam ekran PDF'teki kalem ve asistan düğmeleri eski yerine döner."))
                            .font(KFont.ui(12, lang: lang)).foregroundStyle(C.text3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(C.text)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(minHeight: 44)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(C.line, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
    }

    // MARK: Offline (every plan, CLAUDE.md)

    private var offlineCard: some View {
        card {
            switchRow(d("Çevrimdışı mod"), d("İnternet olmadan kayıtlı derslerinle çalış"), on: settings.offlineMode, minHeight: 60) {
                update { $0.offlineMode.toggle() }
                toast.show(d(settings.offlineMode ? "Çevrimdışı mod açık · kayıtlı derslerinle çalışabilirsin" : "Çevrimiçi moda dönüldü"))
            }
            switchRow(d("Çalıştığım PDF'leri indir"), d("Açtığın her PDF cihazına kaydedilir"), on: settings.autoDownload, minHeight: 60) {
                update { $0.autoDownload.toggle() }
                toast.show(d(settings.autoDownload ? "Açtığın PDF'ler cihazına kaydedilecek" : "Otomatik indirme kapatıldı"))
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(d("Cihazdaki dersler")).font(KFont.ui(15, lang: lang)).foregroundStyle(C.text)
                    Spacer()
                    Text("\(Format.num(pdfCount, lang)) PDF").font(KFont.mono(12, .regular)).foregroundStyle(C.text2)
                }
                Capsule().fill(C.sub).frame(height: 6)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in Capsule().fill(C.pri).frame(width: g.size.width * 0.18) }
                    }
                HStack(alignment: .top, spacing: 10) {
                    KIcon(name: .lock, size: 16, width: 1.8).foregroundStyle(C.ok).padding(.top, 1)
                    Text(d("PDF'lerin yalnızca uygulamanın içinde, şifreli saklanır. Telefonunun dosyalarında görünmez, başka uygulamalarla paylaşılamaz."))
                        .font(KFont.ui(12, lang: lang)).kLineHeight(1.45, size: 12, lang: lang).foregroundStyle(C.text2)
                }
                Button(action: soon) {
                    Text(d("Cihazdaki dersleri yönet"))
                        .font(KFont.ui(12, lang: lang)).foregroundStyle(C.text)
                        .padding(.horizontal, 12).frame(height: 34)
                        .overlay(Capsule().stroke(C.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: My devices (max 2 per account; the web counts as one)

    private var devicesCard: some View {
        card {
            Text(prefs.t("devHint"))
                .font(KFont.ui(12, lang: lang)).kLineHeight(1.4, size: 12, lang: lang).foregroundStyle(C.text3)
                .padding(.vertical, 12)
            ForEach(devices) { device in
                divider
                HStack(spacing: 12) {
                    KIcon(name: device.kind == .web || device.kind == .mac ? .globe : .person, size: 18, width: 1.7)
                        .foregroundStyle(C.priText)
                        .frame(width: 34, height: 34)
                        .background(C.priSoft, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name).font(KFont.ui(15, lang: lang)).foregroundStyle(C.text)
                        Text(device.current ? prefs.t("devThis") + " · " + prefs.t("devActiveNow")
                             : device.lastUsed.map { prefs.t("devLastUsed", ["t": Format.lastSeen($0, lang)]) } ?? "")
                            .font(KFont.ui(12, lang: lang)).foregroundStyle(C.text3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !device.current {
                        Button {
                            Task {
                                if await DevicesAPI.signOutDevice(id: device.id) {
                                    devices.removeAll { $0.id == device.id }
                                    toast.show(prefs.t("devSignedOut", ["name": device.name]))
                                } else {
                                    toast.show(prefs.t("delFailed"))
                                }
                            }
                        } label: {
                            Text(prefs.t("devSignOut"))
                                .font(KFont.ui(12, .medium, lang: lang)).foregroundStyle(C.bad)
                                .padding(.horizontal, 12).frame(height: 34)
                                .overlay(Capsule().stroke(C.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(minHeight: 60)
            }
        }
    }

    // MARK: Timetable, help

    private func linkRow(_ icon: KIconName, chip: Color, fg: Color, _ title: String, _ sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                KIcon(name: icon, size: 18, width: 1.8).foregroundStyle(fg)
                    .frame(width: 34, height: 34).background(chip, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(KFont.ui(15, lang: lang)).foregroundStyle(C.text)
                    Text(sub).font(KFont.ui(12, lang: lang)).foregroundStyle(C.text3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                chevron()
            }
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func plainRow(_ title: String, color: Color = C.text, arrow: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(KFont.ui(15, lang: lang)).foregroundStyle(color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if arrow { chevron() }
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var scheduleCard: some View {
        card {
            linkRow(.calendar, chip: C.amb, fg: Color(hex: 0x2A2420), d("Ders programım"), d("Programını ekle · dersten bir gün önce hatırlatayım"), action: { app.go(.timetable) })
        }
    }

    private var helpCard: some View {
        card {
            linkRow(.chat, chip: Color(hex: 0x9C2F3A), fg: Color(hex: 0xFFFCF6), d("Destekle konuş"), d("Bir sorun mu gördün? Bize yaz, çözelim")) {
                // Support by e-mail: opens the mail app with the address and a subject (the same as the web).
                var c = URLComponents()
                c.scheme = "mailto"
                c.path = Self.supportEmail
                c.queryItems = [URLQueryItem(name: "subject", value: prefs.t("supportSubject"))]
                if let url = c.url { openURL(url) }
            }
            divider
            plainRow(d("Sık sorulanlar")) { if let url = URL(string: "\(Config.webBaseURL)/help?lang=\(lang.rawValue)") { openURL(url) } }
        }
    }

    // MARK: Privacy

    private var privacyCard: some View {
        card {
            HStack(alignment: .top, spacing: 10) {
                KIcon(name: .shield, size: 20, width: 1.7).foregroundStyle(C.ok).padding(.top, 2)
                Text(d("PDF'lerin yalnızca senin hesabında saklanır ve başka kimseyle paylaşılmaz. Asistan istersen sadece senin PDF'lerini, istersen yapay zekâ araştırmasını da kullanır."))
                    .font(KFont.ui(13, lang: lang)).kLineHeight(1.45, size: 13, lang: lang).foregroundStyle(C.text2)
            }
            .padding(.vertical, 12)
            divider
            plainRow(d("Hesap bilgilerimi iste")) {
                toast.show(prefs.t("expMaking"))
                Task {
                    if let url = await AccountAPI.requestMyData() { exportFile = ExportFile(url: url) } else { toast.show(prefs.t("expFailed")) }
                }
            }
            divider
            if let date = deletionDate {
                // A deletion was asked for: the account stays until that day, "Vazgeç" cancels it.
                HStack(spacing: 10) {
                    Text(prefs.t("delBanner", ["date": dayText(date)]))
                        .font(KFont.ui(14, lang: lang)).foregroundStyle(C.bad)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        Task {
                            if await AccountAPI.cancelDeletion() {
                                deletionDate = nil
                                toast.show(prefs.t("delUndone"))
                            } else {
                                toast.show(prefs.t("delFailed"))
                            }
                        }
                    } label: {
                        Text(prefs.t("delUndo"))
                            .font(KFont.ui(12, .medium, lang: lang)).foregroundStyle(C.text)
                            .padding(.horizontal, 12).frame(height: 34)
                            .overlay(Capsule().stroke(C.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 10)
                .frame(minHeight: 52)
            } else {
                plainRow(d("Hesabı sil"), color: C.bad, arrow: false) { deleteOpen = true }
            }
        }
    }
}

/// The exported data file, shown in the share sheet.
private struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.path }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// "Hesabın silinsin mi?" (design ScrSettings dialog). The password once more, like the web, so nobody deletes the
/// account from a phone left open. The account is deleted after 30 days; until then the student can change their mind.
private struct DeleteAccountSheet: View {
    @Environment(AppPrefs.self) private var prefs
    var onClose: () -> Void
    var onDone: (Date) -> Void

    @State private var password = ""
    @State private var error = ""
    @State private var busy = false

    private var lang: Lang { prefs.lang }
    private static let bad = Color.pair(0xC0352B, 0xF27A70)

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0x140E0A, opacity: 0.45).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(alignment: .leading, spacing: 12) {
                Capsule().fill(Color.pair(0xE2D7C6, 0x4A403A)).frame(width: 40, height: 5)
                    .frame(maxWidth: .infinity).padding(.bottom, 8)
                KIcon(name: .trash, size: 24, width: 1.7).foregroundStyle(Self.bad)
                    .frame(width: 52, height: 52)
                    .background(Color.pair(0xFCE8E6, 0x3D1F1F), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(prefs.t("delTitle")).font(KFont.ui(21, .bold, lang: lang)).foregroundStyle(KPhone.text)
                Text(prefs.t("delText")).font(KFont.ui(15, lang: lang)).kLineHeight(1.5, size: 15, lang: lang).foregroundStyle(KPhone.text2)
                Text(prefs.t("delSub")).font(KFont.ui(14, lang: lang)).kLineHeight(1.5, size: 14, lang: lang).foregroundStyle(KPhone.text)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.pair(0xF4EFE6, 0x2B2520), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(prefs.t("delWait")).font(KFont.ui(13, lang: lang)).kLineHeight(1.45, size: 13, lang: lang).foregroundStyle(KPhone.text2)
                SecureField(prefs.t("delPassHint"), text: $password)
                    .textContentType(.password)
                    .font(KFont.ui(15, lang: lang)).foregroundStyle(KPhone.text)
                    .padding(.horizontal, 20).frame(height: 52)
                    .background(KPhone.card, in: Capsule())
                    .overlay(Capsule().stroke(error.isEmpty ? KPhone.line : Self.bad, lineWidth: 1))
                    .onChange(of: password) { error = "" }
                if !error.isEmpty {
                    Text(error).font(KFont.ui(13, lang: lang)).foregroundStyle(Self.bad)
                }
                Button { Task { await confirm() } } label: {
                    Text(prefs.t("k161"))
                        .font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(Color(hex: 0xFFFCF6))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.pair(0xC0352B, 0xB23A47), in: Capsule())
                        .opacity(busy ? 0.6 : 1)
                }
                .disabled(busy)
                .padding(.top, 6)
                Button(action: onClose) {
                    Text(prefs.t("delCancel"))
                        .font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 34)
            .background(Color.pair(0xFFFBF4, 0x221C18), in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 20, y: -10)
            .accessibilityAddTraits(.isModal)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func confirm() async {
        guard !password.isEmpty else { return error = prefs.t("delPassHint") }
        busy = true
        let r = await AccountAPI.deleteAccount(password: password)
        busy = false
        switch r {
        case .success(let date): onDone(date)
        case .failure(.password): error = prefs.t("delPassWrong")
        case .failure: error = prefs.t("delFailed")
        }
    }
}
