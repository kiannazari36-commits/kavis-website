import AVFoundation
import PhotosUI
import SwiftUI

/// Design: design/NewQuestions.dc.html ("Soru örneklerim"), with the web's /samples as the data model: choose the
/// course, add sample questions (photo, PDF or typed; optional), the server finds their style ("Soru tarzını çıkar":
/// question types, topics asked most, patterns), a switch decides whether exams follow it, and "Bu tarzda yeni
/// sorular üret" makes the course's exam pack in that style, played right away.
struct SamplesView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast
    @Environment(TrialModel.self) private var trial

    var courseId: String?

    private enum Busy { case add, analyze, make }

    @State private var courses: [Course] = CoursesAPI.lastCourses
    @State private var picked: String?
    @State private var samples: [SamplesAPI.Sample] = []
    @State private var style: SamplesAPI.Style?
    @State private var busy: Busy?
    @State private var writing = false
    @State private var text = ""
    @State private var askSource = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var libraryItems: [PhotosPickerItem] = []
    @State private var showPdf = false

    private var lang: Lang { prefs.lang }
    private func t(_ key: String) -> String { prefs.t(key) }
    private var current: String? { picked ?? courseId ?? courses.first?.id }

    private enum C {
        static let bg = Color.pair(0xF4EFE6, 0x15120F)
        static let card = Color.pair(0xFFFCF6, 0x211C18)
        static let sub = Color.pair(0xF1EBE0, 0x2B2520)
        static let line = Color.pair(0xE6DDCF, 0x3A322B)
        static let text2 = Color.pair(0x6E645A, 0xBDB2A4)
        static let text3 = Color.pair(0x776C60, 0x9A8F82)
        static let pri = Color(hex: 0x9C2F3A)
        static let priText = Color.pair(0x9C2F3A, 0xF09AA3)
        static let priSoft = Color.pair(0xF5E3E2, 0x3A2224)
        static let ambSoft = Color.pair(0xFBEBC8, 0x3A2E18)
        static let ambFg = Color.pair(0xA86F0E, 0xF2C66D)
        static let good = Color.pair(0x2E7D4F, 0x8FD3A8)
        static let goodSoft = Color.pair(0xE3F1E7, 0x1F3328)
        static let violet = Color.pair(0x4A3F9A, 0xB9B4F0)
        static let violetSoft = Color.pair(0xE8E6F6, 0x2C2A3A)
    }

    var body: some View {
        ZStack {
            C.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        (Text(t("smp_titleA") + " ") + Text(t("smp_titleB")).foregroundColor(C.text3).fontWeight(.regular))
                            .font(KFont.ui(30, .medium, lang: lang)).kTracking(-0.03, size: 30, lang: lang).foregroundStyle(KPhone.text)
                        Text(t("smp_lead")).font(KFont.ui(14, lang: lang)).kLineHeight(1.55, size: 14, lang: lang).foregroundStyle(C.text2)
                        coursePicker
                        methods
                        if writing { writeBox }
                        sampleList
                        primary(busy == .analyze ? t("smp_analyzing") : t(style == nil ? "smp_analyze" : "smp_reanalyze"), dim: samples.isEmpty, action: analyze)
                        styleCard
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 36)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .padColumn()
        }
        .task {
            if courses.isEmpty { courses = await CoursesAPI.listCourses() }
            await load()
        }
        .onChange(of: current) { _, _ in Task { await load() } }
        .confirmationDialog(t("smp_photo"), isPresented: $askSource, titleVisibility: .visible) {
            Button(prefs.d("Fotoğraf çek")) { openCamera() }
            Button(prefs.d("Galeriden seç")) { showLibrary = true }
        }
        .photosPicker(isPresented: $showLibrary, selection: $libraryItems, maxSelectionCount: 10, matching: .images)
        .onChange(of: libraryItems) { _, items in
            guard !items.isEmpty else { return }
            libraryItems = []
            Task {
                var images: [UIImage] = []
                for item in items { if let d = try? await item.loadTransferable(type: Data.self), let i = UIImage(data: d) { images.append(i) } }
                await addPhotos(images)
            }
        }
        .fullScreenCover(isPresented: $showCamera) { CameraPicker { image in Task { await addPhotos([image]) } }.ignoresSafeArea() }
        .fileImporter(isPresented: $showPdf, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            Task { await addPdfs(urls) }
        }
    }

    private func load() async {
        guard let id = current else { return }
        async let s = SamplesAPI.list(courseId: id)
        async let st = SamplesAPI.style(courseId: id)
        samples = await s
        style = await st
    }

    // MARK: Parts

    private var header: some View {
        HStack(spacing: 12) {
            Button { app.back() } label: {
                KIcon(name: .back, size: 20, width: 1.8, flipsInRTL: true).foregroundStyle(KPhone.text)
                    .frame(width: 46, height: 46).background(C.card, in: Circle()).overlay(Circle().stroke(C.line, lineWidth: 1))
            }
            .accessibilityLabel(t("back"))
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, KLayout.top(60, minimum: 6)).padding(.bottom, 6)
    }

    private var coursePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("smp_which")).font(KFont.ui(13, lang: lang)).foregroundStyle(C.text2)
            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(courses) { c in
                    let on = c.id == current
                    Button { picked = c.id } label: {
                        Text((c.short ?? c.name)[lang]).font(KFont.ui(14, lang: lang))
                            .foregroundStyle(on ? Color(hex: 0xFFFCF6) : KPhone.text)
                            .padding(.horizontal, 16).frame(height: 40)
                            .background(on ? C.pri : C.card, in: Capsule())
                            .overlay(Capsule().stroke(on ? .clear : C.line, lineWidth: 1))
                    }
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private var methods: some View {
        let items: [(KIconName, String, Color, Color, () -> Void)] = [
            (.camera, "smp_photo", C.priSoft, C.priText, { askSource = true }),
            (.file, "smp_pdf", C.ambSoft, C.ambFg, { showPdf = true }),
            (.pen, "smp_text", C.violetSoft, C.violet, { writing.toggle() }),
        ]
        return HStack(spacing: 10) {
            ForEach(items, id: \.1) { icon, key, chip, fg, action in
                Button(action: action) {
                    VStack(spacing: 8) {
                        KIcon(name: icon, size: 21, width: 1.8).foregroundStyle(fg).frame(width: 46, height: 46).background(chip, in: Circle())
                        Text(t(key)).font(KFont.ui(13, .medium, lang: lang)).foregroundStyle(KPhone.text)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(C.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(C.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(current == nil || busy == .add)
            }
        }
    }

    private var writeBox: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(t("smp_textHint")).font(KFont.ui(14, lang: lang)).foregroundStyle(C.text3).padding(.horizontal, 19).padding(.vertical, 22).allowsHitTesting(false)
                }
                TextEditor(text: $text).font(KFont.ui(14, lang: lang)).foregroundStyle(KPhone.text).scrollContentBackground(.hidden).padding(10)
            }
            .frame(height: 170)
            .background(C.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(C.line, lineWidth: 1))
            primary(t("smp_save"), dim: false) { Task { await addText() } }
        }
    }

    private var sampleList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("smp_list")).font(KFont.ui(13, lang: lang)).foregroundStyle(C.text2)
            if samples.isEmpty {
                Text(t("smp_empty")).font(KFont.ui(13, lang: lang)).foregroundStyle(C.text3)
            }
            ForEach(samples) { x in
                HStack(spacing: 12) {
                    Text(x.kind == "photo" ? t("smp_kPhoto") : x.kind == "pdf" ? "PDF" : t("smp_kText"))
                        .font(KFont.mono(10, .semibold)).foregroundStyle(C.priText)
                        .frame(width: 42, height: 42).background(C.priSoft, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(x.title.isEmpty ? t("smp_typed") : x.title).font(KFont.ui(14, .medium, lang: lang)).foregroundStyle(KPhone.text).lineLimit(1)
                        Text(x.questions.map { t("smp_count").replacingOccurrences(of: "{n}", with: Format.num($0, lang)) } ?? t("smp_notRead"))
                            .font(KFont.ui(12, lang: lang)).foregroundStyle(C.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        Task {
                            await SamplesAPI.delete(x.id)
                            await load()
                        }
                    } label: {
                        KIcon(name: .trash, size: 16, width: 1.8).foregroundStyle(C.text2).frame(width: 36, height: 36)
                    }
                    .accessibilityLabel(t("lessonDelete"))
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(C.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(C.line, lineWidth: 1))
            }
        }
    }

    private var styleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("smp_style")).font(KFont.ui(17, .semibold, lang: lang)).foregroundStyle(KPhone.text)
            if let style {
                Text(t("smp_from").replacingOccurrences(of: "{n}", with: Format.num(style.questions, lang))).font(KFont.ui(13, lang: lang)).foregroundStyle(C.text2)
                ForEach(SamplesAPI.Style.types.filter { (style.types[$0] ?? 0) > 0 }.sorted { (style.types[$0] ?? 0) > (style.types[$1] ?? 0) }, id: \.self) { k in
                    let v = style.types[k] ?? 0
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(t("style_\(k)")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                            Spacer()
                            Text(Format.percent(v, lang)).font(KFont.mono(12, .regular)).foregroundStyle(C.text2)
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(C.sub)
                                Capsule().fill(C.pri).frame(width: g.size.width * CGFloat(min(v, 100)) / 100)
                            }
                        }
                        .frame(height: 8)
                    }
                }
                if !style.topTopics.isEmpty {
                    Text(t("smp_topics")).font(KFont.ui(13, lang: lang)).foregroundStyle(C.text2)
                    FlowLayout(spacing: 6, rowSpacing: 6) {
                        ForEach(style.topTopics, id: \.title) { x in
                            Text("\(x.title) · \(Format.num(x.count, lang))").font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text)
                                .padding(.horizontal, 10).frame(height: 28).background(C.sub, in: Capsule())
                        }
                    }
                }
                ForEach(style.patterns, id: \.self) { p in
                    Text("• \(p)").font(KFont.ui(13, lang: lang)).kLineHeight(1.45, size: 13, lang: lang).foregroundStyle(KPhone.text)
                }
                Toggle(isOn: Binding(get: { style.useInQuizzes }, set: { on in
                    self.style?.useInQuizzes = on
                    if let id = current { Task { await SamplesAPI.setUseInQuizzes(courseId: id, on) } }
                })) {
                    Text(t("smp_use")).font(KFont.ui(14, lang: lang)).foregroundStyle(KPhone.text)
                }
                .tint(C.pri)
            } else {
                Text(t("smp_noStyle")).font(KFont.ui(13, lang: lang)).kLineHeight(1.5, size: 13, lang: lang).foregroundStyle(C.text2)
            }
            Button(action: make) {
                HStack(spacing: 8) {
                    KIcon(name: .spark, size: 16, width: 1.8)
                    Text(busy == .make ? t("smp_making") : t("smp_makeBtn")).font(KFont.ui(15, .medium, lang: lang))
                }
                .foregroundStyle(KPhone.text)
                .frame(maxWidth: .infinity, minHeight: 50)
                .overlay(Capsule().stroke(C.line, lineWidth: 1))
            }
            .disabled(current == nil || busy == .make)
            Text(t("smp_makeNote")).font(KFont.ui(12, lang: lang)).kLineHeight(1.45, size: 12, lang: lang).foregroundStyle(C.text3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(C.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(C.line, lineWidth: 1))
    }

    private func primary(_ title: String, dim: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(KFont.ui(16, .medium, lang: lang)).foregroundStyle(Color(hex: 0xFFFCF6))
                .frame(maxWidth: .infinity, minHeight: 54).background(C.pri.opacity(dim ? 0.45 : 1), in: Capsule())
        }
    }

    // MARK: Actions

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { showLibrary = true; return }
        Task {
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined { _ = await AVCaptureDevice.requestAccess(for: .video) }
            if AVCaptureDevice.authorizationStatus(for: .video) == .authorized { showCamera = true } else { showLibrary = true }
        }
    }

    private func dayTitle(_ base: String) -> String {
        let f = DateFormatter()
        f.locale = lang.locale
        f.setLocalizedDateFormatFromTemplate("dMMM HHmm")
        return "\(base) · \(f.string(from: Date()))"
    }

    private func addPhotos(_ images: [UIImage]) async {
        guard let id = current, !images.isEmpty else { return }
        busy = .add
        var ok = true
        for image in images {
            guard let jpeg = UploadAPI.shrinkPhoto(image) else { ok = false; continue }
            ok = await SamplesAPI.addFile(jpeg, pdf: false, title: dayTitle(t("smp_photo")), courseId: id) && ok
        }
        busy = nil
        toast.show(t(ok ? "smp_added" : "smp_failed"))
        await load()
    }

    private func addPdfs(_ urls: [URL]) async {
        guard let id = current else { return }
        busy = .add
        var ok = true
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            let data = try? Data(contentsOf: url)
            if access { url.stopAccessingSecurityScopedResource() }
            guard let data, data.count <= 15 * 1_048_576 else { toast.show(t("smp_badFile")); ok = false; continue }
            ok = await SamplesAPI.addFile(data, pdf: true, title: url.lastPathComponent, courseId: id) && ok
        }
        busy = nil
        if ok { toast.show(t("smp_added")) }
        await load()
    }

    private func addText() async {
        guard let id = current else { return }
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20 else { return toast.show(t("smp_tooShort")) }
        busy = .add
        let ok = await SamplesAPI.addText(text, title: t("smp_typed"), courseId: id)
        busy = nil
        if ok { text = ""; writing = false }
        toast.show(t(ok ? "smp_added" : "smp_failed"))
        await load()
    }

    private func failText(_ f: SamplesAPI.Failure) -> String {
        t(f == .locked ? "trialQFull" : f == .budget ? "askBudget" : "smp_failed")
    }

    /// "Soru tarzını çıkar" (AI): needs samples, and the trial or Premium.
    private func analyze() {
        guard let id = current, busy == nil else { return }
        guard !samples.isEmpty else { return toast.show(t("smp_needSample")) }
        trial.perform(.generate) {
            busy = .analyze
            Task {
                let r = await SamplesAPI.analyze(courseId: id)
                busy = nil
                switch r {
                case .success(let s): style = s
                case .failure(let f): toast.show(failText(f))
                }
                await load()
            }
        }
    }

    /// "Bu tarzda yeni sorular üret" (AI): the new exam pack is played right away.
    private func make() {
        guard let id = current, busy == nil else { return }
        trial.perform(.generate) {
            busy = .make
            Task {
                let r = await SamplesAPI.makeExamPack(courseId: id)
                busy = nil
                switch r {
                case .success(let made):
                    toast.show(t("smp_made").replacingOccurrences(of: "{n}", with: Format.num(made.questions, lang)))
                    app.go(.quiz(QuizTarget(materialId: "", kind: .exam, quizId: made.quizId)))
                case .failure(let f): toast.show(failText(f))
                }
            }
        }
    }
}
