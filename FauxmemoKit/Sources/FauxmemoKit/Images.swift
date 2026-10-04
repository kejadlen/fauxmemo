/// An 8-bit grayscale image, row-major. 0 is black, 255 is white.
public struct GrayImage: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public var pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height, "pixel count must be width × height")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public init(width: Int, height: Int, fill: UInt8 = 255) {
        self.init(width: width, height: height, pixels: Array(repeating: fill, count: width * height))
    }
}

/// A 1-bit image in printer dots. `true` is a burned (black) dot.
public struct Bitmap: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public private(set) var dots: [Bool]

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.dots = Array(repeating: false, count: width * height)
    }

    public subscript(x: Int, y: Int) -> Bool {
        get { dots[y * width + x] }
        set { dots[y * width + x] = newValue }
    }

    /// Copies `other`'s black dots in with its top-left corner at (x, y), clipping at the edges.
    public mutating func draw(_ other: Bitmap, x: Int, y: Int) {
        let top = max(0, -y), bottom = min(other.height, height - y)
        let left = max(0, -x), right = min(other.width, width - x)
        guard top < bottom, left < right else { return }
        for oy in top..<bottom {
            for ox in left..<right where other[ox, oy] {
                self[x + ox, y + oy] = true
            }
        }
    }

    /// Grayscale bytes (0 or 255) for drawing a preview.
    public var grayPixels: [UInt8] {
        dots.map { $0 ? 0 : 255 }
    }
}
