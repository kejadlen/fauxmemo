import FauxmemoKit
import PhosphorSwift
import SwiftUI

/// Something printed as a square: a Phosphor glyph or an emoji.
enum PrintIcon: Hashable, Identifiable {
    case glyph(Ph)
    case emoji(String)

    var id: Self { self }

    /// A single emoji typed into a search field, if that's what `query` is.
    init?(emojiQuery query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        // Digits and "#" count as emoji on their own, so a lone scalar must default to emoji presentation.
        guard trimmed.count == 1,
              let first = trimmed.unicodeScalars.first,
              first.properties.isEmojiPresentation || (trimmed.unicodeScalars.count > 1 && first.properties.isEmoji)
        else { return nil }
        self = .emoji(trimmed)
    }

    var name: String {
        switch self {
        case .glyph(let glyph): glyph.rawValue.replacingOccurrences(of: "-", with: " ")
        case .emoji(let emoji): emoji
        }
    }

    var isEmoji: Bool {
        if case .emoji = self { return true }
        return false
    }

    /// Glyphs are line art and always threshold, so `dither` only shades emoji.
    @MainActor
    func bitmap(size: Int, weight: Ph.IconWeight, dither: Dither) -> Bitmap? {
        let side = CGFloat(size)
        switch self {
        case .glyph(let glyph):
            let view = glyph.weight(weight)
                .foregroundStyle(Color.black)
                .frame(width: side, height: side)
                .background(Color.white)
            return GrayImage(rendering: view).map { Dither.threshold.apply(to: $0) }
        case .emoji(let emoji):
            let view = Text(emoji)
                .font(.system(size: side * 0.8))
                .frame(width: side, height: side)
                .background(Color.white)
            return GrayImage(rendering: view).map { dither.apply(to: $0) }
        }
    }
}
