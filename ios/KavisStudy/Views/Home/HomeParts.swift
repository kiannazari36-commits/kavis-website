import SwiftUI

// Small pieces of the home screen (design/NewHome.dc.html).

/// Text turned to read from bottom to top (the side tab of today's plan).
struct VerticalText: View {
    let text: String
    let font: Font
    @State private var size: CGSize = .zero

    var body: some View {
        Text(text)
            .font(font)
            .fixedSize()
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { size = g.size }
                    .onChange(of: g.size) { _, new in size = new }
            })
            .rotationEffect(.degrees(-90))
            .frame(width: size.height, height: size.width)
    }
}

/// The floating bar at the bottom: My Courses (current), Progress, Settings.
struct FloatingTabBar: View {
    @Environment(AppPrefs.self) private var prefs
    var onCourses: () -> Void
    var onProgress: () -> Void
    var onSettings: () -> Void

    var body: some View {
        let lang = prefs.lang
        HStack(spacing: 6) {
            Button(action: onCourses) {
                HStack(spacing: 8) {
                    KIcon(name: .book, size: 22, width: 1.6)
                        .frame(width: 40, height: 40)
                        .background(KPhone.navActiveIcon, in: Circle())
                    Text(prefs.t("home.k785")).font(KFont.ui(14, .medium, lang: lang))
                }
                .foregroundStyle(KPhone.ctaText)
                .padding(.leading, 6).padding(.trailing, 18)
                .frame(height: 52)
                .background(KPhone.navActive, in: Capsule())
            }
            .accessibilityAddTraits(.isSelected)
            navButton(.chart, label: prefs.t("home.navProgress"), action: onProgress)
            navButton(.sliders, label: prefs.t("home.navSettings"), action: onSettings)
        }
        .padding(6)
        .background(KPhone.nav, in: Capsule())
        .shadow(color: Color(hex: 0x2A2420, opacity: 0.18), radius: 15, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(prefs.t("home.k361"))
    }

    private func navButton(_ icon: KIconName, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            KIcon(name: icon, size: 22, width: 1.6)
                .foregroundStyle(KPhone.navIcon)
                .frame(width: 52, height: 52)
        }
        .accessibilityLabel(label)
    }
}

/// One line of today's plan.
struct PlanItem: Identifiable {
    let id: Int
    let icon: KIconName
    let chip: Color
    let fg: Color
    let title: String
    let sub: String

    static let today: [PlanItem] = [
        PlanItem(id: 1, icon: .checklist, chip: KPhone.tile1, fg: KPhone.tile1Text, title: "home.plan1", sub: "home.plan1s"),
        PlanItem(id: 2, icon: .syncHalf, chip: KPhone.tile2, fg: KPhone.tile2Text, title: "home.plan2", sub: "home.plan2s"),
        PlanItem(id: 3, icon: .mic, chip: KPhone.tile3, fg: KPhone.tile3Text, title: "home.plan3", sub: "home.plan3s"),
    ]
}

/// The tab on the screen edge that opens today's plan.
struct PlanTab: View {
    @Environment(AppPrefs.self) private var prefs
    var action: () -> Void

    var body: some View {
        let lang = prefs.lang
        Button(action: action) {
            VStack(spacing: 10) {
                Text(Format.num(PlanItem.today.count, lang))
                    .font(KFont.ui(11, .bold, lang: lang))
                    .foregroundStyle(KPhone.ctaText)
                    .frame(width: 24, height: 24)
                    .background(KPhone.navActive, in: Circle())
                VerticalText(text: prefs.t("home.k613"), font: KFont.ui(12, .semibold, lang: lang))
                    .foregroundStyle(KPhone.text)
                KIcon(name: .chevronLeft, size: 14, width: 2.2, flipsInRTL: true)
                    .foregroundStyle(KPhone.text)
            }
            .padding(.top, 10).padding(.bottom, 12)
            .frame(width: 36)
            .background(KPhone.bannerBg, in: shape)
            .overlay(shape.stroke(KPhone.bannerLine, lineWidth: 1))
            .shadow(color: Color(hex: 0x2A2420, opacity: 0.12), radius: 10, x: -6, y: 8)
        }
        .accessibilityLabel(prefs.t("home.k614"))
    }

    // Only the side that faces the page is rounded; the edge of the screen is straight.
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 0, topTrailingRadius: 0, style: .continuous)
    }
}

/// Today's plan slides in from the screen edge over a dimmed page.
struct PlanPanel: View {
    @Environment(AppPrefs.self) private var prefs
    var onClose: () -> Void
    var onItem: () -> Void
    var onWeek: () -> Void

    var body: some View {
        let lang = prefs.lang
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                Color(hex: 0x2A2420, opacity: 0.32)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)
                    .accessibilityLabel(prefs.t("home.k1310"))
                    .accessibilityAddTraits(.isButton)
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        (Text("\(prefs.t("home.p0a")) ").foregroundStyle(KPhone.text) + Text(prefs.t("home.p0b")).foregroundStyle(KPhone.text3))
                            .font(KFont.ui(21, .medium, lang: lang))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button(action: onWeek) {
                            Text(prefs.t("home.k1116")).font(KFont.ui(13, lang: lang)).foregroundStyle(KPhone.text2)
                        }
                        Button(action: onClose) {
                            KIcon(name: .close, size: 14, width: 2.2)
                                .foregroundStyle(KPhone.text2)
                                .frame(width: 40, height: 40)
                                .background(KPhone.card, in: Circle())
                                .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
                        }
                        .accessibilityLabel(prefs.t("home.k616"))
                    }
                    .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 12)
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(PlanItem.today) { item in
                                Button(action: onItem) {
                                    HStack(spacing: 12) {
                                        KIcon(name: item.icon, size: 19, width: 1.6)
                                            .foregroundStyle(item.fg)
                                            .frame(width: 44, height: 44)
                                            .background(item.chip, in: Circle())
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(prefs.t(item.title)).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text)
                                            Text(prefs.t(item.sub)).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        KIcon(name: .chevron, size: 14, width: 2, flipsInRTL: true)
                                            .foregroundStyle(KPhone.text2)
                                            .frame(width: 34, height: 34)
                                            .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 12)
                                    .frame(minHeight: 72)
                                    .kPhoneCard(radius: 22)
                                }
                            }
                        }
                        .padding(.horizontal, 18).padding(.bottom, 30)
                    }
                }
                .frame(width: geo.size.width * 0.88)
                .frame(maxHeight: .infinity)
                .background(KPhone.homeBg.ignoresSafeArea())
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 30, style: .continuous))
                .shadow(color: Color(hex: 0x2A2420, opacity: 0.22), radius: 20, x: -18)
            }
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(prefs.t("home.k613"))
    }
}

extension View {
    /// Phone card: card color, 1 px line.
    func kPhoneCard(radius: CGFloat = 24) -> some View {
        background(KPhone.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(KPhone.line, lineWidth: 1))
    }
}

/// Remaining limits of the free trial (CLAUDE.md: show them during the trial). Same content as web/src/trial/TrialCard.tsx.
struct TrialCardView: View {
    @Environment(AppPrefs.self) private var prefs
    let status: TrialStatus
    var onPremium: () -> Void

    var body: some View {
        let lang = prefs.lang
        if !status.premium {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(prefs.t(status.ended ? "trialEnded" : "trialTitle")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                    Spacer()
                    if !status.ended {
                        Text(prefs.t("trialDaysLeft", ["n": Format.num(status.daysLeft, lang)]))
                            .font(KFont.ui(12, .semibold, lang: lang)).foregroundStyle(KPhone.tile2Text)
                    }
                }
                if status.ended {
                    Text(prefs.t("trialKeep")).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
                } else {
                    meter("PDF", used: status.pdfsUsed, max: TrialLimits.pdfs)
                    meter(prefs.t("trialQuestions"), used: status.questionsUsed, max: TrialLimits.questions)
                    Text(prefs.t("trialPages")).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
                }
                Button(action: onPremium) {
                    Text(prefs.t("goPremium"))
                        .font(KFont.ui(13, .medium, lang: lang))
                        .foregroundStyle(KPhone.ctaText)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(KPhone.navActive, in: Capsule())
                }
                .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(status.ended ? KPhone.tile1 : KPhone.tile2, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private func meter(_ label: String, used: Int, max: Int) -> some View {
        let lang = prefs.lang
        return VStack(spacing: 4) {
            HStack {
                Text(label).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
                Spacer()
                Text("\(Format.num(used, lang))/\(Format.num(max, lang))").font(KFont.mono(12)).foregroundStyle(KPhone.text)
            }
            Capsule().fill(KPhone.text.opacity(0.1)).frame(height: 5)
                .overlay(alignment: .leading) {
                    GeometryReader { g in
                        Capsule().fill(used >= max ? KColor.bad : KPhone.navActive)
                            .frame(width: g.size.width * min(1, CGFloat(used) / CGFloat(max)))
                    }
                }
        }
    }
}

/// "Premium only" message when a locked button is pressed (Trial ended, PDF or question limit, sharing).
struct TrialLockedDialog: View {
    @Environment(AppPrefs.self) private var prefs
    let messageKey: String
    let ended: Bool
    var onCancel: () -> Void
    var onPremium: () -> Void

    var body: some View {
        let lang = prefs.lang
        ZStack {
            Color(hex: 0x2A2420, opacity: 0.4).ignoresSafeArea().onTapGesture(perform: onCancel)
            VStack(spacing: 12) {
                KIcon(name: .lock, size: 24)
                    .foregroundStyle(KPhone.tile1Text)
                    .frame(width: 52, height: 52)
                    .background(KPhone.tile1, in: Circle())
                Text(prefs.t("premiumOnly")).font(KFont.ui(17, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                Text(prefs.t(messageKey))
                    .font(KFont.ui(14, lang: lang))
                    .kLineHeight(1.5, size: 14, lang: lang)
                    .foregroundStyle(KPhone.text2)
                    .multilineTextAlignment(.center)
                if ended {
                    Text(prefs.t("trialKeep")).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text3).multilineTextAlignment(.center)
                }
                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text(prefs.t("delCancel"))
                            .font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
                    }
                    Button(action: onPremium) {
                        Text(prefs.t("goPremium"))
                            .font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.ctaText)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(KPhone.navActive, in: Capsule())
                    }
                }
                .padding(.top, 6)
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(KPhone.line, lineWidth: 1))
            .padding(.horizontal, 24)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
    }
}
