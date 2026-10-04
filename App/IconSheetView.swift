import FauxmemoKit
import PhosphorSwift
import SwiftUI

struct IconSheetView: View {
    @State private var selected: [PrintIcon] = []
    @State private var query = ""
    @State private var bitmap: Bitmap?
    @AppStorage("iconWeight") private var weight: Ph.IconWeight = .bold
    @AppStorage("iconsPerRow") private var perRow = 4
    @AppStorage("dither") private var dither: Dither = .atkinson

    /// Hairline weights break up on the print head, and duotone has no meaning in 1-bit.
    private static let weights: [Ph.IconWeight] = [.regular, .bold, .fill]

    private var layout: IconSheetLayout {
        IconSheetLayout(count: selected.count, perRow: perRow)
    }

    private struct RenderKey: Hashable {
        let icons: [PrintIcon]
        let weight: Ph.IconWeight
        let perRow: Int
        let dither: Dither
    }

    var body: some View {
        let counts = Dictionary(selected.map { ($0, 1) }, uniquingKeysWith: +)

        VStack(spacing: 14) {
            HStack {
                Picker("Weight", selection: $weight) {
                    ForEach(Self.weights) { weight in
                        Text(weight.rawValue.capitalized).tag(weight)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()

                Spacer()

                Picker("Icons per row", selection: $perRow) {
                    ForEach([3, 4, 5], id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            IconPicker(query: query, weight: weight, counts: counts) { icon in
                selected.append(icon)
            }
            .frame(maxHeight: .infinity)

            if !selected.isEmpty {
                ViewThatFits(in: .vertical) {
                    sheetPreview
                    ScrollView { sheetPreview }
                }
                .frame(maxHeight: 320)
            }

            if selected.contains(where: \.isEmoji) {
                DitherPicker(selection: $dither)
            }

            PrintButton(bitmap: selected.isEmpty ? nil : bitmap)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Palette.ground)
        .navigationTitle("Icon sheet")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search icons or type an emoji")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PrinterStatusChip()
            }
        }
        .task(id: RenderKey(icons: selected, weight: weight, perRow: perRow, dither: dither)) {
            bitmap = render()
        }
    }

    private var sheetPreview: some View {
        SheetPreview(bitmap: bitmap, icons: selected, layout: layout) { index in
            selected.remove(at: index)
        }
    }

    private func render() -> Bitmap? {
        guard !selected.isEmpty, let grid = GrayImage(rendering: SheetGrid(layout: layout)) else { return nil }
        var sheet = Dither.threshold.apply(to: grid)
        var rendered: [PrintIcon: Bitmap] = [:]
        for (index, icon) in selected.enumerated() {
            let cell = layout.cell(index)
            let inset = Int((Double(cell.size) * 0.18).rounded())
            guard let bitmap = rendered[icon] ?? icon.bitmap(size: cell.size - 2 * inset, weight: weight, dither: dither)
            else { continue }
            rendered[icon] = bitmap
            sheet.draw(bitmap, x: cell.x + inset, y: cell.y + inset)
        }
        return sheet
    }
}

/// The sheet's dashed cut lines, one dot per point. Icons are drawn in afterwards.
private struct SheetGrid: View {
    let layout: IconSheetLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            ForEach(Array(layout.cells.enumerated()), id: \.offset) { _, cell in
                Rectangle()
                    .strokeBorder(Color.black, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .frame(width: CGFloat(cell.size), height: CGFloat(cell.size))
                    .offset(x: CGFloat(cell.x), y: CGFloat(cell.y))
            }
        }
        .frame(width: CGFloat(layout.width), height: CGFloat(layout.height))
    }
}

/// The rendered sheet; tap an icon to take it off.
private struct SheetPreview: View {
    let bitmap: Bitmap?
    let icons: [PrintIcon]
    let layout: IconSheetLayout
    let remove: (Int) -> Void

    var body: some View {
        let scale = PaperPreview.displayWidth / CGFloat(layout.width)

        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                if let image = bitmap?.image {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                }
                ForEach(Array(icons.enumerated()), id: \.offset) { index, icon in
                    let cell = layout.cell(index)
                    Button {
                        remove(index)
                    } label: {
                        Color.clear.contentShape(.rect)
                    }
                    .frame(width: CGFloat(cell.size) * scale, height: CGFloat(cell.size) * scale)
                    .offset(x: CGFloat(cell.x) * scale, y: CGFloat(cell.y) * scale)
                    .accessibilityLabel("Remove \(icon.name)")
                }
            }
            .frame(width: PaperPreview.displayWidth, height: CGFloat(layout.height) * scale, alignment: .topLeading)
            .background(.white)
            .shadow(color: .black.opacity(0.08), radius: 12, y: 8)

            Text(millimeterLabel(width: layout.width, height: layout.height))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
