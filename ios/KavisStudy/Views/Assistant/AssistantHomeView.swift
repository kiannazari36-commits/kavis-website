import AVFoundation
import PhotosUI
import SwiftUI

/// Design: design/NewAssistant.dc.html. Start of the assistant: choose the course, the source ("only my PDFs" or
/// "AI + research"), add a file, or pick a quick action, then ask. The first question opens the chat.
struct AssistantHomeView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast
    @Environment(TrialModel.self) private var trial
    @Environment(\.colorScheme) private var scheme

    private enum Panel { case none, menu, add, quick }

    @State private var topics: [AssistantTopic] = []
    @State private var topicId: String?
    @State private var ai = false
    @State private var panel: Panel = .none
    @State private var draft = ""
    @FocusState private var focused: Bool
    /// What a chosen photo is for: "Soruyu çözdür" or a lecturer's question for "Soru örneklerim".
    private enum PhotoUse { case solve, sample }
    @State private var photoUse: PhotoUse?
    @State private var askSource = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var historyOpen = MockFlag.value("assistantPanel") == "history"
    @State private var history: [ChatThread]?

    private var lang: Lang { prefs.lang }
    private func d(_ turkish: String) -> String { prefs.d(turkish) }
    private func soon() { toast.show(prefs.t("k165")) }
    private var topic: AssistantTopic? { topics.first { $0.id == topicId } }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            hero
            VStack(spacing: 10) {
                switch panel {
                case .menu: menuPanel
                case .add: addPanel
                case .quick: quickPanel
                case .none: EmptyView()
                }
                composer
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background.ignoresSafeArea())
        .animation(.easeOut(duration: 0.2), value: panel)
        .task {
            topics = await AssistantAPI.listTopics()
            if MockFlag.value("assistantPanel") == "menu" { panel = .menu }
        }
        .confirmationDialog(d(photoUse == .sample ? "Soru fotoğrafı" : "Soruyu çözdür"), isPresented: $askSource, titleVisibility: .visible) {
            Button(d("Fotoğraf çek")) { openCamera() }
            Button(d("Galeriden seç")) { showLibrary = true }
        }
        .photosPicker(isPresented: $showLibrary, selection: $libraryItem, matching: .images)
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            libraryItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { usePhoto(image) } else { toast.show(prefs.t("solveBadFile")) }
            }
        }
        .fullScreenCover(isPresented: $showCamera) { CameraPicker { usePhoto($0) }.ignoresSafeArea() }
        .sheet(isPresented: $historyOpen) { historySheet.presentationDetents([.medium, .large]) }
    }

    // MARK: Photos ("Soruyu çözdür", "Soru fotoğrafı")

    /// "Soruyu çözdür" needs a chosen course (or all courses); a question sample needs one real course.
    private func pickPhoto(_ use: PhotoUse) {
        guard let topic, use == .solve || topic.courseId != nil else {
            panel = .menu
            return toast.show(d("Önce sorunun hangi dersle ilgili olduğunu seç"))
        }
        let open = { photoUse = use; askSource = true }
        if use == .solve { trial.perform(.question, run: open) } else { open() }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { showLibrary = true; return }
        Task {
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined { _ = await AVCaptureDevice.requestAccess(for: .video) }
            if AVCaptureDevice.authorizationStatus(for: .video) == .authorized { showCamera = true } else { showLibrary = true }
        }
    }

    private func usePhoto(_ image: UIImage) {
        guard let topic, let jpeg = AssistantAPI.photoForAssistant(image) else { return toast.show(prefs.t("solveBadFile")) }
        switch photoUse {
        case .solve:
            let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            draft = ""
            app.go(.assistantChat(AssistantChatTarget(topicId: topic.id, question: question, ai: ai, photo: jpeg)))
        case .sample:
            guard let course = topic.courseId else { return }
            Task {
                let f = DateFormatter()
                f.locale = lang.locale
                f.setLocalizedDateFormatFromTemplate("dMMM HHmm")
                let ok = await AssistantAPI.addQuestionSample(jpeg, courseId: course, title: "\(d("Soru fotoğrafı")) · \(f.string(from: Date()))")
                toast.show(prefs.t(ok ? "smp_added" : "smp_failed"))
            }
        case nil: break
        }
        photoUse = nil
    }

    // MARK: "Geçmiş"

    private var historySheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(d("Geçmiş")).font(KFont.ui(20, .bold, lang: lang)).foregroundStyle(KPhone.text).accessibilityAddTraits(.isHeader)
            if let history {
                if history.isEmpty {
                    Text(prefs.t("noThread")).font(KFont.ui(14, lang: lang)).foregroundStyle(KPhone.text2)
                }
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(history) { th in
                            let course = topics.first { $0.courseId != nil && $0.courseId == th.courseId } ?? topics.first { $0.isAll }
                            Button {
                                historyOpen = false
                                app.go(.assistantChat(AssistantChatTarget(topicId: course?.id ?? "all", ai: ai, threadId: th.id)))
                            } label: {
                                HStack(spacing: 12) {
                                    KIcon(name: .chat, size: 18, width: 1.7).foregroundStyle(KPhone.text)
                                        .frame(width: 36, height: 36).background(KPhone.seg, in: Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(th.title.isEmpty ? prefs.t("solveLabel") : th.title).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text).lineLimit(2)
                                        Text([course?.name[lang] ?? "", th.updatedAt.map(dayText) ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2).lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    KIcon(name: .chevron, size: 16, width: 1.8, flipsInRTL: true).foregroundStyle(KPhone.text3)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(KPhone.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(KPhone.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                SwiftUI.ProgressView().frame(maxWidth: .infinity)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pair(0xF4EFE6, 0x15120F).ignoresSafeArea())
        .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
        .task { history = await AssistantAPI.threads() }
    }

    private func dayText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = lang.locale
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return Format.num(f.string(from: date), lang)
    }

    private var background: some View {
        RadialGradient(colors: [Color.pair(0xF7E2C2, 0x3A2A1E), Color.pair(0xF4EFE6, 0x15120F)],
                       center: UnitPoint(x: 0.5, y: 0.38), startRadius: 0, endRadius: 520)
            .background(Color.pair(0xF4EFE6, 0x15120F))
    }

    // MARK: Top bar and hero

    private var topBar: some View {
        HStack {
            roundButton(.back, label: prefs.t("signup.k1052"), flips: true) { app.back() }
            Spacer()
            HStack(spacing: 8) {
                KIcon(name: .sparkle, size: 17, width: 1.7).foregroundStyle(KPhone.text)
                Wordmark(size: 14)
            }
            .padding(.horizontal, 16).frame(height: 44)
            .background(KPhone.card, in: Capsule())
            .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
            Spacer()
            roundButton(.menuLines, label: d("Geçmiş"), flips: false) { history = nil; historyOpen = true }
        }
        .padding(.horizontal, 20).padding(.top, KLayout.top(54, minimum: 6) + 6)
    }

    private func roundButton(_ icon: KIconName, label: String, flips: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            KIcon(name: icon, size: 20, width: 1.8, flipsInRTL: flips)
                .foregroundStyle(KPhone.text)
                .frame(width: 46, height: 46)
                .background(KPhone.card, in: Circle())
                .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }

    private var compact: Bool { panel != .none }

    private var hero: some View {
        VStack(spacing: 26) {
            Image("StarGlow")
                .resizable().scaledToFit()
                .frame(width: compact ? 150 : 300, height: compact ? 128 : 256)
                .padding(.top, -20).padding(.bottom, -30)
                .accessibilityHidden(true)
            if !compact {
                VStack(spacing: 10) {
                    (Text("\(d("Bugün sana nasıl"))\n").font(KFont.ui(32, .regular, lang: lang)).foregroundStyle(KPhone.text3)
                        + Text(d("yardım edeyim?")).font(KFont.ui(32, .medium, lang: lang)).foregroundStyle(KPhone.text))
                        .kTracking(-0.03, size: 32, lang: lang)
                        .kLineHeight(1.15, size: 32, lang: lang)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(ai ? d("PDF'lerin + yapay zekâ ve araştırma · PDF dışı bilgi ayrıca işaretlenir") : d("Yalnızca senin PDF'lerin, fotoğrafların ve ses kayıtlarınla"))
                        .font(KFont.ui(13, lang: lang)).foregroundStyle(KPhone.text2)
                        .multilineTextAlignment(.center).padding(.horizontal, 10)
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity)
    }

    // MARK: Composer

    private var placeholder: String {
        guard let topic else { return d("Önce dersi seç, sonra sor…") }
        return topic.isAll ? d("Tüm derslerin hakkında sor…") : topic.name[lang] + d(" hakkında sor…")
    }

    private var composer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                KIcon(name: .pen, size: 17, width: 1.6).foregroundStyle(KPhone.text3)
                TextField("", text: $draft, prompt: Text(placeholder).foregroundStyle(KPhone.text3), axis: .vertical)
                    .font(KFont.ui(15, lang: lang)).foregroundStyle(KPhone.text)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .lineLimit(1...3)
            }
            HStack(spacing: 8) {
                tool(.plus, label: d("PDF ekle"), on: panel == .add) { toggle(.add) }
                tool(.sliders, label: d("Ders, kaynak ve hızlı işlemler"), on: panel == .menu, needsDot: topic == nil && panel != .menu) { toggle(.menu) }
                if topic != nil { quickChip }
                Spacer(minLength: 0)
                tool(.mic, label: prefs.t("talk"), on: false) { soon() }
                Button(action: send) {
                    KIcon(name: .paperPlane, size: 18, width: 1.8, flipsInRTL: true)
                        .foregroundStyle(KPhone.ctaText)
                        .frame(width: 44, height: 44)
                        .background(KPhone.cta, in: Circle())
                }
                .accessibilityLabel(prefs.t("send"))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(KPhone.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.pair(0xF2D9A8, 0x4A3A1C), lineWidth: 1))
    }

    private func tool(_ icon: KIconName, label: String, on: Bool, needsDot: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            KIcon(name: icon, size: 19, width: 1.7)
                .foregroundStyle(KPhone.text)
                .frame(width: 40, height: 40)
                .background(on ? KPhone.seg : .clear, in: Circle())
                .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
                .overlay(alignment: .topTrailing) {
                    if needsDot { Circle().fill(KColor.amb).frame(width: 9, height: 9).offset(x: 1, y: -1) }
                }
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Once a course is chosen, the quick actions are one tap away.
    private var quickChip: some View {
        Button { toggle(.quick) } label: {
            HStack(spacing: 6) {
                Circle().fill(Color(hex: UInt32(topic?.color.dropFirst() ?? "9C2F3A", radix: 16) ?? 0x9C2F3A)).frame(width: 9, height: 9)
                Text(topic?.name[lang] ?? "").font(KFont.ui(12, .medium, lang: lang)).lineLimit(1)
            }
            .foregroundStyle(KPhone.text)
            .padding(.horizontal, 12).frame(height: 40)
            .background(KOnb.priSoft, in: Capsule())
            .overlay(Capsule().stroke(KPhone.focus, lineWidth: 1))
        }
        .accessibilityLabel(d("Ders: ") + (topic?.name[lang] ?? ""))
    }

    private func toggle(_ next: Panel) { panel = panel == next ? .none : next }

    private func send() { ask(draft.trimmingCharacters(in: .whitespacesAndNewlines)) }

    /// Opens the chat with the question (a quick action sends its own words as the question).
    private func ask(_ question: String) {
        guard let topic else {
            panel = .menu
            toast.show(d("Önce sorunun hangi dersle ilgili olduğunu seç"))
            return
        }
        trial.perform(.question) {
            draft = ""
            app.go(.assistantChat(AssistantChatTarget(topicId: topic.id, question: question, ai: ai)))
        }
    }

    // MARK: Panels

    private func dot(_ topic: AssistantTopic) -> Color { Color(hex: UInt32(topic.color.dropFirst(), radix: 16) ?? 0x9C2F3A) }

    private func courseCards(assign: Bool = false) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(topics.filter { !(assign && $0.isAll) }) { t in
                    let on = topicId == t.id
                    Button {
                        topicId = t.id; toast.show(d("Ders: ") + t.name[lang]); panel = .none
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Circle().fill(dot(t)).frame(width: 9, height: 9)
                            Text(t.name[lang]).font(KFont.ui(13, .semibold, lang: lang)).kLineHeight(1.25, size: 13, lang: lang)
                            Text(t.sub[lang]).font(KFont.ui(11, lang: lang)).foregroundStyle(KPhone.text2)
                        }
                        .foregroundStyle(KPhone.text)
                        .multilineTextAlignment(.leading)
                        .padding(10)
                        .frame(width: 132, height: 80, alignment: .topLeading)
                        .background(on ? KOnb.priSoft : KPhone.homeBgSolid, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(on ? KPhone.focus : KPhone.line, lineWidth: on ? 2 : 1))
                    }
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var menuPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(prefs.t("courseLabel")).font(KFont.ui(11, .semibold, lang: lang)).tracking(lang.isRTL ? 0 : 0.55).foregroundStyle(KPhone.text2).padding(.horizontal, 16)
            if topic == nil { courseCards() } else {
                HStack(spacing: 10) {
                    Circle().fill(topic.map(dot) ?? .gray).frame(width: 9, height: 9)
                    Text(topic?.name[lang] ?? "").font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text).lineLimit(1)
                    Spacer()
                    Button { topicId = nil } label: {
                        Text(prefs.t("change")).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text)
                            .padding(.horizontal, 12).frame(height: 30)
                            .background(KPhone.card, in: Capsule()).overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
                    }
                }
                .padding(.leading, 12).padding(.trailing, 8).padding(.vertical, 8)
                .background(KOnb.priSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
            }
            Rectangle().fill(KPhone.line).frame(height: 1).padding(.horizontal, 16)
            Text(d("KAYNAK")).font(KFont.ui(11, .semibold, lang: lang)).tracking(lang.isRTL ? 0 : 0.55).foregroundStyle(KPhone.text2).padding(.horizontal, 16)
            HStack(spacing: 4) {
                sourceMode(d("Sadece PDF'lerim"), icon: .file, on: !ai) {
                    ai = false; toast.show(d("Sadece PDF'lerin · cevaplar yalnızca senin materyalinden"))
                }
                sourceMode(d("Yapay zekâ + araştırma"), icon: .globe, on: ai) {
                    ai = true; toast.show(d("Yapay zekâ + araştırma açık · PDF'inde olmayanı da anlatırım, kaynağını gösteririm"))
                }
            }
            .padding(3)
            .background(KPhone.seg, in: Capsule())
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KPhone.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(KPhone.line, lineWidth: 1))
        .shadow(color: Color(hex: 0x2A2420, opacity: 0.12), radius: 17, y: 14)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(d("Ders, kaynak ve hızlı işlemler"))
    }

    private func sourceMode(_ title: String, icon: KIconName, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                KIcon(name: icon, size: 13, width: 1.7)
                Text(title).font(KFont.ui(11, on ? .semibold : .regular, lang: lang)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? KPhone.text : KPhone.text2)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(on ? KPhone.card : .clear, in: Capsule())
        }
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var quickPanel: some View {
        let items: [(KIconName, String, () -> Void)] = [
            // These ask the assistant in the student's own words (the server answers from their lessons).
            (.headphones, "Önemli ve zayıf konularımı anlat", { panel = .none; ask(d("Önemli ve zayıf konularımı anlat")) }),
            (.lines, "Bu konuyu özetle", { panel = .none; ask(d("Bu konuyu özetle")) }),
            (.checklist, "Bana 5 soru sor", { panel = .none; ask(d("Bana 5 soru sor")) }),
            (.target, "Zayıf konularım", { panel = .none; ask(d("Zayıf konularım")) }),
            (.mic, "Ben anlatayım", { panel = .none; soon() }),
        ]
        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                Button(action: item.2) {
                    HStack(spacing: 12) {
                        KIcon(name: item.0, size: 18, width: 1.7)
                            .foregroundStyle(i == 0 ? KPhone.tile2Text : KPhone.text)
                            .frame(width: 36, height: 36)
                            .background(i == 0 ? KPhone.card : KPhone.seg, in: Circle())
                        Text(d(item.1)).font(KFont.ui(14, lang: lang)).foregroundStyle(i == 0 ? KPhone.tile2Text : KPhone.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 52)
                    .background(i == 0 ? KPhone.tile2 : .clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(KPhone.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(KPhone.line, lineWidth: 1))
        .shadow(color: Color(hex: 0x2A2420, opacity: 0.1), radius: 13, y: 10)
    }

    private var addPanel: some View {
        let items: [(AttachmentKind?, KIconName, String, String)] = [
            (.pdf, .upload, "PDF ekle", "Ders notu ya da slayt"),
            (.photo, .camera, "Soru fotoğrafı", "Hocanın soruları, sınav kâğıdı"),
            (.audio, .mic, "Ses kaydı", "Dersin kaydı"),
            (nil, .solve, "Soruyu çözdür", "Fotoğrafını çek, adım adım çözelim"),
        ]
        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button {
                    panel = .none
                    switch item.0 {
                    case .pdf:
                        // A PDF goes through the upload screen into the chosen course.
                        trial.perform(.pdf) {
                            app.uploadCourseId = topic?.courseId
                            app.go(.upload(.pdf))
                        }
                    case .photo: pickPhoto(.sample)
                    case .audio: app.go(.upload(.audio))
                    case nil: pickPhoto(.solve)
                    }
                } label: {
                    HStack(spacing: 12) {
                        KIcon(name: item.1, size: 18, width: 1.7)
                            .foregroundStyle(KPhone.text)
                            .frame(width: 36, height: 36).background(KPhone.seg, in: Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(d(item.2)).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                            Text(d(item.3)).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 56)
                }
                .buttonStyle(.plain)
            }
        }
        .background(KPhone.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(KPhone.line, lineWidth: 1))
        .shadow(color: Color(hex: 0x2A2420, opacity: 0.1), radius: 13, y: 10)
    }

}

extension KPhone {
    /// Page color as a solid (for chips on top of a gradient).
    static let homeBgSolid = Color.pair(0xF4EFE6, 0x15120F)
}
