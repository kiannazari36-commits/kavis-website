import SwiftUI

/// Design: design/ScrNotifications.dc.html (same as the web's /notifications): grouped by Today / Yesterday / This week
/// (and Earlier), a tilted icon, title, text and time. Opening the screen marks everything read.
struct NotificationsView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app

    @State private var list: [Notice]?
    private let notifyTime = SettingsAPI.loadNow().notifyTime

    private var lang: Lang { prefs.lang }

    private func icon(_ kind: String) -> KIconName {
        switch kind {
        case "study_1h_before", "class_tomorrow": .calendar
        case "start_now": .play
        case "review_day": .refresh
        case "streak": .flame
        case "lesson_ready": .book
        case "exam_result": .check
        case "weekly_report": .chart
        case "cheer": .spark
        case "trial_ending": .lock
        case "share_received": .share
        default: .bell
        }
    }

    /// Icon background and color per kind (as the design's meta list).
    private func tone(_ kind: String) -> (Color, Color) {
        switch kind {
        case "exam_result", "cheer": (KStudy.okSoft, KStudy.ok)
        case "streak", "review_day", "study_1h_before", "class_tomorrow": (KStudy.ambSoft, KStudy.ambText)
        case "weekly_report", "lesson_ready": (Color.pair(0xE5EEFB, 0x1E2C45), Color.pair(0x2557A8, 0x8DB4F5))
        default: (KStudy.priSoft, KStudy.priText)
        }
    }

    private func dayKey(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private var groups: [(String, [Notice])] {
        let today = CoursesAPI.todayISO()
        var out: [[Notice]] = [[], [], [], []]
        let cal = Calendar.current
        let yesterday = dayKey(cal.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        let weekAgo = dayKey(cal.date(byAdding: .day, value: -7, to: Date()) ?? Date())
        for n in list ?? [] {
            let k = dayKey(n.at)
            out[k == today ? 0 : k == yesterday ? 1 : k > weekAgo ? 2 : 3].append(n)
        }
        let labels = [prefs.t("nToday"), prefs.t("nYesterday"), prefs.t("nThisWeek"), prefs.t("nEarlier")]
        return zip(labels, out).filter { !$0.1.isEmpty }.map { ($0.0, $0.1) }
    }

    private func time(_ n: Notice) -> String {
        let today = CoursesAPI.todayISO()
        let yesterday = dayKey(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        let k = dayKey(n.at)
        let f = DateFormatter()
        f.locale = lang.locale
        if k == today || k == yesterday {
            f.dateFormat = "HH:mm"
            return Format.num(f.string(from: n.at), lang)
        }
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f.string(from: n.at)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button { app.back() } label: {
                    KIcon(name: .back, size: 22, width: 1.8, flipsInRTL: true).foregroundStyle(KPhone.text).frame(width: 44, height: 44)
                }
                .accessibilityLabel(prefs.d("Geri"))
                Text(prefs.d("Bildirimler")).font(KFont.ui(20, .bold, lang: lang)).foregroundStyle(KPhone.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { app.go(.settings) } label: {
                    HStack(spacing: 6) {
                        KIcon(name: .clock, size: 14, width: 1.8)
                        Text(Format.num(notifyTime, lang)).font(KFont.mono(12, .regular))
                    }
                    .foregroundStyle(KStudy.text2)
                    .padding(.horizontal, 12).frame(height: 36)
                    .background(KStudy.card, in: Capsule())
                    .overlay(Capsule().stroke(KStudy.line, lineWidth: 1))
                }
            }
            .padding(.leading, 6).padding(.trailing, 12).frame(height: 48)
            .padding(.top, KLayout.top(54, minimum: 6))
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let list, list.isEmpty {
                        Text(prefs.t("noNotifs")).font(KFont.ui(14, lang: lang)).foregroundStyle(KStudy.text2)
                            .frame(maxWidth: .infinity).padding(.top, 60)
                    }
                    ForEach(groups, id: \.0) { label, items in
                        Text(label).font(KFont.ui(14, .bold, lang: lang)).foregroundStyle(KStudy.text2).padding(.top, 14)
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { i, n in
                                row(n, last: i == items.count - 1)
                            }
                        }
                        .background(KStudy.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .padColumn()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KStudy.bg.ignoresSafeArea())
        .task {
            list = await NotificationsAPI.list()
            // The unread dots stay on this visit; the next one shows them read.
            if list?.contains(where: { !$0.read }) == true { await NotificationsAPI.markAllRead() }
        }
    }

    private func row(_ n: Notice, last: Bool) -> some View {
        let c = tone(n.kind)
        return Button { if let r = n.route { app.go(r) } } label: {
            HStack(alignment: .top, spacing: 12) {
                KIcon(name: icon(n.kind), size: 18, width: 1.8).foregroundStyle(c.1)
                    .frame(width: 36, height: 36)
                    .background(c.0, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .rotationEffect(.degrees(-7))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(n.title).font(KFont.ui(15, n.read ? .medium : .bold, lang: lang)).foregroundStyle(KPhone.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(time(n)).font(KFont.mono(11, .regular)).foregroundStyle(KStudy.text3)
                    }
                    Text(n.body).font(KFont.ui(13, lang: lang)).kLineHeight(1.45, size: 13, lang: lang).foregroundStyle(KStudy.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Circle().fill(n.read ? .clear : KStudy.pri).frame(width: 8, height: 8).padding(.top, 8)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { if !last { Rectangle().fill(KStudy.line).frame(height: 1) } }
        }
        .buttonStyle(.plain)
    }
}
