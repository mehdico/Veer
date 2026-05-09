import AppKit
import SwiftUI

struct ColorCellView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    let blobProvider: () -> Data?

    @State private var color: NSColor?
    @State private var hex: String?

    var body: some View {
        CellChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.yippyColorCellView) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.map { Color(nsColor: $0) } ?? Color.gray)
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(hex ?? "color")
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                    if let bundle = snapshot.sourceBundleId {
                        Text(bundle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .task(id: snapshot.id) { loadColor() }
    }

    private func loadColor() {
        guard let data = blobProvider() else { return }
        if let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            color = nsColor
            hex = Self.hexString(for: nsColor)
        }
    }

    static func hexString(for color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else { return "color" }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
