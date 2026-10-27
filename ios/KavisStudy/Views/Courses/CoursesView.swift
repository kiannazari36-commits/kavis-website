import SwiftUI

/// Design: design/NewCourses.dc.html, variants "list" ("Derslerim") and "detail" ("Ders klasörü").
/// Real data: the student's courses, lessons, reading progress and study minutes (CoursesAPI, the same as the web).
/// The design's "Cihazımdakiler" filter and "CİHAZDA" tags come with offline downloads (not built yet).

/// The design's folder colours: card, text and tab per course colour.
private enum FolderPalette {
    static func colors(_ c: CourseColor?) -> (bg: Color, fg: Color, tab: Color) {
        switch c {
        case .red: (.pair(0xF5E3E2, 0x3A2224), .pair(0x9C2F3A, 0xF09AA3), .pair(0xE9C3C2, 0x5A2A30))
        case .amb: (.pair(0xFBEBC8, 0x3A2E18), .pair(0xA86F0E, 0xF2C66D), .pair(0xF2D59A, 0x5A4520))
        case .vio: (.pair(0xE8E6F6, 0x2C2A3A), .pair(0x4A3F9A, 0xB9B4F0), .pair(0xD3CFF0, 0x3E3A5A))
        case .grn: (.pair(0xE3F1E7, 0x1F3328), .pair(0x2E7D4F, 0x8FD3A8), .pair(0xC3E2CD, 0x2C4A38))
        case .teal: (.pair(0xDFF0F1, 0x1C3134), .pair(0x1F6E75, 0x8CCFD6), .pair(0xBEDFE2, 0x284549))
        case nil: (.pair(0xEFE8DC, 0x2B2520), .pair(0x6E645A, 0xBDB2A4), .pair(0xE0D6C6, 0x3A322B))
        }
    }
    static let track = Color.pair(0xEAE1D2, 0x3A322B)
    static let line2 = Color.pair(0xD6C8B2, 0x4A4038)
    static let glass = Color(light: Color(hex: 0xFFFCF6, opacity: 0.7), dark: Color(hex: 0xFFF0D2, opacity: 0.08))
    static let time = Color(hex: 0xE8925A)
}

/// "12 dk", "2 sa 5 dk" in the design's words.
private func minutesText(_ m: Int, _ d: (String) -> String) -> String {
    if m <= 0 { return d("0 dk") }
    if m < 60 { return "\(m)\(d(" dk"))" }
    return "\(m / 60)\(d(" sa"))" + (m % 60 > 0 ? " \(m % 60)\(d(" dk"))" : "")
}

private struct CourseHeader: View {
    @Environment(AppPrefs.self) private var prefs
    let title: String
    let actionLabel: String
    var onBack: () -> Void
    var onAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                KIcon(name: .back, size: 20, width: 1.8, flipsInRTL: true)
                    .foregroundStyle(KPhone.text)
                    .frame(width: 46, height: 46)
                    .background(KPhone.card, in: Circle())
                    .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
            }
            .accessibilityLabel(prefs.t("signup.k1052"))
            Text(title)
                .font(KFont.ui(16, .semibold, lang: prefs.lang))
                .foregroundStyle(KPhone.text)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            Button(action: onAction) {
                KIcon(name: .plus, size: 20, width: 1.7)
                    .foregroundStyle(KPhone.text)
                    .frame(width: 46, height: 46)
                    .background(KPhone.card, in: Circle())
                    .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
            }
            .accessibilityLabel(actionLabel)
        }
        .padding(.horizontal, 20)
        .padding(.top, KLayout.top(60, minimum: 6))
        .padding(.bottom, 6)
    }
}

// MARK: - Derslerim

struct CoursesListView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast

    @State private var courses: [Course] = CoursesAPI.lastCourses
    @State private var loaded = false
    @State private var adding = false
    @State private var newName = ""

    private var lang: Lang { prefs.lang }
    private func d(_ turkish: String) -> String { prefs.d(turkish) }

    var body: some View {
        VStack(spacing: 0) {
            CourseHeader(title: d("Derslerim"), actionLabel: d("Ders ekle"), onBack: { app.back() }, onAction: { adding = true })
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    (Text("\(d("Derslerim")) ") + Text(termWord).foregroundStyle(KPhone.text3).fontWeight(.regular))
                        .font(KFont.ui(32, .medium, lang: lang))
                        .kTracking(-0.03, size: 32, lang: lang)
                        .foregroundStyle(KPhone.text)
                        .accessibilityAddTraits(.isHeader)
                    totals
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(courses) { folder($0) }
                        addTile
                    }
                    if !share.isEmpty { weekShare }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .refreshable { courses = await CoursesAPI.listCourses() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KPhone.authBg.ignoresSafeArea())
        .task {
            guard !loaded else { return }
            loaded = true
            courses = await CoursesAPI.listCourses()
        }
        .alert(d("Ders ekle"), isPresented: $adding) {
            TextField(prefs.t("wel_coursePh"), text: $newName)
            Button(prefs.t("wel_addShort")) { Task { await add() } }
            Button(prefs.t("schCancel"), role: .cancel) { newName = "" }
        }
    }

    /// "· Güz" / "· Bahar" from the term.
    private var termWord: String {
        CoursesAPI.termName().hasSuffix("Güz") ? d("· Güz") : "· \(CoursesAPI.termName().components(separatedBy: " ").last ?? "")"
    }

    private var totals: some View {
        let minutes = courses.reduce(0) { $0 + CoursesAPI.stats($1).minutes }
        let pdfs = courses.reduce(0) { $0 + $1.pdfs.count }
        let items: [(String, String)] = [
            (Format.num(courses.count, lang), d("ders sayısı")),
            (Format.num(pdfs, lang), "PDF"),
            ("\(Format.num(minutes / 60, lang))\(d(" sa"))", d("toplam süre")),
        ]
        return HStack(spacing: 8) {
            ForEach(items, id: \.1) { v, l in
                VStack(alignment: .leading, spacing: 2) {
                    Text(v).font(KFont.ui(22, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                    Text(l).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(KPhone.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(KPhone.line, lineWidth: 1))
            }
        }
    }

    private func folder(_ c: Course) -> some View {
        let p = FolderPalette.colors(c.color)
        let st = CoursesAPI.stats(c)
        return Button { app.go(.course(c.id)) } label: {
            ZStack(alignment: .topLeading) {
                UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14, style: .continuous)
                    .fill(p.tab)
                    .frame(width: 64, height: 26)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(Format.num(c.pdfs.count, lang)) PDF").font(KFont.mono(11, .semibold)).foregroundStyle(p.fg)
                        Spacer()
                        Text(minutesText(st.minutes, d)).font(KFont.ui(11, lang: lang)).foregroundStyle(KPhone.text2)
                    }
                    Text(c.name[lang])
                        .font(KFont.ui(16, .semibold, lang: lang))
                        .foregroundStyle(KPhone.text)
                        .lineLimit(3)
                        .frame(minHeight: 40, alignment: .topLeading)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(FolderPalette.track)
                                Capsule().fill(p.fg).frame(width: g.size.width * CGFloat(st.percent) / 100)
                            }
                        }
                        .frame(height: 6)
                        Text("%\(Format.num(st.percent, lang))").font(KFont.mono(12, .semibold)).foregroundStyle(KPhone.text)
                    }
                    Text(c.pdfs.isEmpty ? d("Henüz PDF yok") : c.exam[lang])
                        .font(KFont.ui(11, lang: lang))
                        .foregroundStyle(KPhone.text2)
                        .lineLimit(1)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
                .background(p.bg, in: UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 22, bottomTrailingRadius: 22, topTrailingRadius: 22, style: .continuous))
                .padding(.top, 14)
            }
        }
        .buttonStyle(.plain)
    }

    private var addTile: some View {
        Button { adding = true } label: {
            VStack(spacing: 8) {
                KIcon(name: .plus, size: 20, width: 2)
                    .foregroundStyle(KPhone.text)
                    .frame(width: 44, height: 44)
                    .background(KPhone.card, in: Circle())
                Text(d("Ders ekle")).font(KFont.ui(14, lang: lang)).foregroundStyle(KPhone.text2)
            }
            .frame(maxWidth: .infinity, minHeight: 168)
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(FolderPalette.line2, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
            .padding(.top, 14)
        }
        .buttonStyle(.plain)
    }

    /// "Bu hafta hangi derse ne kadar?": each course's share of the study minutes.
    private var share: [(name: String, pct: Int, color: Color)] {
        let total = max(1, courses.reduce(0) { $0 + CoursesAPI.stats($1).minutes })
        return courses.compactMap { c in
            let m = CoursesAPI.stats(c).minutes
            guard m > 0 else { return nil }
            return (c.name[lang].components(separatedBy: " ").first ?? c.name[lang], Int((Double(m) / Double(total) * 100).rounded()), FolderPalette.colors(c.color).fg)
        }
    }

    private var weekShare: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(d("Bu hafta hangi derse ne kadar?")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text)
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(share, id: \.name) { s in
                        Rectangle().fill(s.color).frame(width: max(2, (g.size.width - CGFloat(share.count * 2)) * CGFloat(s.pct) / 100))
                    }
                }
            }
            .frame(height: 14)
            .clipShape(Capsule())
            FlowLayout(spacing: 14, rowSpacing: 6) {
                ForEach(share, id: \.name) { s in
                    HStack(spacing: 6) {
                        Circle().fill(s.color).frame(width: 8, height: 8)
                        Text("\(s.name) · %\(Format.num(s.pct, lang))").font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KPhone.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(KPhone.line, lineWidth: 1))
    }

    private func add() async {
        let name = newName.trimmingCharacters(in: .whitespaces)
        newName = ""
        guard !name.isEmpty else { return toast.show(prefs.t("wel_needName")) }
        if courses.contains(where: { $0.name.tr.lowercased() == name.lowercased() }) { return toast.show(prefs.t("wel_exists")) }
        if await CoursesAPI.createCourses([name]) {
            courses = await CoursesAPI.listCourses()
            toast.show(prefs.t("wel_added", ["x": name]))
        } else {
            toast.show(prefs.t("wel_failed"))
        }
    }
}

// MARK: - Ders klasörü

struct CourseFolderView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast

    let courseId: String
    @State private var course: Course?
    @State private var recordings: [RecordingAPI.Item] = []

    private var lang: Lang { prefs.lang }
    private func d(_ turkish: String) -> String { prefs.d(turkish) }

    var body: some View {
        VStack(spacing: 0) {
            CourseHeader(title: d("Ders klasörü"), actionLabel: d("PDF ekle"), onBack: { app.back(fallback: .courses) }, onAction: addPdf)
            ScrollView {
                if let course {
                    VStack(alignment: .leading, spacing: 14) {
                        summary(course)
                        if course.pdfs.isEmpty { empty } else { lessons(course) }
                        if !recordings.isEmpty { recordingList }
                        Button(action: addPdf) {
                            HStack(spacing: 8) {
                                KIcon(name: .plus, size: 18, width: 2)
                                Text(d("Bu derse PDF ekle")).font(KFont.ui(15, .medium, lang: lang))
                            }
                            .foregroundStyle(KPhone.ctaText)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(KPhone.cta, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 36)
                }
            }
            .scrollIndicators(.hidden)
            .refreshable {
                course = await CoursesAPI.getCourse(id: courseId)
                recordings = await RecordingAPI.recordingsOfCourse(courseId)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KPhone.authBg.ignoresSafeArea())
        .task {
            course = CoursesAPI.lastCourses.first { $0.id == courseId }
            course = await CoursesAPI.getCourse(id: courseId)
            recordings = await RecordingAPI.recordingsOfCourse(courseId)
        }
    }

    /// The course's lecture recordings (as on the web's course page); "Kaydı aç" opens the recording page.
    private var recordingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(prefs.t("recList")).font(KFont.ui(18, .medium, lang: lang)).foregroundStyle(KPhone.text)
            ForEach(recordings) { r in
                Button { app.go(.recording(r.id)) } label: {
                    HStack(spacing: 12) {
                        KIcon(name: .mic, size: 22, width: 1.8).foregroundStyle(KPhone.brand)
                            .frame(width: 46, height: 46).background(KPhone.sub, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(r.title).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text).lineLimit(1)
                            Text("\(r.status == "ready" ? Format.clock(r.seconds) : prefs.t(r.status == "failed" ? "recFailedShort" : "recWorkingShort")) · \(r.day)")
                                .font(KFont.ui(11, lang: lang)).foregroundStyle(KPhone.text3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        KIcon(name: .chevron, size: 18, width: 1.8, flipsInRTL: true).foregroundStyle(KPhone.text3)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(KPhone.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(KPhone.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityHint(prefs.t("rec_open"))
            }
        }
    }

    private func addPdf() {
        app.uploadCourseId = courseId
        app.go(.upload(.pdf))
    }

    private func summary(_ c: Course) -> some View {
        let p = FolderPalette.colors(c.color)
        let st = CoursesAPI.stats(c)
        let stat = { (v: String, l: String) in
            VStack(alignment: .leading, spacing: 0) {
                Text(v).font(KFont.ui(20, .semibold, lang: lang)).foregroundStyle(KPhone.text).lineLimit(1).minimumScaleFactor(0.7)
                Text(l).font(KFont.ui(11, lang: lang)).foregroundStyle(KPhone.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(FolderPalette.glass, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(c.exam[lang]).font(KFont.ui(12, .semibold, lang: lang)).foregroundStyle(p.fg)
                Text(c.name[lang]).font(KFont.ui(26, .semibold, lang: lang)).kTracking(-0.02, size: 26, lang: lang).foregroundStyle(KPhone.text)
            }
            HStack(spacing: 8) {
                stat(Format.num(c.pdfs.count, lang), "PDF")
                stat("%\(Format.num(st.percent, lang))", d("okundu"))
                stat(minutesText(st.minutes, d), d("çalışma"))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.bg, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func lessons(_ c: Course) -> some View {
        let ring = FolderPalette.colors(c.color).fg
        let maxM = max(1, c.pdfs.map(\.minutes).max() ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("PDF").font(KFont.ui(18, .medium, lang: lang)).foregroundStyle(KPhone.text)
                Spacer()
                Text(d("Halka = okunan · çubuk = ayrılan süre")).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
            }
            ForEach(c.pdfs) { pdf in
                Button { app.go(.reader(pdf.id)) } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().stroke(FolderPalette.track, lineWidth: 5)
                            Circle().trim(from: 0, to: CGFloat(pdf.read) / 100).stroke(ring, style: StrokeStyle(lineWidth: 5, lineCap: .butt)).rotationEffect(.degrees(-90))
                            Text(Format.num(pdf.read, lang)).font(KFont.mono(11, .semibold)).foregroundStyle(KPhone.text)
                        }
                        .frame(width: 46, height: 46)
                        .accessibilityLabel("%\(pdf.read) \(d("okundu"))")
                        VStack(alignment: .leading, spacing: 5) {
                            Text(pdf.title[lang]).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text).lineLimit(1)
                            HStack(spacing: 8) {
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(FolderPalette.track)
                                        Capsule().fill(FolderPalette.time).frame(width: g.size.width * CGFloat(pdf.minutes) / CGFloat(maxM))
                                    }
                                }
                                .frame(height: 5)
                                Text(minutesText(pdf.minutes, d)).font(KFont.mono(11, .regular)).foregroundStyle(KPhone.text2).frame(minWidth: 58, alignment: .trailing)
                            }
                            Text(pageLine(pdf)).font(KFont.ui(11, lang: lang)).foregroundStyle(KPhone.text3)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(KPhone.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(KPhone.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// "24 sayfa · 9 sayfa kaldı" / "bitti" / "başlanmadı".
    private func pageLine(_ p: Pdf) -> String {
        let rest = p.read >= 100 ? prefs.t("course.done") : p.read == 0 ? d("başlanmadı") : "\(Int((Double(p.pages) * Double(100 - p.read) / 100).rounded()))\(d(" sayfa kaldı"))"
        return "\(p.pages)\(d(" sayfa · "))\(rest)"
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Text(d("Bu klasör henüz boş")).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(KPhone.text)
            Text(d("İlk PDF'ini, slayt fotoğraflarını ya da ders ses kaydını ekle."))
                .font(KFont.ui(13, lang: lang)).foregroundStyle(KPhone.text2).multilineTextAlignment(.center)
        }
        .padding(.vertical, 28).padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(FolderPalette.line2, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
    }
}
