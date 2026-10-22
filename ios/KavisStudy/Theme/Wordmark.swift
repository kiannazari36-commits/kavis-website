import SwiftUI

/// "KAVIS / STUDY" logotype of the design: A and I in the brand color, a small star above the I.
/// `size` is the design's font size for the whole block (KAVIS is 1.15 em, STUDY .63 em).
struct Wordmark: View {
    var size: CGFloat = 20

    var body: some View {
        let big = size * 1.15
        VStack(spacing: size * 0.14) {
            HStack(spacing: 0) {
                Text("K").foregroundStyle(KColor.text)
                Text("A").foregroundStyle(KColor.pb)
                Text("V").foregroundStyle(KColor.text)
                Text("I").foregroundStyle(KColor.pb)
                    .overlay(alignment: .top) {
                        KIcon(name: .star, size: big * 0.34)
                            .foregroundStyle(KColor.pb)
                            .offset(y: -big * 0.34)
                    }
                Text("S").foregroundStyle(KColor.text)
            }
            .font(KFont.ui(big, .bold, lang: .en))
            .tracking(big * 0.01)
            Text("STUDY")
                .font(KFont.ui(size * 0.63, .medium, lang: .en))
                .tracking(size * 0.63 * 0.1)
                .foregroundStyle(KColor.text.opacity(0.7))
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kavis Study")
    }
}
