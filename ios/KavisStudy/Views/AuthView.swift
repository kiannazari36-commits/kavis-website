import SwiftUI

/// Design: design/NewSignup.dc.html (sign up, log in and the 6-digit email code), flow as in web/src/pages/Login.tsx.
struct AuthView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast
    @Environment(\.colorScheme) private var scheme

    private enum Mode { case signup, login, verify }
    private enum Field { case name, email, password }

    @State private var mode: Mode
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var consent = false
    @State private var busy = false
    @State private var pending = (email: "", name: "")
    @FocusState private var focus: Field?

    var onBack: () -> Void

    init(start: AuthMode, onBack: @escaping () -> Void) {
        _mode = State(initialValue: start == .login ? .login : .signup)
        self.onBack = onBack
        // Test switch: `-kavis.route verify` opens the code screen directly.
        if MockFlag.value("route") == "verify" {
            _mode = State(initialValue: .verify)
            _pending = State(initialValue: ("elif@ogrenci.edu.tr", "Elif Yıldız"))
        }
    }

    private var lang: Lang { prefs.lang }
    private func t(_ key: String) -> String { prefs.t(key) }
    private var signup: Bool { mode == .signup }

    var body: some View {
        VStack(spacing: 0) {
            header
            if mode == .verify {
                VerifyView(email: pending.email, name: pending.name, busy: $busy, onSignedIn: finish)
            } else {
                form
                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    // MARK: Background, header

    private var background: some View {
        ZStack {
            KPhone.authBg
            if scheme == .dark {
                RadialGradient(colors: [KPhone.authTop, .clear], center: .top, startRadius: 0, endRadius: 520)
            } else {
                LinearGradient(colors: [KPhone.authTop, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                if mode == .verify { mode = .signup } else { onBack() }
            } label: {
                KIcon(name: .back, size: 20, width: 1.8, flipsInRTL: true)
                    .foregroundStyle(KPhone.text)
                    .frame(width: 46, height: 46)
                    .background(KPhone.card, in: Circle())
                    .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
            }
            .accessibilityLabel(t("signup.k1052"))
            Spacer()
            HStack(spacing: 7) {
                Image("BrandIcon").resizable().frame(width: 26, height: 26)
                Wordmark(size: 17)
            }
            Spacer()
            Color.clear.frame(width: 46, height: 46)
        }
        .padding(.horizontal, 20)
        .padding(.top, KLayout.top(60, minimum: 6))
    }

    // MARK: Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                tabs
                (Text("\(t(signup ? "signup.titleUp1" : "signup.titleIn1")) ").foregroundStyle(KPhone.text).font(KFont.ui(32, .medium, lang: lang))
                    + Text(t(signup ? "signup.titleUp2" : "signup.titleIn2")).foregroundStyle(KPhone.text3).font(KFont.ui(32, .regular, lang: lang)))
                    .kTracking(-0.03, size: 32, lang: lang)
                    .padding(.top, 4)

                VStack(spacing: 10) {
                    socialButton(provider: .apple)
                    socialButton(provider: .google)
                }

                HStack(spacing: 12) {
                    Rectangle().fill(KPhone.line).frame(height: 1)
                    Text(t("signup.k2437")).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text3)
                    Rectangle().fill(KPhone.line).frame(height: 1)
                }

                VStack(spacing: 10) {
                    if signup {
                        field(label: t("signup.k324"), focused: focus == .name) {
                            TextField("", text: $name, prompt: Text("Elif Yıldız").foregroundStyle(KPhone.text3))
                                .textContentType(.name)
                                .focused($focus, equals: .name)
                        }
                    }
                    field(label: t("signup.k876"), focused: focus == .email) {
                        TextField("", text: $email, prompt: Text("elif@ogrenci.edu.tr").foregroundStyle(KPhone.text3))
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focus, equals: .email)
                    }
                    field(label: t("signup.k2622"), focused: focus == .password, trailing: eyeButton) {
                        Group {
                            if showPassword {
                                TextField("", text: $password, prompt: Text("••••••••••").foregroundStyle(KPhone.text3))
                            } else {
                                SecureField("", text: $password, prompt: Text("••••••••••").foregroundStyle(KPhone.text3))
                            }
                        }
                        .textContentType(signup ? .newPassword : .password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .password)
                    }
                    if signup, !password.isEmpty { strength }
                    if !signup {
                        Button { toast.show(t("k165")) } label: {
                            Text(t("signup.k2625")).font(KFont.ui(13, .medium, lang: lang)).foregroundStyle(KPhone.brand)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 6)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 8)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach([Mode.signup, Mode.login], id: \.self) { m in
                let on = mode == m
                Button { mode = m } label: {
                    Text(t(m == .signup ? "signup.tabSignup" : "signup.tabLogin"))
                        .font(KFont.ui(15, on ? .semibold : .regular, lang: lang))
                        .foregroundStyle(on ? KPhone.text : KPhone.text2)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(on ? KPhone.card : .clear, in: Capsule())
                        .shadow(color: on ? Color(hex: 0x2A2420, opacity: 0.12) : .clear, radius: 2, y: 1)
                }
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(KPhone.seg, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(t("signup.k1173"))
    }

    private func socialButton(provider: AuthProvider) -> some View {
        let apple = provider == .apple
        let label = t(apple ? (signup ? "signup.appleUp" : "signup.appleIn") : (signup ? "signup.googleUp" : "signup.googleIn"))
        return Button { Task { await social(provider) } } label: {
            HStack(spacing: 10) {
                if apple { KIcon(name: .apple, size: 20) } else { GoogleLogo(size: 18) }
                Text(label).font(KFont.ui(15, .medium, lang: lang))
            }
            .foregroundStyle(apple ? KPhone.appleText : KPhone.text)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(apple ? KPhone.apple : KPhone.card, in: Capsule())
            .overlay(Capsule().stroke(apple ? .clear : KPhone.line, lineWidth: 1))
        }
        .disabled(busy)
    }

    /// Label above a pill-shaped input; the border turns to the focus color while typing.
    private func field<Content: View>(label: String, focused: Bool, trailing: AnyView? = nil,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(KFont.ui(13, lang: lang)).foregroundStyle(KPhone.text2).padding(.leading, 6)
            HStack(spacing: 8) {
                content()
                    .font(KFont.ui(16, lang: lang))
                    .foregroundStyle(KPhone.text)
                    .environment(\.layoutDirection, .leftToRight)
                    .multilineTextAlignment(lang.isRTL ? .trailing : .leading)
                if let trailing { trailing }
            }
            .padding(.leading, 20)
            .padding(.trailing, trailing == nil ? 20 : 6)
            .frame(height: 54)
            .background(KPhone.card, in: Capsule())
            .overlay(Capsule().stroke(focused ? KPhone.focus : KPhone.line, lineWidth: focused ? 1.5 : 1))
        }
    }

    private var eyeButton: AnyView {
        AnyView(
            Button { showPassword.toggle() } label: {
                KIcon(name: showPassword ? .eye : .eyeOff, size: 20, width: 1.6)
                    .foregroundStyle(KPhone.text2)
                    .frame(width: 42, height: 42)
            }
            .accessibilityLabel(t(showPassword ? "signup.hidePw" : "signup.showPw"))
        )
    }

    private var strength: some View {
        let score = Self.passwordScore(password)
        return HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(1...4, id: \.self) { i in
                    Capsule().fill(i <= score ? (score >= 3 ? KPhone.good : KColor.amb) : KPhone.seg).frame(height: 5)
                }
            }
            if score >= 3 {
                Text(t("signup.k1104")).font(KFont.ui(12, .medium, lang: lang)).foregroundStyle(KPhone.good)
            }
        }
        .padding(.horizontal, 6)
    }

    /// 0–4 bars: length, mixed case, digit, symbol (same as the web).
    static func passwordScore(_ pw: String) -> Int {
        guard !pw.isEmpty else { return 0 }
        var n = pw.count >= 8 ? 1 : 0
        if pw.contains(where: \.isLowercase), pw.contains(where: \.isUppercase) { n += 1 }
        if pw.contains(where: \.isNumber) { n += 1 }
        if pw.contains(where: { !$0.isLetter && !$0.isNumber }) { n += 1 }
        return max(n, 1)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            if signup {
                Button { consent.toggle() } label: {
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle().fill(consent ? KPhone.cta : .clear)
                            Circle().stroke(consent ? .clear : KPhone.text3, lineWidth: 1.5)
                            if consent { KIcon(name: .check, size: 13, width: 3).foregroundStyle(KPhone.ctaText) }
                        }
                        .frame(width: 22, height: 22)
                        consentText
                            .font(KFont.ui(12, lang: lang))
                            .kLineHeight(1.5, size: 12, lang: lang)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 4)
                }
                .accessibilityAddTraits(consent ? [.isSelected] : [])
            }
            Button { Task { await submit() } } label: {
                let blocked = signup && !consent
                Text(t(signup ? "signup.createAccount" : "signup.login"))
                    .font(KFont.ui(17, .medium, lang: lang))
                    .foregroundStyle(blocked ? KPhone.text3 : KPhone.ctaText)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(blocked ? KPhone.seg : KPhone.cta, in: Capsule())
                    .shadow(color: blocked ? .clear : Color(hex: 0x9C2F3A, opacity: 0.28), radius: 15, y: 12)
            }
            .disabled(busy)
            Button { mode = signup ? .login : .signup } label: {
                (Text("\(t(signup ? "signup.haveAccount" : "signup.noAccount")) ").foregroundStyle(KPhone.text2)
                    + Text(t(signup ? "signup.login" : "signup.signup")).fontWeight(.semibold).foregroundStyle(KPhone.text))
                    .font(KFont.ui(13, lang: lang))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) { Rectangle().fill(KPhone.line).frame(height: 1) }
    }

    private var consentText: Text {
        let strong = { (key: String) in Text(t(key)).fontWeight(.medium).foregroundStyle(KPhone.text) }
        let plain = { (key: String) in Text(t(key)).foregroundStyle(KPhone.text2) }
        return strong("signup.k1372") + Text(" ") + plain("signup.k2434") + Text(" ") + strong("signup.k1297") + Text(" ") + plain("signup.k2389")
    }

    // MARK: Actions

    private func submit() async {
        guard !busy else { return }
        if signup && !consent {
            toast.show(t("signup.needConsent"))
            return
        }
        busy = true
        if signup {
            let r = await AuthAPI.signUp(name: name, email: email, password: password)
            pending = (r.pendingEmail, r.name)
            busy = false
            mode = .verify
        } else {
            await finish(await AuthAPI.logIn(email: email, password: password))
        }
    }

    private func social(_ provider: AuthProvider) async {
        guard !busy else { return }
        busy = true
        await finish(await AuthAPI.socialLogIn(provider))
    }

    /// After a login: an account that is already on 2 devices must sign one out first (screen comes in step 4).
    private func finish(_ user: User) async {
        if await DevicesAPI.checkDeviceLimit() != nil {
            busy = false
            toast.show(t("devFullTitle"))
            return
        }
        busy = false
        app.signedIn(user)
    }
}

// MARK: - Email code

private struct VerifyView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(ToastCenter.self) private var toast

    let email: String
    let name: String
    @Binding var busy: Bool
    var onSignedIn: (User) async -> Void

    @State private var code = ""
    @State private var left = 42
    @FocusState private var focused: Bool

    /// Mock server: this is the code of every account (the web does the same).
    private let demoCode = "481920"

    private var lang: Lang { prefs.lang }
    private func t(_ key: String) -> String { prefs.t(key) }
    private var filled: Bool { code.count == 6 }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image("BrandIcon")
                    .resizable()
                    .frame(width: 96, height: 96)
                    .shadow(color: Color(hex: 0x5E1A22, opacity: 0.3), radius: 15, y: 16)
                    .padding(.top, 16)
                    .accessibilityHidden(true)
                (Text("\(t("signup.p0a")) ").foregroundStyle(KPhone.text).font(KFont.ui(30, .medium, lang: lang))
                    + Text(t("signup.p0b")).foregroundStyle(KPhone.text3).font(KFont.ui(30, .regular, lang: lang)))
                    .kTracking(-0.03, size: 30, lang: lang)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 26)
                (Text("\(t("signup.k257")) ") + Text(email).fontWeight(.semibold).foregroundStyle(KPhone.text) + Text(" \(t("signup.k2343"))"))
                    .font(KFont.ui(14, lang: lang))
                    .foregroundStyle(KPhone.text2)
                    .kLineHeight(1.55, size: 14, lang: lang)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                codeBoxes.padding(.top, 10)
                Button { code = demoCode } label: {
                    Text(t("signup.k1356")).font(KFont.ui(13, .medium, lang: lang)).foregroundStyle(KPhone.brand)
                }
                Button {
                    guard left == 0 else { return }
                    Task { _ = await AuthAPI.resendCode(email: email); left = 42 }
                } label: {
                    HStack(spacing: 4) {
                        Text(t("signup.k1354"))
                        if left > 0 { Text("0:\(String(format: "%02d", left))").font(KFont.mono(13, .regular)) }
                    }
                    .font(KFont.ui(13, lang: lang))
                    .foregroundStyle(left == 0 ? KPhone.brand : KPhone.text3)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        // The button stays right above the keyboard.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button { Task { await verify() } } label: {
                Text(t("signup.k864"))
                    .font(KFont.ui(17, .medium, lang: lang))
                    .foregroundStyle(filled ? KPhone.ctaText : KPhone.text3)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(filled ? KPhone.cta : KPhone.seg, in: Capsule())
                    .shadow(color: filled ? Color(hex: 0x9C2F3A, opacity: 0.28) : .clear, radius: 15, y: 12)
            }
            .disabled(busy)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .task { focused = true }
        .task(id: left) {
            guard left > 0 else { return }
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled { left -= 1 }
        }
    }

    private var codeBoxes: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    let digit = i < code.count ? String(Array(code)[i]) : ""
                    let active = i < code.count || i == code.count
                    Text(digit)
                        .font(KFont.mono(24, .semibold))
                        .foregroundStyle(KPhone.text)
                        .frame(width: 46, height: 58)
                        .background(KPhone.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(active ? KPhone.focus : KPhone.line, lineWidth: active ? 1.5 : 1)
                        )
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .onTapGesture { focused = true }
            // The real input is invisible; the boxes above show what is typed.
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.01)
                .allowsHitTesting(false)
                .onChange(of: code) { _, new in
                    let digits = String(new.filter(\.isNumber).prefix(6))
                    if digits != new { code = digits }
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(t("signup.k257"))
    }

    private func verify() async {
        guard filled else {
            toast.show(t("signup.needCode"))
            return
        }
        busy = true
        do {
            await onSignedIn(try await AuthAPI.verifyEmail(email: email, name: name, code: code))
        } catch {
            busy = false
            toast.show(t("signup.needCode"))
        }
    }
}
