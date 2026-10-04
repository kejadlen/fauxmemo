import FauxmemoKit
import SwiftUI

struct TextPrintView: View {
    @State private var text = ""
    @State private var bitmap: Bitmap?
    @AppStorage("textFont") private var font: TextFont = .standard
    @AppStorage("textSize") private var size: TextSize = .medium
    @AppStorage("textBold") private var bold = true
    @FocusState private var editing: Bool

    private struct RenderKey: Hashable {
        let text: String
        let font: TextFont
        let size: TextSize
        let bold: Bool
    }

    var body: some View {
        VStack(spacing: 16) {
            TextEditor(text: $text)
                .focused($editing)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(height: 140)
                .background(Palette.surface, in: .rect(cornerRadius: 16))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Type something to print")
                            .foregroundStyle(Palette.muted)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line)
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
        .task(id: RenderKey(text: text, font: font, size: size, bold: bold)) {
            bitmap = render()
        }
    }

    private func render() -> Bitmap? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let width = CGFloat(PhomemoEncoder.printWidth)
        let content = Text(text)
            .font(.system(size: size.points, weight: bold ? .bold : .regular, design: font.design))
            .foregroundStyle(Color.black)
            .frame(width: width, alignment: .leading)
            .background(Color.white)
        return GrayImage(rendering: content, width: width).map { Dither.threshold.apply(to: $0) }
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
