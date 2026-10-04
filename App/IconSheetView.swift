import FauxmemoKit
import PhosphorSwift
import SwiftUI

struct IconSheetView: View {
    @State private var selected: [Ph] = []
    @State private var query = ""
    @State private var bitmap: Bitmap?
    @AppStorage("iconWeight") private var weight: Ph.IconWeight = .bold
    @AppStorage("iconsPerRow") private var perRow = 4

    /// Hairline weights break up on the print head, and duotone has no meaning in 1-bit.
    private static let weights: [Ph.IconWeight] = [.regular, .bold, .fill]

    private var layout: IconSheetLayout {
        IconSheetLayout(count: selected.count, perRow: perRow)
    }

    private var results: [Ph] {
        let search = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !search.isEmpty else { return Ph.allCases }
        return Ph.allCases.filter { $0.rawValue.replacingOccurrences(of: "-", with: " ").contains(search) }
    }

    private struct RenderKey: Hashable {
        let icons: [Ph]
        let weight: Ph.IconWeight
        let perRow: Int
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

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(results) { icon in
                        IconButton(icon: icon, weight: weight, count: counts[icon, default: 0]) {
                            selected.append(icon)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: .infinity)

            if !selected.isEmpty {
                ViewThatFits(in: .vertical) {
                    sheetPreview
                    ScrollView { sheetPreview }
                }
                .frame(maxHeight: 320)
            }

            PrintButton(bitmap: selected.isEmpty ? nil : bitmap)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Palette.ground)
        .navigationTitle("Icon sheet")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search icons")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PrinterStatusChip()
            }
        }
        .task(id: RenderKey(icons: selected, weight: weight, perRow: perRow)) {
            bitmap = render()
        }
    }

    private var sheetPreview: some View {
        SheetPreview(bitmap: bitmap, icons: selected, layout: layout) { index in
            selected.remove(at: index)
        }
    }

    private func render() -> Bitmap? {
        guard !selected.isEmpty else { return nil }
        let renderer = ImageRenderer(content: IconSheet(icons: selected, weight: weight, layout: layout))
        renderer.scale = 1
        guard let cgImage = renderer.cgImage, let gray = GrayImage(cgImage: cgImage) else { return nil }
        return Dither.threshold.apply(to: gray)
    }
}

private struct IconButton: View {
    let icon: Ph
    let weight: Ph.IconWeight
    let count: Int
    let add: () -> Void

    var body: some View {
        Button(action: add) {
            icon.weight(weight)
                .frame(width: 24, height: 24)
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(count > 0 ? Palette.surface : Palette.ink)
                .background(count > 0 ? Palette.ink : Palette.surface, in: .rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(count > 0 ? Palette.ink : Palette.line)
                }
                .overlay(alignment: .topTrailing) {
                    if count > 1 {
                        Text("\(count)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Palette.accent, in: .capsule)
                            .offset(x: 6, y: -6)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.rawValue.replacingOccurrences(of: "-", with: " "))
        .accessibilityValue(count > 0 ? "\(count) on sheet" : "")
    }
}

/// The printed sheet, one dot per point. Rendered with `ImageRenderer`.
private struct IconSheet: View {
    let icons: [Ph]
    let weight: Ph.IconWeight
    let layout: IconSheetLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            ForEach(Array(icons.enumerated()), id: \.offset) { index, icon in
                let cell = layout.cell(index)
                let size = CGFloat(cell.size)
                ZStack {
                    Rectangle()
                        .strokeBorder(Color.black, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    icon.weight(weight)
                        .foregroundStyle(Color.black)
                        .padding(size * 0.18)
                }
                .frame(width: size, height: size)
                .offset(x: CGFloat(cell.x), y: CGFloat(cell.y))
            }
        }
        .frame(width: CGFloat(layout.width), height: CGFloat(layout.height))
    }
}

/// The rendered sheet; tap an icon to take it off.
private struct SheetPreview: View {
    let bitmap: Bitmap?
    let icons: [Ph]
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
                    .accessibilityLabel("Remove \(icon.rawValue.replacingOccurrences(of: "-", with: " "))")
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
