import SwiftUI
import UniformTypeIdentifiers

/// Design: design/ScrUpload.dc.html. Choose a PDF (or photos / a lecture recording), see the lesson being prepared,
/// or an error when the PDF has no text. A PDF over 100 pages opens the "too long" sheet (CLAUDE.md: max 100 pages).
/// Preparing the lesson is a mock until the server exists; picking the file and reading its pages is real.
struct UploadView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast
    @Environment(TrialModel.self) private var trial

    enum Mode { case pick, photo, audio, processing, error }

    let kind: UploadKind
    @State private var mode: Mode
    @State private var showPDFImporter = false
    @State private var showAudioImporter = false
    @State private var picked: PickedPDF?
    @State private var lessonName = "Hipertansiyon"
    @State private var courseName = "Farmakoterapi"
    @State private var shots = 4
    @State private var audioName: String?
    @State private var doneSteps = 0
    @State private var runID = 0
    @State private var longSheet = false
    @State private var splitMode = true
    @State private var rangeFrom = "1"
    @State private var rangeTo = "100"

    init(kind: UploadKind) {
        self.kind = kind
        // Test switch: `-kavis.uploadMode pick | photo | audio | processing | error` shows a state of this screen.
        switch MockFlag.value("uploadMode") {
        case "processing": _mode = State(initialValue: .processing)
        case "error": _mode = State(initialValue: .error)
        case "photo": _mode = State(initialValue: .photo)
        case "audio": _mode = State(initialValue: .audio)
        default: _mode = State(initialValue: kind == .photo ? .photo : kind == .audio ? .audio : .pick)
        }
        if MockFlag.value("uploadMode") == "processing" { _doneSteps = State(initialValue: 2) }
        if MockFlag.value("uploadMode") == "long" { _longSheet = State(initialValue: true) }
    }

    private var lang: Lang { prefs.lang }
    private func d(_ turkish: String) -> String { prefs.d(turkish) }
    private func mono(_ size: CGFloat) -> Font { KFont.mono(size, .regular) }
    private func soon() { toast.show(prefs.t("k165")) }

    private let barPad: CGFloat = 8

    var body: some View {
        ZStack {
            KPhone.authBg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                switch mode {
                case .pick: pickContent
                case .photo: photoContent
                case .audio: audioContent
                case .processing: processingContent
                case .error: errorContent
                }
            }
            if longSheet { longPdfSheet }
        }
        .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result { handlePicked(url) }
        }
        .fileImporter(isPresented: $showAudioImporter, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result { audioName = url.lastPathComponent }
        }
        .animation(.easeOut(duration: 0.2), value: longSheet)
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    // MARK: Header and footer

    private var header: some View {
        ZStack {
            Text(d("PDF yükle")).font(KFont.ui(17, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button { app.back() } label: {
                    KIcon(name: .close, size: 24, width: 1.8)
                        .foregroundStyle(KPhone.text)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(d("Kapat"))
                Spacer()
            }
            .padding(.horizontal, barPad)
        }
        .frame(height: 52)
        .padding(.top, KLayout.top(54, minimum: 6))
    }

    /// Bottom bar with the main button (and the free-trial counter).
    private func footer(_ title: String, enabled: Bool = true, showQuota: Bool = false, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Button(action: action) {
                Text(title)
                    .font(KFont.ui(16, .semibold, lang: lang))
                    .foregroundStyle(KPhone.ctaText)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(KOnb.pri, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .opacity(enabled ? 1 : 0.5)
            }
            .disabled(!enabled)
            if showQuota && !trial.status.premium { quota }
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(KPhone.authBg)
        .overlay(alignment: .top) { Rectangle().fill(KPhone.line).frame(height: 1) }
    }

    /// Remaining trial limits instead of the old "1/2 free lessons this month" (CLAUDE.md: 3-day trial, 2 PDFs).
    private var quota: some View {
        let s = trial.status
        let text = s.ended
            ? prefs.t("trialEnded")
            : "\(Format.num(s.pdfsUsed, lang))/\(Format.num(TrialLimits.pdfs, lang)) PDF · \(prefs.t("trialDaysLeft", ["n": Format.num(s.daysLeft, lang)]))"
        return Text(text.uppercased()).font(mono(11)).foregroundStyle(KOnb.text3)
    }

    private func fileBadge(_ color: Color, _ bg: Color, border: Bool = false, size: CGSize = CGSize(width: 34, height: 40)) -> some View {
        Text("PDF").font(KFont.mono(9, .semibold)).foregroundStyle(color)
            .frame(width: size.width, height: size.height)
            .background(bg, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(border ? KPhone.line : .clear, lineWidth: 1))
    }

    private func infoBox(_ icon: KIconName, _ text: String, size: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 10) {
            KIcon(name: icon, size: 20, width: 1.6)
            Text(text).font(KFont.ui(size, lang: lang)).kLineHeight(size == 13 ? 1.45 : 1.5, size: size, lang: lang)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(KPhone.text2)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(KPhone.sub, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func optionRow(_ icon: KIconName, chip: Color, fg: Color, _ title: String, _ sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                KIcon(name: icon, size: 21, width: 1.7)
                    .foregroundStyle(fg)
                    .frame(width: 40, height: 40)
                    .background(chip, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .rotationEffect(.degrees(-7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(KFont.ui(15, .bold, lang: lang)).foregroundStyle(KPhone.text)
                    Text(sub).font(KFont.ui(12, lang: lang)).foregroundStyle(KOnb.text3).multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                KIcon(name: .arrowRight, size: 16, width: 2, flipsInRTL: true).foregroundStyle(KPhone.text2)
            }
            .padding(14)
            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Pick (PDF)

    private var pickContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    dropZone
                    optionRow(.camera, chip: KOnb.ambSoft, fg: KOnb.ambText, d("PDF yok mu? Fotoğraf çek"), d("Slayt, ders notu ya da el yazısı sayfaların fotoğrafı")) { mode = .photo }
                    optionRow(.mic, chip: KOnb.priSoft, fg: KOnb.priText, d("Derse ses kaydı ekle"), d("Hocanın anlattıklarını metne çevirir, vurgularını bulur")) { mode = .audio }
                    optionRow(.help, chip: KPhone.sub, fg: KPhone.text, d("Elinde soru var mı?"), d("Eski sınav ya da örnek sorular: o tarzda soru hazırlarız")) { soon() }
                    recentFiles
                    fields
                    infoBox(.shield, d("Hocanın metni hiç değiştirilmez. Asistan istersen sadece bu PDF'le, istersen yapay zekâ araştırmasıyla da cevap verir."), size: 13)
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            footer(d("Dersi hazırla"), showQuota: true) { prepare() }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            KIcon(name: .upload, size: 28, width: 1.6)
                .foregroundStyle(KOnb.priText)
                .frame(width: 54, height: 54)
                .background(KOnb.priSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .rotationEffect(.degrees(-7))
            Text(d("Ders PDF'ini seç")).font(KFont.ui(18, .bold, lang: lang)).foregroundStyle(KPhone.text)
            Text(d("Dosyalar · iCloud Drive · Google Drive")).font(KFont.ui(13, lang: lang)).foregroundStyle(KOnb.text3)
            Button { showPDFImporter = true } label: {
                Text(d("Dosya seç"))
                    .font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                    .padding(.horizontal, 22).frame(height: 44)
                    .background(KPhone.sub, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(KPhone.line, lineWidth: 1))
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 20).padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(KPhone.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(KOnb.text3, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
    }

    private var recentFiles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(d("SON DOSYALAR")).font(mono(11)).tracking(lang.isRTL ? 0 : 1.1).foregroundStyle(KOnb.text3)
            VStack(spacing: 0) {
                if let picked {
                    recentRow(name: picked.name, meta: Format.fileMeta(pages: picked.pages, megabytes: picked.megabytes, lang), selected: true)
                }
                recentRow(name: "Farmakoterapi_Hipertansiyon.pdf", meta: d("48 sayfa · 6,2 MB"), selected: picked == nil) { select(mock: "Farmakoterapi_Hipertansiyon.pdf", pages: 48, mb: 6.2) }
                    .overlay(alignment: .bottom) { Rectangle().fill(KPhone.line).frame(height: 1) }
                recentRow(name: "Diyabet_Ders_Notu.pdf", meta: d("36 sayfa · 4,1 MB"), selected: false) { select(mock: "Diyabet_Ders_Notu.pdf", pages: 36, mb: 4.1) }
            }
            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func recentRow(name: String, meta: String, selected: Bool, action: (() -> Void)? = nil) -> some View {
        Button { action?() } label: {
            HStack(spacing: 12) {
                fileBadge(selected ? KOnb.priText : KOnb.text3, selected ? KPhone.card : KPhone.sub, border: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(KFont.ui(14, .semibold, lang: lang)).lineLimit(1).truncationMode(.middle).foregroundStyle(KPhone.text)
                        .environment(\.layoutDirection, .leftToRight)
                    Text(meta).font(mono(11)).foregroundStyle(KOnb.text3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if selected {
                    KIcon(name: .check, size: 14, width: 2.6)
                        .foregroundStyle(KPhone.ctaText)
                        .frame(width: 24, height: 24)
                        .background(KOnb.pri, in: Circle())
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 64)
            .background(selected ? KOnb.priSoft : .clear)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var fields: some View {
        VStack(spacing: 12) {
            field(d("Ders adı"), text: $lessonName)
            field(d("Ders"), text: $courseName)
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(KFont.ui(13, .medium, lang: lang)).foregroundStyle(KPhone.text2)
            TextField("", text: text)
                .font(KFont.ui(15, lang: lang)).foregroundStyle(KPhone.text)
                .padding(.horizontal, 14).frame(height: 48)
                .background(KPhone.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(KPhone.line, lineWidth: 1))
        }
    }

    // MARK: Photo

    private var photoContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 4) {
                        tab("PDF", on: false) { mode = .pick }
                        tab(d("Fotoğraf"), on: true) {}
                    }
                    .padding(4)
                    .background(KPhone.sub, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    viewfinder
                    HStack {
                        Button { shots = min(30, shots + 3); toast.show(d("Galeriden 3 fotoğraf eklendi")) } label: {
                            KIcon(name: .image, size: 22, width: 1.7)
                                .foregroundStyle(KPhone.text)
                                .frame(width: 48, height: 48)
                                .background(KPhone.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(KPhone.line, lineWidth: 1))
                        }
                        .accessibilityLabel(d("Galeriden seç"))
                        Spacer()
                        Button { shots = min(30, shots + 1) } label: {
                            Circle().fill(KOnb.pri).frame(width: 54, height: 54)
                                .frame(width: 72, height: 72)
                                .background(KPhone.card, in: Circle())
                                .overlay(Circle().stroke(KOnb.pri, lineWidth: 4))
                        }
                        .accessibilityLabel(d("Fotoğraf çek"))
                        Spacer()
                        Text("\(Format.num(shots, lang))/\(Format.num(30, lang))").font(KFont.mono(12, .semibold)).foregroundStyle(KPhone.text2)
                            .frame(width: 48)
                    }
                    .padding(.horizontal, 24)
                    Text(d("ÇEKİLEN SAYFALAR · SIRALAMAK İÇİN SÜRÜKLE")).font(mono(10)).tracking(lang.isRTL ? 0 : 1).foregroundStyle(KOnb.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(1...max(shots, 1), id: \.self) { i in thumb(i) }
                        }
                    }
                    infoBox(.shield, d("Metin tanıma (OCR) ile her fotoğrafı okunabilir karta çeviririz; hocanın yazısı aynen korunur. El yazısı da olur. Sayfalar net, düz ve gölgesiz olsun."), size: 12)
                }
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 16)
            }
            footer("\(d("Dersi hazırla · "))\(shots)\(d(" sayfa"))") { prepare() }
        }
    }

    private func tab(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(KFont.ui(13, on ? .semibold : .regular, lang: lang))
                .foregroundStyle(on ? KPhone.text : KPhone.text2)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(on ? KPhone.card : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .shadow(color: on ? Color.black.opacity(0.12) : .clear, radius: 1.5, y: 1)
        }
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// The camera view of the design (a still page with the corner marks). Taking real photos comes with the camera permission later.
    private var viewfinder: some View {
        ZStack {
            Color(hex: 0x0E1218)
            VStack(alignment: .leading, spacing: 8) {
                Text(d("Antidotlar")).font(KFont.reading(11, .semibold, lang: lang)).foregroundStyle(Color(hex: 0x2A2420))
                ForEach([0.92, 0.8, 0.88, 0.6, 0.84, 0.7], id: \.self) { w in
                    GeometryReader { g in Capsule().fill(Color(hex: 0xB3A898)).frame(width: g.size.width * w, height: 4) }.frame(height: 4)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.vertical, 18)
            .frame(width: 200, height: 236)
            .background(Color(hex: 0xF4F1EA), in: RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.4), radius: 15, y: 10)
            .rotationEffect(.degrees(-3))
            ForEach(0..<4, id: \.self) { i in
                CornerMark()
                    .stroke(KColor.amb, lineWidth: 3)
                    .frame(width: 26, height: 26)
                    .rotationEffect(.degrees(Double(i) * 90))
                    .offset(x: i == 0 || i == 3 ? -60 : 60, y: i < 2 ? -96 : 96)
            }
            Text(d("SAYFAYI ÇERÇEVEYE AL")).font(mono(10)).tracking(lang.isRTL ? 0 : 0.8).foregroundStyle(KColor.amb)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
                .frame(maxHeight: .infinity, alignment: .top).padding(.top, 10)
        }
        .frame(height: 290)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .environment(\.layoutDirection, .leftToRight)
    }

    private func thumb(_ i: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach([0.9, 0.7, 0.85, 0.6], id: \.self) { w in
                GeometryReader { g in Capsule().fill(Color(hex: 0xB7BEC8)).frame(width: g.size.width * w, height: 3) }.frame(height: 3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6).padding(.vertical, 8)
        .frame(width: 58, height: 74)
        .background(Color(hex: 0xF4F1EA), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(KPhone.line, lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            Text(Format.num(i, lang)).font(mono(10)).foregroundStyle(KPhone.ctaText)
                .frame(width: 18, height: 18).background(KOnb.pri, in: Circle()).padding(4)
        }
    }

    // MARK: Audio

    private var audioContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(d("Ders ses kaydı ekle")).font(KFont.ui(24, .bold, lang: lang)).kLineHeight(1.2, size: 24, lang: lang).foregroundStyle(KPhone.text)
                            .accessibilityAddTraits(.isHeader)
                        Text(d("Kaydı metne çevirip PDF sayfalarıyla eşleştiririz. Hocanın çok durduğu konulara özetinde ve sınavlarında daha çok ağırlık veririz."))
                            .font(KFont.ui(14, lang: lang)).kLineHeight(1.5, size: 14, lang: lang).foregroundStyle(KPhone.text2)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(d("Hangi derse ait?")).font(KFont.ui(13, .medium, lang: lang)).foregroundStyle(KPhone.text2)
                        HStack(spacing: 10) {
                            Text("PDF").font(KFont.mono(9, .semibold)).foregroundStyle(KOnb.priText)
                                .padding(.horizontal, 5).padding(.vertical, 3).background(KOnb.priSoft, in: RoundedRectangle(cornerRadius: 4))
                            Text(d("Hipertansiyon")).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            KIcon(name: .chevronDown, size: 14, width: 2).foregroundStyle(KPhone.text2)
                        }
                        .padding(.horizontal, 14).frame(height: 52)
                        .background(KPhone.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(KPhone.line, lineWidth: 1))
                    }
                    HStack(spacing: 10) {
                        Button { showAudioImporter = true } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                KIcon(name: .audioFile, size: 22, width: 1.7).foregroundStyle(KOnb.priText)
                                Text(d("Kayıt dosyası seç")).font(KFont.ui(14, .bold, lang: lang)).foregroundStyle(KPhone.text)
                                Text("M4A · MP3 · WAV").font(mono(10)).foregroundStyle(KOnb.text3)
                            }
                            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading).padding(12)
                            .background(KOnb.priSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(KOnb.pri, lineWidth: 2))
                        }
                        Button { toast.show(d("Kayıt başladı · telefonu masaya koy")) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack {
                                    Circle().stroke(KOnb.bad, lineWidth: 2)
                                    Circle().fill(KOnb.bad).frame(width: 10, height: 10)
                                }
                                .frame(width: 22, height: 22)
                                Text(d("Derste canlı kaydet")).font(KFont.ui(14, .bold, lang: lang)).foregroundStyle(KPhone.text)
                                Text(d("Ekran kapalıyken de kaydeder")).font(KFont.ui(11, lang: lang)).foregroundStyle(KOnb.text3)
                            }
                            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading).padding(12)
                            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(KPhone.line, lineWidth: 1))
                        }
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 12) {
                        KIcon(name: .wave, size: 18, width: 1.8)
                            .foregroundStyle(KOnb.priText)
                            .frame(width: 36, height: 36)
                            .background(KOnb.priSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(audioName ?? "Farmakoterapi_08Ekim.m4a").font(KFont.ui(14, .semibold, lang: lang)).lineLimit(1).truncationMode(.middle).foregroundStyle(KPhone.text)
                                .environment(\.layoutDirection, .leftToRight)
                            Text("52:18 · 48 MB").font(mono(11)).foregroundStyle(KOnb.text3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        KIcon(name: .check, size: 14, width: 2.6).foregroundStyle(KPhone.ctaText)
                            .frame(width: 24, height: 24).background(KOnb.pri, in: Circle())
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(KPhone.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(d("HAZIRLAYACAKLARIMIZ")).font(mono(10)).tracking(lang.isRTL ? 0 : 1).foregroundStyle(KOnb.text3)
                        ForEach(["Konuşmanın tam metni, zaman damgalarıyla", "Her bölümün PDF sayfasıyla eşleşmesi", "Hocanın uzun durduğu ve tekrar ettiği konular", "“Sınavda çıkar” gibi ipuçları"], id: \.self) { line in
                            HStack(alignment: .top, spacing: 8) {
                                Text("✓").font(KFont.ui(13, .bold, lang: lang)).foregroundStyle(KOnb.priText)
                                Text(d(line)).font(KFont.ui(13, lang: lang)).kLineHeight(1.4, size: 13, lang: lang).foregroundStyle(KPhone.text)
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(KPhone.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    infoBox(.shield, d("Kayıt yalnızca senin hesabında saklanır. Derse kayıt almadan önce hocandan izin almayı unutma."), size: 12)
                }
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 16)
            }
            footer(d("Metne çevir ve PDF ile eşleştir")) { soon() }
        }
    }

    // MARK: Processing

    private let stepTitles = ["Tam metin", "Terim açıklamaları", "Çeviri", "Sınav soruları", "Kartlar"]
    private let stepDetails = ["48 sayfa · metin aynen korunur", "126 terim", "English · فارسی · العربية", "64 soru", "40 kart"]

    private var processingContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                fileBadge(KOnb.priText, KOnb.priSoft)
                VStack(alignment: .leading, spacing: 2) {
                    Text(picked.map { _ in lessonName } ?? d("Hipertansiyon")).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                    Text("\(d("Farmakoterapi ·")) \(picked.map { Format.fileMeta(pages: $0.pages, megabytes: $0.megabytes, lang) } ?? d("48 sayfa · 6,2 MB"))")
                        .font(mono(11)).foregroundStyle(KOnb.text3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(d("Ders hazırlanıyor…")).font(KFont.ui(28, .bold, lang: lang)).kTracking(-0.02, size: 28, lang: lang).foregroundStyle(KPhone.text)
                    .accessibilityAddTraits(.isHeader)
                Text(d("Yaklaşık 2 dakika sürer. Uygulamayı kapatabilirsin; hazır olunca bildirim göndeririz."))
                    .font(KFont.ui(14, lang: lang)).kLineHeight(1.5, size: 14, lang: lang).foregroundStyle(KPhone.text2)
            }
            .padding(.top, 6)
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    HStack(spacing: 14) {
                        stepIcon(i)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d(stepTitles[i])).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(i <= doneSteps ? KPhone.text : KOnb.text3)
                            Text(i == 2 ? stepDetails[i] : d(stepDetails[i])).font(mono(11)).foregroundStyle(KOnb.text3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 62)
                    .overlay(alignment: .bottom) { if i < 4 { Rectangle().fill(KPhone.line).frame(height: 1) } }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            HStack(spacing: 10) {
                Capsule().fill(KPhone.line).frame(height: 8)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in Capsule().fill(KOnb.pri).frame(width: g.size.width * CGFloat(progress) / 100) }
                    }
                Text(Format.percent(progress, lang)).font(KFont.mono(12, .regular)).foregroundStyle(KPhone.text2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20)
        .task(id: runID) { await runProcessing() }
    }

    private var progress: Int { min(100, Int((Double(doneSteps) / 5 * 100).rounded()) + (doneSteps < 5 ? 8 : 0)) }

    @ViewBuilder private func stepIcon(_ i: Int) -> some View {
        if i < doneSteps {
            KIcon(name: .check, size: 16, width: 2.6)
                .foregroundStyle(Color.pair(0xFFFCF6, 0x0E2A1D))
                .frame(width: 28, height: 28).background(KOnb.ok, in: Circle())
        } else if i == doneSteps {
            SpinnerRing().frame(width: 28, height: 28)
        } else {
            Circle().strokeBorder(KPhone.line, style: StrokeStyle(lineWidth: 2, dash: [3, 3])).frame(width: 24, height: 24).frame(width: 28, height: 28)
        }
    }

    // MARK: Error

    private var errorContent: some View {
        VStack(spacing: 12) {
            KIcon(name: .fileX, size: 34, width: 1.6)
                .foregroundStyle(KOnb.bad)
                .frame(width: 72, height: 72)
                .background(KOnb.badSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .rotationEffect(.degrees(-7))
            Text(d("Bu PDF'ten metin okunamadı")).font(KFont.ui(24, .bold, lang: lang)).kLineHeight(1.2, size: 24, lang: lang)
                .multilineTextAlignment(.center).foregroundStyle(KPhone.text).padding(.top, 10)
                .accessibilityAddTraits(.isHeader)
            Text(d("Dosya taranmış sayfalardan oluşuyor gibi görünüyor. Metni seçilebilir bir PDF dene ya da metin tanıma (OCR) ile devam et."))
                .font(KFont.ui(15, lang: lang)).kLineHeight(1.55, size: 15, lang: lang)
                .multilineTextAlignment(.center).foregroundStyle(KPhone.text2)
            HStack(spacing: 12) {
                fileBadge(KOnb.bad, KOnb.badSoft)
                VStack(alignment: .leading, spacing: 2) {
                    Text(picked?.name ?? "Biyofarmasotik_tarama.pdf").font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                        .lineLimit(1).truncationMode(.middle).environment(\.layoutDirection, .leftToRight)
                    Text(d("HATA · METİN BULUNAMADI")).font(mono(11)).foregroundStyle(KOnb.bad)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 8)
            Spacer()
            Button { picked = nil; mode = .pick; showPDFImporter = true } label: {
                Text(d("Başka dosya seç")).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(KOnb.pri, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Button { startProcessing() } label: {
                Text(d("Metin tanıma ile dene")).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(KPhone.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(KPhone.line, lineWidth: 1))
            }
            Text(d("Bu deneme ücretsiz ders hakkından düşmez.")).font(KFont.ui(12, lang: lang)).foregroundStyle(KOnb.text3).padding(.bottom, 6)
        }
        .padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 8)
    }

    // MARK: Actions

    private func select(mock name: String, pages: Int, mb: Double) {
        picked = PickedPDF(name: name, pages: pages, megabytes: mb, hasText: true)
        lessonName = d(name.hasPrefix("Diyabet") ? "Diyabet" : "Hipertansiyon")
    }

    /// A real file: read its pages with PDFKit.
    private func handlePicked(_ url: URL) {
        guard let info = PDFInspector.inspect(url) else {
            toast.show(d("Bu PDF'ten metin okunamadı"))
            return
        }
        picked = info
        lessonName = url.deletingPathExtension().lastPathComponent
        if info.pages > TrialLimits.pagesPerPdf { rangeTo = String(TrialLimits.pagesPerPdf); longSheet = true }
    }

    /// "Dersi hazırla": needs the trial / Premium to allow a new PDF; scanned PDFs show the error first.
    private func prepare() {
        trial.perform(.pdf) {
            if let picked, !picked.hasText { mode = .error; return }
            if let picked, picked.pages > TrialLimits.pagesPerPdf { longSheet = true; return }
            startProcessing()
        }
    }

    private func startProcessing() {
        doneSteps = 0
        runID += 1
        mode = .processing
    }

    /// Mock server: one step every 0.85 s, then the lesson counts against the trial and the student goes home.
    private func runProcessing() async {
        while doneSteps < 5 {
            if MockFlag.value("uploadMode") == "processing" { return } // test switch keeps the screen still
            try? await Task.sleep(for: .milliseconds(850))
            if Task.isCancelled { return }
            doneSteps += 1
        }
        try? await Task.sleep(for: .milliseconds(700))
        if Task.isCancelled { return }
        if !trial.status.premium { trial.status.pdfsUsed += 1 }
        // Mock server: every lesson opens the sample lesson until the PDF processing exists (see TODO.md).
        app.reset(to: .home)
        app.go(.reader("hypertension"))
    }

    // MARK: "This PDF is too long" sheet

    private struct LongTexts {
        let title, body, meta, split, splitSub, range, rangeSub, tooMany, cont, other: String
        let pages: (Int) -> String
    }

    private func longTexts() -> LongTexts {
        switch lang {
        case .tr: LongTexts(title: "Bu PDF çok uzun", body: "Bir derste en fazla 100 sayfa hazırlayabiliyoruz. Hangi kısmı çalışmak istediğini seç.", meta: "", split: "Bölümlere ayır", splitSub: "İçindekiler'e göre 4 ayrı ders: 38 · 44 · 41 · 41 sayfa", range: "Sayfa aralığı seç", rangeSub: "En fazla 100 sayfa", tooMany: "En fazla 100 sayfa seçebilirsin", cont: "Devam et", other: "Başka dosya seç", pages: { "\($0) sayfa" })
        case .en: LongTexts(title: "This PDF is too long", body: "We can prepare up to 100 pages per lesson. Choose the part you want to study.", meta: "", split: "Split into chapters", splitSub: "By table of contents, 4 lessons: 38 · 44 · 41 · 41 pages", range: "Choose a page range", rangeSub: "Up to 100 pages", tooMany: "You can choose up to 100 pages", cont: "Continue", other: "Choose another file", pages: { "\($0) pages" })
        case .fa: LongTexts(title: "این PDF خیلی طولانی است", body: "در هر درس حداکثر ۱۰۰ صفحه آماده می‌کنیم. بخشی را که می‌خواهی بخوانی انتخاب کن.", meta: "", split: "تقسیم به فصل‌ها", splitSub: "بر اساس فهرست، ۴ درس جدا: ۳۸ · ۴۴ · ۴۱ · ۴۱ صفحه", range: "انتخاب بازهٔ صفحه", rangeSub: "حداکثر ۱۰۰ صفحه", tooMany: "حداکثر ۱۰۰ صفحه می‌توانی انتخاب کنی", cont: "ادامه", other: "انتخاب فایل دیگر", pages: { "\(Format.num($0, .fa)) صفحه" })
        case .ar: LongTexts(title: "ملف PDF هذا طويل جدًا", body: "يمكننا تجهيز 100 صفحة كحد أقصى لكل درس. اختر الجزء الذي تريد دراسته.", meta: "", split: "قسّمه إلى فصول", splitSub: "حسب الفهرس، 4 دروس منفصلة: 38 · 44 · 41 · 41 صفحة", range: "اختر نطاق الصفحات", rangeSub: "100 صفحة كحد أقصى", tooMany: "يمكنك اختيار 100 صفحة كحد أقصى", cont: "متابعة", other: "اختيار ملف آخر", pages: { "\($0) صفحة" })
        }
    }

    private var rangeCount: Int? {
        guard let from = Int(rangeFrom), let to = Int(rangeTo), let total = picked?.pages ?? Optional(164) else { return nil }
        guard from >= 1, to <= total, from <= to else { return nil }
        return to - from + 1
    }

    private var longPdfSheet: some View {
        let t = longTexts()
        let bad = !splitMode && (rangeCount.map { $0 > TrialLimits.pagesPerPdf } ?? true)
        return ZStack(alignment: .bottom) {
            Color(hex: 0x140E0A, opacity: 0.45).ignoresSafeArea().onTapGesture { longSheet = false }
            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(Color.pair(0xE2D7C6, 0x4A403A)).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.bottom, 18)
                HStack(spacing: 12) {
                    fileBadge(Color(hex: 0x9C2F3A), KPhone.sub, border: true, size: CGSize(width: 44, height: 52))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(picked?.name ?? "Farmakoloji_Tum_Notlar.pdf").font(KFont.ui(15, .bold, lang: lang)).lineLimit(1).truncationMode(.middle)
                            .foregroundStyle(KPhone.text).environment(\.layoutDirection, .leftToRight)
                        Text(Format.fileMeta(pages: picked?.pages ?? 164, megabytes: picked?.megabytes ?? 31, lang).uppercased()).font(mono(11)).foregroundStyle(KPhone.text2)
                    }
                }
                .padding(.bottom, 12)
                Text(t.title).font(KFont.ui(21, .bold, lang: lang)).foregroundStyle(KPhone.text).padding(.bottom, 6)
                Text(t.body).font(KFont.ui(14.5, lang: lang)).kLineHeight(1.5, size: 14.5, lang: lang).foregroundStyle(KPhone.text2).padding(.bottom, 14)
                choice(on: splitMode, title: t.split, sub: t.splitSub) { splitMode = true }.padding(.bottom, 10)
                VStack(alignment: .leading, spacing: 10) {
                    Button { splitMode = false } label: {
                        HStack(spacing: 12) {
                            radio(!splitMode)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.range).font(KFont.ui(15, .bold, lang: lang)).foregroundStyle(KPhone.text)
                                Text(t.rangeSub).font(KFont.ui(12.5, lang: lang)).foregroundStyle(KPhone.text2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                    if !splitMode {
                        HStack(spacing: 8) {
                            rangeField($rangeFrom, label: "from")
                            Text("–").foregroundStyle(KPhone.text2)
                            rangeField($rangeTo, label: "to")
                            Text(bad ? t.tooMany : t.pages(rangeCount ?? 0)).font(KFont.ui(13, lang: lang))
                                .foregroundStyle(bad ? KOnb.bad : KPhone.text2).padding(.leading, 6)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                        .padding(.leading, 34)
                    }
                }
                .padding(14)
                .background(!splitMode ? KOnb.priSoft : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(!splitMode ? KOnb.pri : KPhone.line, lineWidth: !splitMode ? 1.5 : 1))
                .padding(.bottom, 8)
                Button {
                    guard !bad else { return }
                    longSheet = false
                    startProcessing()
                } label: {
                    Text(t.cont).font(KFont.ui(16, .semibold, lang: lang)).foregroundStyle(Color(hex: 0xFFF6E6))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color(hex: 0x9C2F3A), in: Capsule())
                        .opacity(bad ? 0.45 : 1)
                }
                .padding(.top, 8)
                Button { longSheet = false; picked = nil } label: {
                    Text(t.other).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text).frame(maxWidth: .infinity, minHeight: 46)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 12)
            .background(Color.pair(0xFFFBF4, 0x221C18), in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 20, y: -10)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func radio(_ on: Bool) -> some View {
        ZStack {
            Circle().stroke(KPhone.line, lineWidth: 2)
            Circle().fill(KOnb.pri).frame(width: 10, height: 10).opacity(on ? 1 : 0)
        }
        .frame(width: 22, height: 22)
    }

    private func choice(on: Bool, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                radio(on)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(KFont.ui(15, .bold, lang: lang)).foregroundStyle(KPhone.text)
                    Text(sub).font(KFont.ui(12.5, lang: lang)).foregroundStyle(KPhone.text2).multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(on ? KOnb.priSoft : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(on ? KOnb.pri : KPhone.line, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func rangeField(_ text: Binding<String>, label: String) -> some View {
        TextField("", text: text)
            .keyboardType(.numberPad)
            .font(KFont.ui(15, lang: .en)).foregroundStyle(KPhone.text)
            .multilineTextAlignment(.center)
            .frame(width: 64, height: 40)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(KPhone.line, lineWidth: 1))
            .accessibilityLabel(label)
    }
}

/// One corner mark of the camera frame.
private struct CornerMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

/// The turning ring next to the step that is being prepared.
private struct SpinnerRing: View {
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle().stroke(KPhone.line, lineWidth: 3)
            Circle().trim(from: 0, to: 0.3).stroke(KOnb.pri, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(spin ? 360 : 0))
        }
        .padding(2)
        .onAppear { withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { spin = true } }
        .accessibilityHidden(true)
    }
}
