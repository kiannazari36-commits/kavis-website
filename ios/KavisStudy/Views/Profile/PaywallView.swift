import StoreKit
import SwiftUI

/// Design: design/ScrPaywall.dc.html. Premium with Apple in-app purchase: the trial-vs-Premium table, the three plans
/// with the App Store's own prices (never written in the code), buy, restore. Differences from the design on purpose
/// (CLAUDE.md): the table shows the 3-day trial limits, the button says "Premium'a geç" (there is no Apple free trial),
/// and the store note says how the subscription renews instead of "after the 3-day trial you are charged".
struct PaywallView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast
    @Environment(TrialModel.self) private var trial
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL

    /// Why the paywall opened (a text key, e.g. "pwWhyShare"), shown as the amber chip.
    let reason: String?

    @State private var rows: [CompareRow] = []
    @State private var products: [Product] = []
    @State private var loaded = false
    @State private var selected = StoreAPI.productIds[0]
    @State private var busy = false
    @State private var manageOpen = false

    private var lang: Lang { prefs.lang }
    private func d(_ s: String) -> String { prefs.d(s) }
    private func t(_ key: String, _ vars: [String: String] = [:]) -> String { prefs.t(key, vars) }

    private enum C {
        static let bg = Color.pair(0xF4EFE6, 0x15120F)
        static let card = Color.pair(0xFFFCF6, 0x211C18)
        static let text = Color.pair(0x2A2420, 0xEFE8DC)
        static let text2 = Color.pair(0x6E645A, 0xBDB2A4)
        static let text3 = Color.pair(0x776C60, 0x9A8F82)
        static let line = Color.pair(0xE6DDCF, 0x3A322B)
        static let pri = Color.pair(0x9C2F3A, 0xB23A47)
        static let priText = Color.pair(0x9C2F3A, 0xF09AA3)
        static let priSoft = Color.pair(0xF7E7E9, 0x3A2027)
        static let ambSoft = Color.pair(0xFDF1D6, 0x3A2F1A)
        static let onPri = Color(hex: 0xFFFCF6)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: close) {
                    KIcon(name: .close, size: 18, width: 2).foregroundStyle(C.text2)
                        .frame(width: 44, height: 44).background(C.card, in: Circle())
                }
                .accessibilityLabel(d("Kapat"))
            }
            .padding(.horizontal, 12).padding(.top, KLayout.top(54, minimum: 6))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    table
                    Text(t("pwFair")).font(KFont.ui(11, lang: lang)).kLineHeight(1.4, size: 11, lang: lang).foregroundStyle(C.text3).padding(.top, -6)
                    if trial.status.premium { activeCard } else { plans }
                }
                .padding(.horizontal, 20).padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            if !trial.status.premium { footer }
        }
        .background(C.bg.ignoresSafeArea())
        .manageSubscriptionsSheet(isPresented: $manageOpen)
        .task {
            guard !loaded else { return }
            loaded = true
            rows = await PremiumAPI.getOffer().rows
            products = await StoreAPI.products()
            await trial.refresh()
        }
    }

    private func close() { app.back() }

    // MARK: Top

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            KIcon(name: .sparkle, size: 24, width: 1.8).foregroundStyle(Color(hex: 0xF2B33D))
                .frame(width: 46, height: 46).background(C.pri, in: RoundedRectangle(cornerRadius: 13)).rotationEffect(.degrees(-8))
            HStack(spacing: 12) {
                Wordmark(size: 28)
                Text("PREMIUM").font(KFont.ui(13, .bold, lang: .en)).tracking(1)
                    .foregroundStyle(scheme == .dark ? Color(hex: 0x241C14) : Color(hex: 0xFFF6E6))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(scheme == .dark ? Color(hex: 0xF2B33D) : Color(hex: 0x9C2F3A), in: RoundedRectangle(cornerRadius: 10))
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(.top, 6)
            Text(t("pwSub")).font(KFont.ui(15, lang: lang)).kLineHeight(1.5, size: 15, lang: lang).foregroundStyle(C.text2)
            if let reason {
                HStack(spacing: 8) {
                    KIcon(name: .lock, size: 16, width: 1.8)
                    Text(t(reason)).font(KFont.ui(13, .semibold, lang: lang))
                }
                .foregroundStyle(C.text)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(C.ambSoft, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            row("", d("ÜCRETSİZ"), "PREMIUM", header: true)
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                if r.count == 3 { row(r[0][lang], r[1][lang], r[2][lang], last: i == rows.count - 1) }
            }
        }
        .background(C.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// One line of the table: the feature, the trial value and the Premium value (short marks like ✓ are bigger).
    private func row(_ k: String, _ free: String, _ pro: String, header: Bool = false, last: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(k).font(KFont.ui(13, lang: lang)).foregroundStyle(C.text)
                .kLineHeight(1.35, size: 13, lang: lang)
                .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if header {
                    Text(free).font(KFont.mono(10, .regular)).foregroundStyle(C.text3)
                } else {
                    Text(free).font(KFont.ui(free.count < 3 ? 15 : 12, lang: lang)).foregroundStyle(free == "—" ? C.text3 : C.text2)
                }
            }
            .multilineTextAlignment(.center).frame(width: 80)
            Group {
                if header {
                    Text(pro).font(KFont.mono(10, .semibold)).foregroundStyle(C.priText)
                } else {
                    Text(pro).font(KFont.ui(pro.count < 3 ? 15 : 12, .semibold, lang: lang)).foregroundStyle(C.priText)
                }
            }
            .multilineTextAlignment(.center).frame(width: 80)
        }
        .padding(.horizontal, 14).padding(.vertical, header ? 12 : 10)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(C.line).frame(height: 1) } }
    }

    // MARK: Plans

    private var monthly: Product? { products.first { $0.id.hasSuffix(".month") } }

    private func note(_ p: Product) -> String {
        if p.id.hasSuffix(".month") { return t("pwMonthNote") }
        let months: Decimal = p.id.hasSuffix(".year") ? 12 : 5
        let perMonth = p.price / months
        var parts: [String] = []
        // Only when the prices make sense: a longer plan never costs less than one month (Xcode's local test store
        // reads prices over 1,000 wrongly on a Mac set to Turkish; the real App Store sends the right numbers).
        if let m = monthly?.price, m > 0, p.price >= m {
            parts.append(t("pwPerMonth", ["p": perMonth.formatted(p.priceFormatStyle.precision(.fractionLength(0)))]))
            let save = Int((NSDecimalNumber(decimal: (1 - perMonth / m) * 100)).doubleValue.rounded())
            if save > 0 { parts.append(t("pwSave", ["n": Format.num(save, lang)])) }
        }
        if p.id.hasSuffix(".term") { parts.append(t("pwTermNote")) }
        return parts.joined(separator: " · ")
    }

    private func name(_ p: Product) -> String {
        p.id.hasSuffix(".year") ? d("Yıllık") : p.id.hasSuffix(".term") ? d("Dönemlik · 5 ay") : d("Aylık")
    }

    private var plans: some View {
        VStack(spacing: 10) {
            if products.isEmpty {
                Text(t(loaded ? "pwNoStore" : "pwLoading")).font(KFont.ui(13, lang: lang)).foregroundStyle(C.text3)
                    .frame(maxWidth: .infinity, minHeight: 70)
                    .background(C.card, in: RoundedRectangle(cornerRadius: 16))
            }
            ForEach(products, id: \.id) { p in
                let on = p.id == selected
                Button { selected = p.id } label: {
                    HStack(spacing: 14) {
                        Circle().stroke(on ? C.pri : C.text3, lineWidth: on ? 2 : 1.5).frame(width: 22, height: 22)
                            .overlay { if on { Circle().fill(C.pri).frame(width: 10, height: 10) } }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name(p)).font(KFont.ui(16, .bold, lang: lang)).foregroundStyle(C.text)
                            Text(note(p)).font(KFont.ui(12, lang: lang)).foregroundStyle(C.text3).multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(p.displayPrice).font(KFont.ui(18, .bold, lang: .en)).foregroundStyle(C.text).lineLimit(1).fixedSize()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .frame(minHeight: 70)
                    .background(on ? C.priSoft : C.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(on ? C.pri : C.line, lineWidth: on ? 2 : 1))
                    .overlay(alignment: .topTrailing) { badge(p) }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(d("Plan seç"))
    }

    @ViewBuilder private func badge(_ p: Product) -> some View {
        if p.id.hasSuffix(".year") {
            Text(d("En avantajlı")).font(KFont.ui(12, .bold, lang: lang)).foregroundStyle(Color(hex: 0x2A2420))
                .padding(.horizontal, 11).padding(.vertical, 4)
                .background(Color(hex: 0xF2B33D), in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color(hex: 0x2A2420, opacity: 0.22), radius: 4, y: 3)
                .rotationEffect(.degrees(-4)).offset(x: -14, y: -10)
        } else if p.id.hasSuffix(".month") {
            Text(d("Lansmana özel")).font(KFont.ui(11, .bold, lang: lang)).foregroundStyle(C.onPri)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(C.pri, in: RoundedRectangle(cornerRadius: 6))
                .rotationEffect(.degrees(-3)).offset(x: -14, y: -10)
        }
    }

    /// Already Premium: what is on and where to manage it (the App Store's own sheet).
    private var activeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                KIcon(name: .check, size: 18, width: 2.4).foregroundStyle(C.onPri).frame(width: 34, height: 34).background(C.pri, in: Circle())
                Text(t("pwActive")).font(KFont.ui(17, .bold, lang: lang)).foregroundStyle(C.text)
            }
            RedeemCodeView()
            Text(t("pwIphoneSub")).font(KFont.ui(13, lang: lang)).foregroundStyle(C.text2)
            Button { manageOpen = true } label: {
                Text(t("pwManage")).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(C.onPri)
                    .frame(maxWidth: .infinity, minHeight: 50).background(C.pri, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(16)
        .background(C.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Button { Task { await buy() } } label: {
                Text(d("Premium'a geç")).font(KFont.ui(17, .semibold, lang: lang)).foregroundStyle(C.onPri)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(C.pri, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .opacity(busy || products.isEmpty ? 0.6 : 1)
            }
            .disabled(busy || products.isEmpty)
            Text(t("pwStoreNote")).font(KFont.ui(11, lang: lang)).kLineHeight(1.4, size: 11, lang: lang)
                .foregroundStyle(C.text3).multilineTextAlignment(.center)
            HStack(spacing: 14) {
                link(d("Satın alımları geri yükle")) { Task { await restore() } }
                link(d("Koşullar")) { openLegal("terms") }
                link(d("Gizlilik")) { openLegal("privacy") }
            }
            RedeemCodeView()
            Button(action: close) {
                Text(d("Ücretsiz planla devam et")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(C.priText).frame(minHeight: 36)
            }
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
        .background(C.bg)
        .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
    }

    /// Public web pages (draft texts, lawyer check pending) in the app language: `/terms`, `/privacy`.
    private func openLegal(_ page: String) {
        if let url = URL(string: "\(Config.webBaseURL)/\(page)?lang=\(lang.rawValue)") { openURL(url) }
    }

    private func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(KFont.ui(12, lang: lang)).underline().foregroundStyle(C.text2).frame(minHeight: 32)
        }
        .disabled(busy)
    }

    private func buy() async {
        guard let p = products.first(where: { $0.id == selected }) else { return }
        busy = true
        defer { busy = false }
        switch await StoreAPI.buy(p) {
        case .premium:
            await trial.refresh()
            toast.show(t("pwDone"))
            app.back()
        case .pending: toast.show(t("pwPending"))
        case .cancelled: break
        case .failed: toast.show(t("pwFailed"))
        }
    }

    private func restore() async {
        busy = true
        defer { busy = false }
        switch await StoreAPI.restore() {
        case .some(true):
            await trial.refresh()
            toast.show(t("pwRestored"))
        case .some(false): toast.show(d("Bu hesapta önceki satın alım bulunamadı"))
        case .none: toast.show(t("pwNoStore"))
        }
    }
}
