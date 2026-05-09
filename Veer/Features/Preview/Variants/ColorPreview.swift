import AppKit
import SwiftUI

struct ColorPreview: View {
    let data: Data?

    var body: some View {
        let color = decodedColor()
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.map { Color(nsColor: $0) } ?? Color.gray)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            VStack(spacing: 6) {
                if let color {
                    Text(ColorCellView.hexString(for: color))
                        .font(.system(.title3, design: .monospaced))
                    if let rgb = color.usingColorSpace(.sRGB) {
                        Text(String(
                            format: "RGB %.0f, %.0f, %.0f  ·  Alpha %.2f",
                            rgb.redComponent * 255,
                            rgb.greenComponent * 255,
                            rgb.blueComponent * 255,
                            rgb.alphaComponent
                        ))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Unable to decode color")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
    }

    private func decodedColor() -> NSColor? {
        guard let data else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    }
}
