public enum Dither: String, CaseIterable, Identifiable, Sendable {
    case atkinson
    case floydSteinberg
    case threshold

    public var id: Self { self }

    public var name: String {
        switch self {
        case .atkinson: "Atkinson"
        case .floydSteinberg: "Floyd"
        case .threshold: "Threshold"
        }
    }

    /// Converts a grayscale image to printer dots.
    ///
    /// - Parameter brightness: -1 (darker) through 1 (lighter).
    public func apply(to image: GrayImage, brightness: Double = 0) -> Bitmap {
        let offset = Float(max(-1, min(1, brightness)) * 128)
        var buffer = image.pixels.map { Float($0) + offset }
        var bitmap = Bitmap(width: image.width, height: image.height)

        let width = image.width
        let height = image.height

        func spread(_ x: Int, _ y: Int, _ amount: Float) {
            guard x >= 0, x < width, y < height else { return }
            buffer[y * width + x] += amount
        }

        for y in 0..<height {
            for x in 0..<width {
                let old = buffer[y * width + x]
                let black = old < 128
                bitmap[x, y] = black
                let error = old - (black ? 0 : 255)

                switch self {
                case .threshold:
                    break
                case .floydSteinberg:
                    spread(x + 1, y, error * 7 / 16)
                    spread(x - 1, y + 1, error * 3 / 16)
                    spread(x, y + 1, error * 5 / 16)
                    spread(x + 1, y + 1, error * 1 / 16)
                case .atkinson:
                    let share = error / 8
                    spread(x + 1, y, share)
                    spread(x + 2, y, share)
                    spread(x - 1, y + 1, share)
                    spread(x, y + 1, share)
                    spread(x + 1, y + 1, share)
                    spread(x, y + 2, share)
                }
            }
        }

        return bitmap
    }
}
