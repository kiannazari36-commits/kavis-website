import SwiftUI

/// "Cihazdaki dersleri yönet" (design ScrSettings): the lessons kept on this phone for offline use (OfflineStore), each with
/// its size and a remove button, and "Hepsini sil". The lessons themselves stay in the account.
struct OfflineLessonsView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss

    var onChange: () -> Void = {}

    @State private var items: [(id: String, bytes: Int)] = []
    @State private var names: [String: (title: String, course: String)] = [:]
    @State private var askAll = false

    private var lang: Lang { prefs.lang }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(prefs.d("Cihazdaki dersler")).font(KFont.ui(20, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                Spacer()
                Button { dismiss() } label: {
                    KIcon(name: .close, size: 16, width: 2).foregroundStyle(KPhone.text)
                        .frame(width: 36, height: 36).background(KPhone.card, in: Circle())
                }
                .accessibilityLabel(prefs.t("schCancel"))
            }
            if items.isEmpty {
                Text(prefs.t("ofEmpty")).font(KFont.ui(14, lang: lang)).foregroundStyle(KPhone.text2)
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                Text(prefs.t("ofTotal", ["n": Format.num(items.count, lang), "size": size(items.reduce(0) { $0 + $1.bytes })]))
                    .font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
                ScrollView {
                    VStack(spacing: 8) { ForEach(items, id: \.id) { row($0) } }
                }
                .scrollIndicators(.hidden)
                Button { askAll = true } label: {
                    Text(prefs.t("ofAll")).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.brand)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .overlay(Capsule().stroke(KPhone.brand.opacity(0.5), lineWidth: 1))
                }
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(KPhone.authBg.ignoresSafeArea())
        .task {
            for c in await CoursesAPI.listCourses() {
                for p in c.pdfs { names[p.id.lowercased()] = (p.title[lang], c.name[lang]) }
            }
            reload()
        }
        .alert(prefs.t("ofAllAsk"), isPresented: $askAll) {
            Button(prefs.t("cfDeleteYes"), role: .destructive) { OfflineStore.removeLessons(); reload(); onChange(); toast.show(prefs.t("ofRemoved")) }
            Button(prefs.t("schCancel"), role: .cancel) {}
        } message: {
            Text(prefs.t("ofAllBody"))
        }
    }

    private func row(_ item: (id: String, bytes: Int)) -> some View {
        let n = names[item.id]
        return HStack(spacing: 12) {
            KIcon(name: .file, size: 20, width: 1.7).foregroundStyle(KPhone.brand)
                .frame(width: 42, height: 42).background(KPhone.sub, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(n?.title ?? prefs.t("ofLesson")).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text).lineLimit(1)
                Text([n?.course, size(item.bytes)].compactMap { $0 }.joined(separator: " · "))
                    .font(KFont.ui(11, lang: lang)).foregroundStyle(KPhone.text3).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                OfflineStore.remove(item.id)
                reload()
                onChange()
                toast.show(prefs.t("ofRemoved"))
            } label: {
                KIcon(name: .trash, size: 18, width: 1.7).foregroundStyle(KPhone.text2).frame(width: 40, height: 40)
            }
            .accessibilityLabel(prefs.t("ofRemoveOne"))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(KPhone.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(KPhone.line, lineWidth: 1))
    }

    private func reload() { items = OfflineStore.lessons() }

    private func size(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
