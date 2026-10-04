import Foundation

/// Turns a bitmap into the byte stream the Phomemo T02 expects.
///
/// Ported from the macOS Fauxmemo, which follows vivier/phomemo-tools.
public enum PhomemoEncoder {
    /// Dots across the T02's print head (48 mm at 203 dpi).
    public static let printWidth = 384
    /// Dots per millimetre at 203 dpi.
    public static let dotsPerMillimeter = 8

    private static let bytesPerLine = printWidth / 8
    private static let maxLinesPerBlock = 256

    public static func encode(_ bitmap: Bitmap) -> Data {
        precondition(bitmap.width <= printWidth, "bitmap is wider than the print head")

        var data = header()
        var remaining = bitmap.height
        var y = 0

        while remaining > 0 {
            let lines = min(remaining, maxLinesPerBlock)
            data.append(marker(lines: UInt8(lines - 1)))
            remaining -= lines
            for _ in 0..<lines {
                data.append(line(bitmap, row: y))
                y += 1
            }
        }

        data.append(footer())
        return data
    }

    static func header() -> Data {
        Data([0x1b, 0x40, 0x1b, 0x61, 0x01, 0x1f, 0x11, 0x02, 0x04])
    }

    static func marker(lines: UInt8) -> Data {
        Data([
            0x1d, 0x76,
            0x30, 0x00,
            0x30, 0x00,
            lines, 0x00
        ])
    }

    static func line(_ bitmap: Bitmap, row: Int) -> Data {
        var data = Data(capacity: bytesPerLine)
        for column in 0..<bytesPerLine {
            var byte: UInt8 = 0
            for bit in 0..<8 {
                let x = column * 8 + bit
                if x < bitmap.width, bitmap[x, row] {
                    byte |= 1 << (7 - bit)
                }
            }
            // A bare line feed confuses the printer.
            if byte == 0x0a {
                byte = 0x14
            }
            data.append(byte)
        }
        return data
    }

    static func footer() -> Data {
        Data([
            0x1b, 0x64, 0x02,
            0x1b, 0x64, 0x02,
            0x1f, 0x11, 0x08,
            0x1f, 0x11, 0x0e,
            0x1f, 0x11, 0x07,
            0x1f, 0x11, 0x09
        ])
    }
}
