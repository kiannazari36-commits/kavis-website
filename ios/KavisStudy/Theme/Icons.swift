import SwiftUI

/// Line icons of the design (24 × 24, round caps). Paths are copied from the design files / web/src/components/Icon.tsx.
enum KIconName: String {
    case lock = "M6 11h12v9H6z M8 11V8a4 4 0 0 1 8 0v3"
    case upload = "M6 3h8l5 5v13H6z M14 3v5h5 M12 18v-6 M9.5 14.5L12 12l2.5 2.5"
    case list = "M9 6h11 M9 12h11 M9 18h11 M4 6h.01 M4 12h.01 M4 18h.01"
    case checklist = "M9 5h10 M9 12h10 M9 19h10 M4 5l1 1 2-2 M4 12l1 1 2-2 M4 19h.01"
    case cards = "M5 7h11a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2z M7 3.5h12a2 2 0 0 1 2 2V17"
    case mic = "M12 3a3 3 0 0 1 3 3v5a3 3 0 0 1-6 0V6a3 3 0 0 1 3-3z M5 11a7 7 0 0 0 14 0 M12 18v3"
    case back = "M19 12H5 M11 6l-6 6 6 6"
    case check = "M5 12l5 5 9-10"
    case mail = "M3 6h18v12H3z M3 7l9 6 9-6"
    case eye = "M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z"
    case eyeOff = "M3 3l18 18 M10.6 5.1A10 10 0 0 1 12 5c6.5 0 10 7 10 7a17 17 0 0 1-3 3.9 M6.6 6.6C3.7 8.4 2 12 2 12s3.5 7 10 7a9.6 9.6 0 0 0 5.4-1.6 M9.9 9.9a3 3 0 0 0 4.2 4.2"
    case book = "M3 5.5c2.5-1 5.5-1 9 1v13c-3.5-2-6.5-2-9-1z M21 5.5c-2.5-1-5.5-1-9 1v13c3.5-2 6.5-2 9-1z"
    case bell = "M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15z M10 21h4"
    case refresh = "M20 12a8 8 0 1 1-2.3-5.7 M20 4v5h-5"
    case play = "M8 5v14l11-7z"
    case camera = "M4 8h3l2-3h6l2 3h3v11H4z M12 17a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z"
    case help = "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6v.6 M12 17h.01"
    case chevron = "M9 6l6 6-6 6"
    case chevronDown = "M6 9l6 6 6-6"
    case chevronLeft = "M15 6l-6 6 6 6"
    case arrowRight = "M9 5l7 7-7 7"
    case wifiOff = "M3 3l18 18 M5 9.5a14 14 0 0 1 4-2.6 M19 9.5a14 14 0 0 0-6.5-3.2 M8.5 13a7 7 0 0 1 3-1.5 M12 18h.01"
    case sync = "M4 12a8 8 0 0 1 14-5.3L20 9 M20 4v5h-5 M20 12a8 8 0 0 1-14 5.3L4 15 M4 20v-5h5"
    case syncHalf = "M4 12a8 8 0 0 1 14-5.3L20 9 M20 4v5h-5"
    case flask = "M9 3h6 M10 3v6L4.5 19a1.5 1.5 0 0 0 1.3 2h12.4a1.5 1.5 0 0 0 1.3-2L14 9V3 M7 15h10"
    case stethoscope = "M5 3H4v6a5 5 0 0 0 10 0V3h-1 M9 14v1a5 5 0 0 0 10 0v-3 M19 8a2 2 0 1 1 0 4 2 2 0 0 1 0-4z"
    case tooth = "M7 3c-2.5 0-4 2-4 4.5 0 3 1.5 4.5 2 7 .5 3 1 6.5 2.5 6.5S9 16 12 16s3 5 4.5 5 2-3.5 2.5-6.5c.5-2.5 2-4 2-7C21 5 19.5 3 17 3c-2 0-3 1-5 1S9 3 7 3z"
    case cross = "M12 5v14 M5 12h14"
    case pulse = "M3 12h4l2-5 4 10 2-5h6"
    case dots = "M6 12h.01 M12 12h.01 M18 12h.01"
    case info = "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z M12 8h.01 M11 12h1v5h1"
    case shield = "M12 3l7 3v5c0 5-3 8.5-7 10-4-1.5-7-5-7-10V6z M9 12l2 2 4-4"
    case image = "M4 5h16v14H4z M4 16l5-5 4 4 3-3 4 4 M9 9h.01"
    case wave = "M4 12v.01 M8 8v8 M12 5v14 M16 9v6 M20 12v.01"
    case fileX = "M6 3h8l5 5v13H6z M14 3v5h5 M9.5 13.5l5 5 M14.5 13.5l-5 5"
    case audioFile = "M6 3h8l5 5v13H6z M14 3v5h5 M10 17v-3 M12 18v-5 M14 17v-3"
    case chat = "M4 5h16v11H9l-5 4z"
    case bellSmall = "M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z M10 20a2 2 0 0 0 4 0"
    case spark = "M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"
    case plus = "M12 6v12 M6 12h12"
    case minus = "M5 12h14"
    case person = "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M4 21a8 8 0 0 1 16 0"
    case folder = "M3 6.5A1.5 1.5 0 0 1 4.5 5H9l2 2.5h8.5A1.5 1.5 0 0 1 21 9v9.5a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 18.5z"
    case close = "M6 6l12 12 M18 6L6 18"
    case send = "M5 12h14 M13 6l6 6-6 6"
    case clock = "M12 7v5l3 2 M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z"
    case calendar = "M4 6h16v14H4z M4 10h16 M8 3v4 M16 3v4"
    case trash = "M4 7h16 M9 7V4h6v3 M6 7l1 13h10l1-13"
    case chart = "M4 20V11 M10 20V5 M16 20v-6 M21 20H3"
    case sliders = "M4 7h9 M17 7h3 M4 17h3 M11 17h9 M15 5v4 M9 15v4"
    case apple = "M16.4 12.6c0-2.4 2-3.5 2-3.6-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.8-3.5.8s-1.9-.8-3.1-.8C6.8 7.2 5.3 8.1 4.5 9.6c-1.7 2.9-.4 7.2 1.2 9.6.8 1.2 1.7 2.4 3 2.4 1.2-.1 1.6-.8 3.1-.8s1.8.8 3.1.8c1.3 0 2.1-1.2 2.9-2.3.9-1.3 1.3-2.6 1.3-2.7-.1 0-2.6-1-2.7-4zM14.1 5.5c.7-.8 1.1-1.9 1-3-1 0-2.1.7-2.8 1.5-.6.7-1.1 1.8-1 2.9 1 .1 2.1-.6 2.8-1.4z"
    case star = "M12 0 L14.6 9.4 L24 12 L14.6 14.6 L12 24 L9.4 14.6 L0 12 L9.4 9.4Z"

    /// Drawn as a filled shape instead of a line.
    var isFilled: Bool { self == .play || self == .apple || self == .star }
}

/// An icon in the current foreground color. `width` is the stroke width in the 24-unit box (design: 1.6–2).
struct KIcon: View {
    let name: KIconName
    var size: CGFloat = 20
    var width: CGFloat = 1.7
    /// Mirror in right-to-left languages (back arrows, chevrons).
    var flipsInRTL = false

    @Environment(\.layoutDirection) private var direction

    var body: some View {
        let mirrored = flipsInRTL && direction == .rightToLeft
        Group {
            if name.isFilled {
                SVGShape(d: name.rawValue, mirrored: mirrored).fill(style: FillStyle())
            } else {
                SVGShape(d: name.rawValue, mirrored: mirrored)
                    .stroke(style: StrokeStyle(lineWidth: width * size / 24, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Google "G" in its four brand colors (path data from design/NewSignup.dc.html).
struct GoogleLogo: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            SVGShape(d: "M22 12.2c0-.7-.1-1.4-.2-2H12v3.8h5.6a4.8 4.8 0 0 1-2.1 3.1v2.6h3.4c2-1.8 3.1-4.5 3.1-7.5z").fill(Color(hex: 0x4285F4))
            SVGShape(d: "M12 22c2.8 0 5.2-.9 6.9-2.5l-3.4-2.6c-.9.6-2.1 1-3.5 1-2.7 0-5-1.8-5.8-4.3H2.7v2.7A10 10 0 0 0 12 22z").fill(Color(hex: 0x34A853))
            SVGShape(d: "M6.2 13.6a6 6 0 0 1 0-3.8V7.1H2.7a10 10 0 0 0 0 9z").fill(Color(hex: 0xFBBC05))
            SVGShape(d: "M12 6c1.5 0 2.9.5 4 1.5l3-3A10 10 0 0 0 2.7 7.1l3.5 2.7C7 7.8 9.3 6 12 6z").fill(Color(hex: 0xEA4335))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
