import SwiftUI

/// Shown after a login (or at start) on a 3rd device (CLAUDE.md: max 2 devices, the web counts as one). The student
/// signs one of the other devices out, then this phone is registered (RPC register_device) and the app goes on.
/// Same screen as the web's /devices.
struct DeviceLimitView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast

    @State private var devices: [Device] = []
    @State private var busy = false

    private var lang: Lang { prefs.lang }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                KIcon(name: .person, size: 26, width: 1.6)
                    .foregroundStyle(KPhone.brand)
                    .frame(width: 60, height: 60)
                    .background(KPhone.card, in: Circle())
                    .overlay(Circle().stroke(KPhone.line, lineWidth: 1))
                    .padding(.top, KLayout.top(110, minimum: 24))
                Text(prefs.t("devFullTitle"))
                    .font(KFont.ui(24, .semibold, lang: lang))
                    .kTracking(-0.02, size: 24, lang: lang)
                    .foregroundStyle(KPhone.text)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(prefs.t("devFullSub"))
                    .font(KFont.ui(14, lang: lang))
                    .foregroundStyle(KPhone.text2)
                    .multilineTextAlignment(.center)
                VStack(spacing: 0) {
                    ForEach(Array(devices.enumerated()), id: \.element.id) { i, device in
                        if i > 0 { Rectangle().fill(KPhone.line).frame(height: 1) }
                        row(device)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 4)
                .kPhoneCard()
                .padding(.top, 8)
                Text(prefs.t("devHint"))
                    .font(KFont.ui(12, lang: lang))
                    .kLineHeight(1.4, size: 12, lang: lang)
                    .foregroundStyle(KPhone.text3)
                    .multilineTextAlignment(.center)
                Button { Task { await app.signOut() } } label: {
                    Text(prefs.t("logout"))
                        .font(KFont.ui(15, .medium, lang: lang))
                        .foregroundStyle(KPhone.brand)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24).padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KPhone.authBg.ignoresSafeArea())
        .task { if devices.isEmpty { devices = app.limitDevices } }
    }

    private func row(_ device: Device) -> some View {
        HStack(spacing: 12) {
            KIcon(name: device.kind == .web || device.kind == .mac ? .globe : .person, size: 18, width: 1.7)
                .foregroundStyle(KPhone.brand)
                .frame(width: 38, height: 38)
                .background(KPhone.tile1, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text)
                if let seen = device.lastUsed {
                    Text(prefs.t("devLastUsed", ["t": Format.lastSeen(seen, lang)])).font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { Task { await signOut(device) } } label: {
                Text(prefs.t("devSignOut"))
                    .font(KFont.ui(12, .medium, lang: lang)).foregroundStyle(KPhone.brand)
                    .padding(.horizontal, 12).frame(height: 34)
                    .overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(busy)
        }
        .frame(minHeight: 64)
    }

    /// Signs the chosen device out, registers this phone, and goes on.
    private func signOut(_ device: Device) async {
        busy = true
        defer { busy = false }
        guard await DevicesAPI.signOutDevice(id: device.id) else { return toast.show(prefs.t("delFailed")) }
        toast.show(prefs.t("devSignedOut", ["name": device.name]))
        if let others = await DevicesAPI.checkDeviceLimit() {
            devices = others
        } else {
            await app.continueAfterDeviceLimit()
        }
    }
}
