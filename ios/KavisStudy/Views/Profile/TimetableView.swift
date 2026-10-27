import SwiftUI

/// Design: design/NewSchedule.dc.html (same as the web's /schedule, typed-in part): day tabs with each day's classes
/// and a reminder bell, "Ders ekle". Reading a photo / PDF of the timetable is not on the phone yet.
struct TimetableView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast

    @State private var classes: [ClassEntry]?
    @State private var day = 1
    @State private var adding = false

    private var lang: Lang { prefs.lang }
    private func t(_ key: String, _ vars: [String: String] = [:]) -> String { prefs.t(key, vars) }

    private var today: Int { (Calendar(identifier: .gregorian).component(.weekday, from: Date()) + 5) % 7 + 1 }
    private var tomorrow: Int { today % 7 + 1 }

    private func hasClasses(_ wd: Int) -> Bool { (classes ?? []).contains { $0.weekday == wd } }
    /// Monday to Friday always; the weekend only when it has classes.
    private var shownDays: [Int] { (1...7).filter { $0 <= 5 || hasClasses($0) } }

    private func dayName(_ wd: Int, short: Bool) -> String {
        let f = DateFormatter()
        f.locale = lang.locale
        let names = short ? f.shortWeekdaySymbols : f.weekdaySymbols
        // Calendar symbols start on Sunday.
        return (names?[wd % 7] ?? "").capitalized(with: lang.locale)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button { app.back() } label: {
                    KIcon(name: .back, size: 22, width: 1.8, flipsInRTL: true).foregroundStyle(KPhone.text).frame(width: 44, height: 44)
                }
                .accessibilityLabel(prefs.d("Geri"))
                Text(t("schTitle")).font(KFont.ui(20, .bold, lang: lang)).foregroundStyle(KPhone.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 6).padding(.trailing, 12).frame(height: 48)
            .padding(.top, KLayout.top(54, minimum: 6))
            if let classes {
                if classes.isEmpty { empty } else { list(classes) }
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KStudy.bg.ignoresSafeArea())
        .task {
            day = tomorrow
            classes = await TimetableAPI.list()
        }
        .sheet(isPresented: $adding) {
            AddClassSheet(day: day) { await reload() }
                .presentationDetents([.large])
        }
    }

    private func reload() async { classes = await TimetableAPI.list() }

    // MARK: Empty

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                KIcon(name: .calendar, size: 26, width: 1.7).foregroundStyle(KStudy.priText)
                    .frame(width: 54, height: 54).background(Color.white.opacity(0.6), in: Circle())
                Text(t("schEmptyT")).font(KFont.ui(22, .semibold, lang: lang)).foregroundStyle(Color(hex: 0x2A2420))
                Text(t("schEmptyS")).font(KFont.ui(14, lang: lang)).kLineHeight(1.5, size: 14, lang: lang).foregroundStyle(Color(hex: 0x2A2420))
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(hex: 0xFBE9BD), Color(hex: 0xF5C76A)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            Button { adding = true } label: {
                HStack(spacing: 8) {
                    KIcon(name: .plus, size: 16, width: 2)
                    Text(t("schAdd")).font(KFont.ui(15, .semibold, lang: lang))
                }
                .foregroundStyle(KPhone.ctaText).frame(maxWidth: .infinity, minHeight: 52)
                .background(KStudy.pri, in: Capsule())
            }
            Label { Text(t("schPrivate")).font(KFont.ui(12, lang: lang)).foregroundStyle(KStudy.text2) } icon: {
                KIcon(name: .lock, size: 15, width: 1.8).foregroundStyle(KStudy.text2)
            }
            .padding(4)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }

    // MARK: List

    private func list(_ all: [ClassEntry]) -> some View {
        let shown = all.filter { $0.weekday == day }
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(shownDays, id: \.self) { wd in dayTab(wd) }
                }
                Text(dayName(day, short: false)).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text).padding(.horizontal, 4).padding(.top, 2)
                if shown.isEmpty {
                    Text(t("schNoClasses")).font(KFont.ui(14, lang: lang)).foregroundStyle(KStudy.text2).padding(.horizontal, 4)
                }
                ForEach(shown) { c in row(c) }
                Button { adding = true } label: {
                    HStack(spacing: 8) {
                        KIcon(name: .plus, size: 16, width: 2)
                        Text(t("schAdd")).font(KFont.ui(14, lang: lang))
                    }
                    .foregroundStyle(KPhone.text).frame(maxWidth: .infinity, minHeight: 48)
                    .overlay(Capsule().strokeBorder(KStudy.line, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                }
                Label { Text(t("schPrivate")).font(KFont.ui(12, lang: lang)).foregroundStyle(KStudy.text2) } icon: {
                    KIcon(name: .lock, size: 15, width: 1.8).foregroundStyle(KStudy.text2)
                }
                .padding(4)
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }

    private func dayTab(_ wd: Int) -> some View {
        let on = wd == day
        let tag = wd == today ? t("schToday") : wd == tomorrow ? t("schTomorrow") : ""
        return Button { day = wd } label: {
            VStack(spacing: 1) {
                Text(dayName(wd, short: true)).font(KFont.ui(14, .semibold, lang: lang))
                Text(tag.isEmpty ? " " : tag).font(KFont.ui(9, .semibold, lang: lang)).opacity(0.8).frame(height: 11)
            }
            .foregroundStyle(on ? KPhone.ctaText : KPhone.text)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(on ? KStudy.pri : KStudy.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(on ? .clear : KStudy.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func row(_ c: ClassEntry) -> some View {
        let detail = [c.room, c.teacher].compactMap { $0 }.joined(separator: " · ")
        return HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text(Format.num(c.start, lang)).font(KFont.mono(13, .semibold))
                Text(c.end.map { Format.num($0, lang) } ?? "").font(KFont.mono(10, .regular))
            }
            .foregroundStyle(KStudy.priText).frame(width: 58).padding(.vertical, 7)
            .background(KStudy.priSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(c.title).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                if !detail.isEmpty { Text(detail).font(KFont.ui(12, lang: lang)).foregroundStyle(KStudy.text2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { toggle(c) } label: {
                KIcon(name: .bell, size: 19, width: 1.8).foregroundStyle(c.remind ? KStudy.ambText : KStudy.text3)
                    .frame(width: 42, height: 42)
                    .background(c.remind ? KStudy.ambSoft : .clear, in: Circle())
                    .overlay(Circle().stroke(c.remind ? .clear : KStudy.line, lineWidth: 1))
            }
            .accessibilityLabel(c.remind ? t("schRemind") : t("schRemindOff"))
            .accessibilityAddTraits(c.remind ? .isSelected : [])
        }
        .padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 12)
        .background(KStudy.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(KStudy.line, lineWidth: 1))
        .contextMenu {
            Button(role: .destructive) { remove(c) } label: { Label(t("schDelete"), systemImage: "trash") }
        }
    }

    private func toggle(_ c: ClassEntry) {
        guard let i = classes?.firstIndex(of: c) else { return }
        classes?[i].remind.toggle()
        let on = classes?[i].remind ?? false
        Task { await TimetableAPI.setRemind(c.id, on) }
    }

    private func remove(_ c: ClassEntry) {
        classes?.removeAll { $0.id == c.id }
        toast.show(c.title + t("schDeleted"))
        Task { await TimetableAPI.delete(c.id) }
    }
}

/// "Ders ekle": name, day, start / end, classroom and teacher.
private struct AddClassSheet: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss

    let day: Int
    let onSaved: () async -> Void

    @State private var title = ""
    @State private var weekday = 1
    @State private var start = Self.time(9, 0)
    @State private var end = Self.time(10, 50)
    @State private var room = ""
    @State private var teacher = ""
    @State private var saving = false

    private var lang: Lang { prefs.lang }
    private static func time(_ h: Int, _ m: Int) -> Date { Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date() }
    private static let hm: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private func dayName(_ wd: Int) -> String {
        let f = DateFormatter()
        f.locale = lang.locale
        return (f.weekdaySymbols?[wd % 7] ?? "").capitalized(with: lang.locale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(prefs.t("schAdd")).font(KFont.ui(20, .bold, lang: lang)).foregroundStyle(KPhone.text).padding(.top, 20)
            field(prefs.t("schName"), text: $title)
            HStack {
                Text(prefs.t("schDay")).font(KFont.ui(14, lang: lang)).foregroundStyle(KStudy.text2)
                Spacer()
                Picker("", selection: $weekday) { ForEach(1...7, id: \.self) { Text(dayName($0)).tag($0) } }.tint(KStudy.priText)
            }
            HStack {
                Text(prefs.t("schStart")).font(KFont.ui(14, lang: lang)).foregroundStyle(KStudy.text2)
                DatePicker("", selection: $start, displayedComponents: .hourAndMinute).labelsHidden()
                Spacer()
                Text(prefs.t("schEnd")).font(KFont.ui(14, lang: lang)).foregroundStyle(KStudy.text2)
                DatePicker("", selection: $end, displayedComponents: .hourAndMinute).labelsHidden()
            }
            field(prefs.t("schRoom"), text: $room)
            field(prefs.t("schTeacher"), text: $teacher)
            Spacer()
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text(prefs.t("schCancel")).font(KFont.ui(15, lang: lang)).foregroundStyle(KPhone.text)
                        .frame(maxWidth: .infinity, minHeight: 50).overlay(Capsule().stroke(KStudy.line, lineWidth: 1))
                }
                Button { save() } label: {
                    Text(prefs.t("save")).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                        .frame(maxWidth: .infinity, minHeight: 50).background(KStudy.pri.opacity(saving ? 0.5 : 1), in: Capsule())
                }
                .disabled(saving)
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KStudy.bg.ignoresSafeArea())
        .onAppear { weekday = day }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(label).foregroundStyle(KStudy.text3))
            .font(KFont.ui(15, lang: lang)).foregroundStyle(KPhone.text)
            .padding(.horizontal, 16).frame(height: 48)
            .background(KStudy.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(KStudy.line, lineWidth: 1))
    }

    private func save() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return toast.show(prefs.t("schNeedName")) }
        saving = true
        Task {
            let ok = await TimetableAPI.add(weekday: weekday, start: Self.hm.string(from: start), end: end > start ? Self.hm.string(from: end) : nil,
                                            title: title, room: room, teacher: teacher)
            saving = false
            if ok {
                toast.show(title + prefs.t("schAdded"))
                await onSaved()
                dismiss()
            } else {
                toast.show(prefs.t("errOther"))
            }
        }
    }
}
