import PhosphorSwift
import SwiftUI

/// Glyphs matching `query`, or just the emoji when `query` is one.
struct IconPicker: View {
    let query: String
    let weight: Ph.IconWeight
    var counts: [PrintIcon: Int] = [:]
    let pick: (PrintIcon) -> Void

    private var results: [PrintIcon] {
        if let emoji = PrintIcon(emojiQuery: query) { return [emoji] }
        let search = query.trimmingCharacters(in: .whitespaces).lowercased()
        let glyphs = search.isEmpty
            ? Ph.allCases
            : Ph.allCases.filter { $0.rawValue.replacingOccurrences(of: "-", with: " ").contains(search) }
        return glyphs.map(PrintIcon.glyph)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                ForEach(results) { icon in
                    IconButton(icon: icon, weight: weight, count: counts[icon, default: 0]) {
                        pick(icon)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        // Inset the grid, not the scroll view, so the indicator stays on the screen edge.
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }
}

private struct IconButton: View {
    let icon: PrintIcon
    let weight: Ph.IconWeight
    let count: Int
    let add: () -> Void

    var body: some View {
        Button(action: add) {
            Group {
                switch icon {
                case .glyph(let glyph):
                    glyph.weight(weight).frame(width: 24, height: 24)
                case .emoji(let emoji):
                    Text(emoji).font(.system(size: 22))
                }
            }
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
        .accessibilityLabel(icon.name)
        .accessibilityValue(count > 0 ? "\(count) on sheet" : "")
    }
}
