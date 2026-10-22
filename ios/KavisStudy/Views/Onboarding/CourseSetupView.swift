import SwiftUI

/// Design: design/NewCourses.dc.html, variant "setup" ("Dönem derslerim"). Last step of the onboarding:
/// the student picks this term's courses and which ones were already started. "Klasörümü oluştur" goes home.
struct CourseSetupView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast

    /// Suggestions of the design (pharmacy, year 3). Per-department suggestions come with the real server.
    static let suggestions = ["Farmakoterapi", "Toksikoloji", "Farmasötik Teknoloji III", "Farmakognozi", "Farmasötik Kimya II", "Biyofarmasötik", "Klinik Eczacılık"]
    private static let defaultSelection = ["Farmakoterapi", "Toksikoloji", "Farmasötik Teknoloji III", "Farmakognozi", "Farmasötik Kimya II"]

    @State private var all = CourseSetupView.suggestions
    @State private var selected = CourseSetupView.defaultSelection
    @State private var started = false
    @State private var done: Set<String> = []
    @State private var typed = ""
    @State private var extra = 0
    @State private var busy = false
    @FocusState private var focused: Bool

    private var lang: Lang { prefs.lang }
    private func d(_ turkish: String) -> String { prefs.d(turkish) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(d("2026–2027 Güz dönemi"))
                        .font(KFont.ui(12, .semibold, lang: lang))
                        .foregroundStyle(KPhone.tile2Text)
                        .padding(.horizontal, 14).frame(height: 32)
                        .background(KPhone.tile2, in: Capsule())
                    (Text("\(d("Bu dönem hangi")) ").foregroundStyle(KPhone.text).font(KFont.ui(30, .medium, lang: lang))
                        + Text(d("dersleri alıyorsun?")).foregroundStyle(KPhone.text3).font(KFont.ui(30, .regular, lang: lang)))
                        .kTracking(-0.03, size: 30, lang: lang)
                        .kLineHeight(1.12, size: 30, lang: lang)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(d("Her ders için bir klasör açarız. PDF'lerin, sınavların ve kartların o klasörde toplanır."))
                        .font(KFont.ui(14, lang: lang))
                        .kLineHeight(1.55, size: 14, lang: lang)
                        .foregroundStyle(KPhone.text2)
                        .padding(.top, -6)
                        .fixedSize(horizontal: false, vertical: true)
                    addRow
                    suggestionChips
                    termState
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KPhone.authBg.ignoresSafeArea())
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 12) {
            Button { app.reset(to: .home) } label: {
                KIcon(name: .back, size: 20, width: 1.8, flipsInRTL: true)
                    .foregroundStyle(KPhone.text)
                    .frame(width: 46, height: 46)
                    .background(KPhone.card, in: Circle())
                    .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
            }
            .accessibilityLabel(prefs.t("signup.k1052"))
            Text(d("Dönem derslerim"))
                .font(KFont.ui(16, .semibold, lang: lang))
                .foregroundStyle(KPhone.text)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            Button(action: addCourse) {
                KIcon(name: .plus, size: 20, width: 1.7)
                    .foregroundStyle(KPhone.text)
                    .frame(width: 46, height: 46)
                    .background(KPhone.card, in: Circle())
                    .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
            }
            .accessibilityLabel(d("Ders ekle"))
        }
        .padding(.horizontal, 20)
        .padding(.top, KLayout.top(60, minimum: 6))
        .padding(.bottom, 6)
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            TextField("", text: $typed, prompt: Text(d("Ders adı yaz (ör. Biyokimya)")).foregroundStyle(KPhone.text3))
                .font(KFont.ui(15, lang: lang))
                .foregroundStyle(KPhone.text)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(addCourse)
                .frame(height: 44)
                .accessibilityLabel(d("Ders adı"))
            Button(action: addCourse) {
                KIcon(name: .plus, size: 20, width: 2)
                    .foregroundStyle(KPhone.ctaText)
                    .frame(width: 44, height: 44)
                    .background(KPhone.cta, in: Circle())
            }
            .accessibilityLabel(d("Ders ekle"))
        }
        .padding(.leading, 20).padding(.trailing, 5).padding(.vertical, 5)
        .background(KPhone.card, in: Capsule())
        .overlay(Capsule().stroke(focused ? KPhone.focus : KPhone.line, lineWidth: focused ? 1.5 : 1))
    }

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(d("Eczacılık 3. sınıf için öneriler · dokunarak seç")).font(KFont.ui(13, lang: lang)).foregroundStyle(KPhone.text2)
            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(all, id: \.self) { name in
                    let on = selected.contains(name)
                    Button { toggle(name) } label: {
                        HStack(spacing: 8) {
                            KIcon(name: on ? .check : .plus, size: 13, width: 2.6)
                                .foregroundStyle(on ? KPhone.ctaText : KPhone.text2)
                                .frame(width: 26, height: 26)
                                .background(on ? Color(hex: 0xFFFCF6, opacity: 0.22) : KPhone.sub, in: Circle())
                            Text(d(name)).font(KFont.ui(14, lang: lang)).foregroundStyle(on ? KPhone.ctaText : KPhone.text)
                        }
                        .padding(.leading, 8).padding(.trailing, 14)
                        .frame(height: 42)
                        .background(on ? KPhone.cta : KPhone.card, in: Capsule())
                        .overlay(Capsule().stroke(on ? .clear : KPhone.line, lineWidth: 1))
                    }
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    /// "Dönem başladı mı?": new term, or already started and some courses studied.
    private var termState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(d("Dönem başladı mı?")).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text)
            HStack(spacing: 4) {
                segment(d("Yeni başlıyor"), on: !started) { started = false }
                segment(d("Başladı, bazılarını çalıştım"), on: started) { started = true }
            }
            .padding(4)
            .background(KPhone.sub, in: Capsule())
            .accessibilityElement(children: .contain)
            .accessibilityLabel(d("Dönem durumu"))
            if started {
                Text(d("Hangi dersleri çalışmaya başladın?")).font(KFont.ui(13, lang: lang)).foregroundStyle(KPhone.text2)
                FlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(selected, id: \.self) { name in
                        let on = done.contains(name)
                        Button { if on { done.remove(name) } else { done.insert(name) } } label: {
                            HStack(spacing: 6) {
                                KIcon(name: on ? .check : .plus, size: 14, width: 2.4)
                                Text(d(name)).font(KFont.ui(13, lang: lang))
                            }
                            .foregroundStyle(on ? KPhone.tile2Text : KPhone.text)
                            .padding(.leading, 10).padding(.trailing, 14)
                            .frame(height: 38)
                            .background(on ? KPhone.tile2 : KPhone.card, in: Capsule())
                            .overlay(Capsule().stroke(on ? KPhone.bannerLine : KPhone.line, lineWidth: on ? 1.5 : 1))
                        }
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            HStack(alignment: .top, spacing: 8) {
                KIcon(name: .info, size: 14, width: 1.8).padding(.top, 2)
                Text(placementNote).font(KFont.ui(12, lang: lang)).kLineHeight(1.45, size: 12, lang: lang)
            }
            .foregroundStyle(KPhone.text2)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kPhoneCard()
    }

    private var placementNote: String {
        let n = selected.filter(done.contains).count
        guard started, n > 0 else { return d("Çalışmaya başladığın dersleri seç") }
        return Format.num(n, lang) + d(" dersin PDF'ini yükleyince kısa seviye tespit sınavı önereceğim · bildiğin konuları atlarız")
    }

    private func segment(_ text: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(KFont.ui(13, on ? .semibold : .regular, lang: lang))
                .foregroundStyle(KPhone.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(on ? KPhone.card : .clear, in: Capsule())
                .shadow(color: on ? Color(hex: 0x2A2420, opacity: 0.14) : .clear, radius: 2, y: 1)
        }
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button { Task { await create() } } label: {
                // Three parts, not one string: in right-to-left text the dot and the number would swap places.
                let name = d("Klasörümü oluştur · ").trimmingCharacters(in: CharacterSet(charactersIn: " ·"))
                let count = "\(selected.count)\(d(" ders"))"
                HStack(spacing: 6) {
                    Text(name)
                    Text("·")
                    Text(count)
                }
                .font(KFont.ui(17, .medium, lang: lang))
                .foregroundStyle(KPhone.ctaText)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(KPhone.cta, in: Capsule())
                .shadow(color: Color(hex: 0x9C2F3A, opacity: 0.28), radius: 15, y: 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(name) · \(count)")
            }
            .disabled(busy)
            Text(d("Dersleri sonra Derslerim klasöründen değiştirebilirsin")).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text3)
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
    }

    // MARK: Actions

    private func toggle(_ name: String) {
        if let i = selected.firstIndex(of: name) { selected.remove(at: i); done.remove(name) } else { selected.append(name) }
    }

    /// The typed name (or "Yeni ders N") is added and selected.
    private func addCourse() {
        let name = typed.trimmingCharacters(in: .whitespaces)
        let course: String
        if name.isEmpty {
            extra += 1
            course = "\(Strings.design("Yeni ders ", .tr))\(extra)"
        } else {
            course = name
        }
        if !all.contains(course) { all.append(course) }
        if !selected.contains(course) { selected.append(course) }
        typed = ""
    }

    /// Creates the folders and goes home.
    private func create() async {
        guard !busy else { return }
        busy = true
        _ = await CoursesAPI.createTermFolders(TermSetup(courses: selected, started: started ? selected.filter(done.contains) : []))
        app.reset(to: .home)
    }
}
