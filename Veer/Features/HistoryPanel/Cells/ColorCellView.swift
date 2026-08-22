import AppKit
import SwiftUI

struct ColorCellView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    /// Off → no swatch or decoding; a plain icon + label row.
    var previewsEnabled: Bool = true
    let blobProvider: () -> Data?
    /// Hex color text for text clips that are exactly a hex string;
    /// takes precedence over the pasteboard blob.
    var hexColorFallback: String?

    @State private var color: NSColor?
    @State private var hex: String?
    @State private var loaded = false

    var body: some View {
        CellChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.veerColorCellView) {
            HStack(spacing: 10) {
                if previewsEnabled {
                    swatch
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "paintpalette")
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(previewsEnabled
                         ? (loaded ? (hex ?? "Unknown color") : "color")
                         : "Color")
                        .font(previewsEnabled
                              ? .system(.body, design: .monospaced)
                              : .system(size: 13, weight: .medium))
                        .lineLimit(1)
                    metadataLine
                }
                Spacer(minLength: 0)
            }
        }
        .task(id: "\(snapshot.id.uuidString)-\(previewsEnabled)") {
            guard previewsEnabled else { return }
            loadColor()
        }
    }

    private var metadataLine: some View {
        HStack(spacing: 6) {
            if let bundle = snapshot.sourceBundleId {
                Text(bundle)
            }
            Text(snapshot.relativeTimeLabel)
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
    }

    /// Swatch with a visible edge (and a checkerboard behind translucent
    /// colors) so it never blends into the row background.
    @ViewBuilder
    private var swatch: some View {
        ZStack {
            if let color {
                if color.alphaComponent < 1 {
                    ColorContrastCheckerboard()
                }
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: color))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func loadColor() {
        if let hexColorFallback, let nsColor = NSColor.fromHexString(hexColorFallback) {
            color = nsColor
            hex = Self.hexString(for: nsColor)
            loaded = true
            return
        }
        if let data = blobProvider(),
           let nsColor = NSColor.decodePasteboardColor(from: data)
        {
            color = nsColor
            hex = Self.hexString(for: nsColor)
            loaded = true
            return
        }
        loaded = true
    }

    static func hexString(for color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else { return "color" }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
