import AppKit
import SwiftUI

extension NSColor {
    /// WCAG relative luminance of the color converted to sRGB, in 0…1.
    var relativeLuminance: CGFloat {
        guard let rgb = usingColorSpace(.sRGB) else { return 0.5 }
        func linear(_ component: CGFloat) -> CGFloat {
            component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.redComponent)
            + 0.7152 * linear(rgb.greenComponent)
            + 0.0722 * linear(rgb.blueComponent)
    }

    /// Black or white — whichever keeps text readable when placed over this color.
    var contrastingTextColor: Color {
        relativeLuminance < 0.5 ? .white : .black
    }

    /// Decodes pasteboard color data, retrying without secure coding for
    /// legacy archives written by third-party apps.
    static func decodePasteboardColor(from data: Data) -> NSColor? {
        if let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            return color
        }
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = false
        defer { unarchiver.finishDecoding() }
        return try? unarchiver.decodeTopLevelObject() as? NSColor
    }

    /// Creates a color from a hex string like `#RGB`, `#RRGGBB` or
    /// `#RRGGBBAA` (leading `#` optional).
    static func fromHexString(_ text: String) -> NSColor? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ClipContentDetector.detectHex(in: trimmed) != nil else { return nil }
        let core = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let expanded = core.count == 3 ? core.map { "\($0)\($0)" }.joined() : core
        var components: [CGFloat] = []
        for index in 0..<3 {
            let start = expanded.index(expanded.startIndex, offsetBy: index * 2)
            let end = expanded.index(start, offsetBy: 2)
            components.append(CGFloat(Int(expanded[start..<end], radix: 16) ?? 0) / 255)
        }
        var alpha: CGFloat = 1
        if expanded.count == 8 {
            let start = expanded.index(expanded.startIndex, offsetBy: 6)
            let end = expanded.index(start, offsetBy: 2)
            alpha = CGFloat(Int(expanded[start..<end], radix: 16) ?? 255) / 255
        }
        return NSColor(srgbRed: components[0], green: components[1], blue: components[2], alpha: alpha)
    }
}

/// Classic transparency checkerboard shown behind translucent color swatches.
struct ColorContrastCheckerboard: View {
    private let square: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var row = 0
            var y: CGFloat = 0
            while y < size.height {
                var column = 0
                var x: CGFloat = 0
                while x < size.width {
                    if (row + column).isMultiple(of: 2) {
                        let rect = CGRect(
                            x: x,
                            y: y,
                            width: min(square, size.width - x),
                            height: min(square, size.height - y)
                        )
                        context.fill(Path(rect), with: .color(Color(white: 0.82)))
                    }
                    x += square
                    column += 1
                }
                y += square
                row += 1
            }
        }
    }
}
