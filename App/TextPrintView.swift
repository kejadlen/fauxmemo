import FauxmemoKit
import PhosphorSwift
import SwiftUI

struct TextPrintView: View {
    @State private var text = ""
    @State private var bitmap: Bitmap?
    @State private var icon: PrintIcon?
    @State private var pickingIcon = false
    @AppStorage("textFont") private var font: TextFont = .standard
    @AppStorage("textSize") private var size: TextSize = .medium
    @AppStorage("textBold") private var bold = true
    @AppStorage("dither") private var dither: Dither = .atkinson
    @FocusState private var editing: Bool

    private struct RenderKey: Hashable {
        let text: String
        let font: TextFont
        let size: TextSize
        let bold: Bool
        let icon: PrintIcon?
        let dither: Dither
    }

    /// Room between a leading icon and the text, in dots.
    private static let iconGap = 12

    private var glyphWeight: Ph.IconWeight { bold ? .bold : .regular }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                iconTile

                TextEditor(text: $text)
                    .focused($editing)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(height: 140)
                    .background(Palette.surface, in: .rect(cornerRadius: 16))
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Label")
                                .foregroundStyle(Palette.muted)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line)
                    }
            }

            Group {
                if bitmap != nil {
                    PaperPreview(bitmap: bitmap)
                } else {
                    Spacer()
                }
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 12) {
                Picker("Font", selection: $font) {
                    ForEach(TextFont.allCases) { font in
                        Text(font.name).tag(font)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    Picker("Size", selection: $size) {
                        ForEach(TextSize.allCases) { size in
                            Text(size.name).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(isOn: $bold) {
                        Image(systemName: "bold")
                    }
                    .toggleStyle(.button)
                    .accessibilityLabel("Bold")
                }

                if icon?.isEmoji == true {
                    DitherPicker(selection: $dither)
                }

                PrintButton(bitmap: bitmap)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Palette.ground)
        .navigationTitle("Text")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PrinterStatusChip()
            }
            ToolbarItem(placement: .keyboard) {
                Button("Done") { editing = false }
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .sheet(isPresented: $pickingIcon) {
            IconPickerSheet(weight: glyphWeight) { icon = $0 }
        }
        .task(id: RenderKey(text: text, font: font, size: size, bold: bold, icon: icon, dither: dither)) {
            bitmap = render()
        }
    }

    private var iconTile: some View {
        Button {
            pickingIcon = true
        } label: {
            Group {
                switch icon {
                case .glyph(let glyph):
                    glyph.weight(glyphWeight).frame(width: 32, height: 32)
                case .emoji(let emoji):
                    Text(emoji).font(.system(size: 32))
                case nil:
                    Image(systemName: "plus").foregroundStyle(Palette.muted)
                }
            }
            .frame(width: 64, height: 64)
            .foregroundStyle(Palette.ink)
            .background(Palette.surface, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 1, dash: icon == nil ? [4, 4] : []))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.map { "Icon: \($0.name)" } ?? "Add icon")
        .overlay(alignment: .topTrailing) {
            if icon != nil {
                Button("Remove icon", systemImage: "xmark") { icon = nil }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Palette.ink, in: .circle)
                    .offset(x: 6, y: -6)
            }
        }
    }

    private func render() -> Bitmap? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let printWidth = PhomemoEncoder.printWidth
        let iconSide = min(Int(size.points) * 2, 128)
        let textX = icon == nil ? 0 : iconSide + Self.iconGap
        let textWidth = CGFloat(printWidth - textX)
        let content = Text(text)
            .font(.system(size: size.points, weight: bold ? .bold : .regular, design: font.design))
            .foregroundStyle(Color.black)
            .frame(width: textWidth, alignment: .leading)
            .background(Color.white)
        guard let gray = GrayImage(rendering: content, width: textWidth) else { return nil }
        let textBitmap = Dither.threshold.apply(to: gray)
        guard let icon else { return textBitmap }

        // Center both on the taller one, like a label.
        let height = max(iconSide, textBitmap.height)
        var label = Bitmap(width: printWidth, height: height)
        if let iconBitmap = icon.bitmap(size: iconSide, weight: glyphWeight, dither: dither) {
            label.draw(iconBitmap, x: 0, y: (height - iconSide) / 2)
        }
        label.draw(textBitmap, x: textX, y: (height - textBitmap.height) / 2)
        return label
    }
}

private struct IconPickerSheet: View {
    let weight: Ph.IconWeight
    let pick: (PrintIcon) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            IconPicker(query: query, weight: weight) { icon in
                pick(icon)
                dismiss()
            }
            .padding(.horizontal, 20)
            .background(Palette.ground)
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search icons or type an emoji")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

enum TextFont: String, CaseIterable, Identifiable {
    case standard
    case rounded
    case serif
    case monospaced

    var id: Self { self }

    var name: String {
        switch self {
        case .standard: "Sans"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .monospaced: "Mono"
        }
    }

    var design: Font.Design {
        switch self {
        case .standard: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }
}

/// Sizes in points, which render one dot each: 8 dots is 1 mm.
enum TextSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case huge

    var id: Self { self }

    var name: String {
        switch self {
        case .small: "S"
        case .medium: "M"
        case .large: "L"
        case .huge: "XL"
        }
    }

    var points: CGFloat {
        switch self {
        case .small: 24
        case .medium: 40
        case .large: 64
        case .huge: 96
        }
    }
}
