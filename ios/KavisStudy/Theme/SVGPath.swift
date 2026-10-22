import SwiftUI

/// Reads SVG path data (the `d="…"` of a `<path>`) so the icons of the design can be used as they are.
/// Supports M L H V C S Q T A Z (upper and lower case), implicit repeats and compact numbers like `.5.5` or `0-18`.
enum SVGPathParser {
    static func parse(_ d: String) -> Path {
        var reader = Reader(Array(d))
        var path = Path()
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastCubic: CGPoint?
        var lastQuad: CGPoint?
        var command: Character = "M"

        while true {
            reader.skipSeparators()
            guard let next = reader.peek else { break }
            if next.isLetter { command = next; reader.advance() }
            else if reader.isFirstCommand { return path }
            let rel = command.isLowercase
            var cubic: CGPoint?
            var quad: CGPoint?

            func point() -> CGPoint? {
                guard let x = reader.number(), let y = reader.number() else { return nil }
                return rel ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            }

            switch command.uppercased() {
            case "M":
                guard let p = point() else { return path }
                path.move(to: p); current = p; start = p
                command = rel ? "l" : "L" // more pairs after M are lines
            case "L":
                guard let p = point() else { return path }
                path.addLine(to: p); current = p
            case "H":
                guard let x = reader.number() else { return path }
                current = CGPoint(x: rel ? current.x + x : x, y: current.y); path.addLine(to: current)
            case "V":
                guard let y = reader.number() else { return path }
                current = CGPoint(x: current.x, y: rel ? current.y + y : y); path.addLine(to: current)
            case "C":
                guard let c1 = point(), let c2 = point(), let p = point() else { return path }
                path.addCurve(to: p, control1: c1, control2: c2); current = p; cubic = c2
            case "S":
                let c1 = lastCubic.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                guard let c2 = point(), let p = point() else { return path }
                path.addCurve(to: p, control1: c1, control2: c2); current = p; cubic = c2
            case "Q":
                guard let c = point(), let p = point() else { return path }
                path.addQuadCurve(to: p, control: c); current = p; quad = c
            case "T":
                let c = lastQuad.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                guard let p = point() else { return path }
                path.addQuadCurve(to: p, control: c); current = p; quad = c
            case "A":
                guard let rx = reader.number(), let ry = reader.number(), let rot = reader.number(),
                      let large = reader.flag(), let sweep = reader.flag(), let p = point() else { return path }
                addArc(&path, from: current, rx: rx, ry: ry, rotation: rot, large: large, sweep: sweep, to: p)
                current = p
            case "Z":
                path.closeSubpath(); current = start
                if let n = reader.peek, !n.isLetter, n != " ", n != "," { return path } // stray numbers after Z
            default:
                return path
            }
            lastCubic = cubic
            lastQuad = quad
        }
        return path
    }

    /// SVG arc (endpoint form) -> cubic curves, following the SVG 1.1 implementation notes F.6.5.
    private static func addArc(_ path: inout Path, from p0: CGPoint, rx rxIn: CGFloat, ry ryIn: CGFloat,
                               rotation: CGFloat, large: Bool, sweep: Bool, to p1: CGPoint) {
        var rx = abs(rxIn), ry = abs(ryIn)
        if rx == 0 || ry == 0 || p0 == p1 { path.addLine(to: p1); return }
        let phi = rotation * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cosPhi * dx + sinPhi * dy
        let y1 = -sinPhi * dx + cosPhi * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 { let s = lambda.squareRoot(); rx *= s; ry *= s }
        let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var coef = max(0, numerator / denominator).squareRoot()
        if large == sweep { coef = -coef }
        let cxp = coef * rx * y1 / ry
        let cyp = -coef * ry * x1 / rx
        let cx = cosPhi * cxp - sinPhi * cyp + (p0.x + p1.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p0.y + p1.y) / 2
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat { atan2(ux * vy - uy * vx, ux * vx + uy * vy) }
        let theta = angle(1, 0, (x1 - cxp) / rx, (y1 - cyp) / ry)
        var delta = angle((x1 - cxp) / rx, (y1 - cyp) / ry, (-x1 - cxp) / rx, (-y1 - cyp) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi } else if sweep && delta < 0 { delta += 2 * .pi }

        let segments = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / CGFloat(segments)
        let k = 4 / 3 * tan(step / 4)
        func map(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: cosPhi * rx * x - sinPhi * ry * y + cx, y: sinPhi * rx * x + cosPhi * ry * y + cy)
        }
        var t = theta
        for _ in 0..<segments {
            let c1 = cos(t), s1 = sin(t), c2 = cos(t + step), s2 = sin(t + step)
            path.addCurve(to: map(c2, s2), control1: map(c1 - k * s1, s1 + k * c1), control2: map(c2 + k * s2, s2 - k * c2))
            t += step
        }
    }

    private struct Reader {
        let chars: [Character]
        var i = 0
        var started = false

        init(_ chars: [Character]) { self.chars = chars }

        var peek: Character? { i < chars.count ? chars[i] : nil }
        /// True when the data does not start with a command letter.
        var isFirstCommand: Bool { !started }
        mutating func advance() { i += 1; started = true }

        mutating func skipSeparators() {
            while let c = peek, c == " " || c == "," || c == "\n" || c == "\t" { i += 1 }
        }

        /// Arc flags are a single 0 or 1 and may be written without a separator.
        mutating func flag() -> Bool? {
            skipSeparators()
            guard let c = peek, c == "0" || c == "1" else { return nil }
            i += 1
            return c == "1"
        }

        mutating func number() -> CGFloat? {
            skipSeparators()
            let begin = i
            if let c = peek, c == "+" || c == "-" { i += 1 }
            var dot = false
            while let c = peek {
                if c.isNumber { i += 1 }
                else if c == "." && !dot { dot = true; i += 1 }
                else { break }
            }
            if let c = peek, c == "e" || c == "E" {
                i += 1
                if let s = peek, s == "+" || s == "-" { i += 1 }
                while let d = peek, d.isNumber { i += 1 }
            }
            guard i > begin, let v = Double(String(chars[begin..<i])) else { i = begin; return nil }
            started = true
            return CGFloat(v)
        }
    }
}

/// An SVG path drawn into a square, with the design's 24 × 24 coordinates.
struct SVGShape: Shape {
    let d: String
    var viewBox: CGFloat = 24
    /// Draw the path mirrored left to right (arrows and chevrons in right-to-left languages).
    var mirrored = false

    /// SwiftUI mirrors shapes in right-to-left layouts by itself. The design only mirrors arrows and chevrons
    /// (`mirrored`), so every other icon (file, camera, Apple logo…) must keep its shape.
    var layoutDirectionBehavior: LayoutDirectionBehavior { .fixed }

    func path(in rect: CGRect) -> Path {
        let scale = CGAffineTransform(scaleX: rect.width / viewBox, y: rect.height / viewBox)
        let path = SVGPathParser.parse(d).applying(scale)
        guard mirrored else { return path }
        return path.applying(CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -rect.width, y: 0))
    }
}
