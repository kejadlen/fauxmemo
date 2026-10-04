import FauxmemoKit
import ImageIO
import UIKit

extension UIImage {
    /// Decodes at a bounded size so large photos don't blow the share extension's memory limit.
    static func downsampled(from data: Data, maxPixelSize: Int = 1600) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return downsampled(source, maxPixelSize: maxPixelSize)
    }

    static func downsampled(from url: URL, maxPixelSize: Int = 1600) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return downsampled(source, maxPixelSize: maxPixelSize)
    }

    private static func downsampled(_ source: CGImageSource, maxPixelSize: Int) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}

extension GrayImage {
    /// Draws a photo across the print width. Landscape photos are turned
    /// sideways so they print as large as possible.
    init?(printing image: UIImage, width: Int = PhomemoEncoder.printWidth) {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let landscape = size.width > size.height
        let aspect = landscape ? size.width / size.height : size.height / size.width
        let height = max(1, Int((CGFloat(width) * aspect).rounded()))
        let w = CGFloat(width)
        let h = CGFloat(height)

        self.init(width: width, height: height) { context in
            // Switch to UIKit's top-left origin.
            context.translateBy(x: 0, y: h)
            context.scaleBy(x: 1, y: -1)
            UIGraphicsPushContext(context)
            if landscape {
                context.translateBy(x: w, y: 0)
                context.rotate(by: .pi / 2)
                image.draw(in: CGRect(x: 0, y: 0, width: h, height: w))
            } else {
                image.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
            }
            UIGraphicsPopContext()
        }
    }

    init?(cgImage: CGImage) {
        self.init(width: cgImage.width, height: cgImage.height) { context in
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        }
    }

    /// Renders into a white grayscale canvas. Transparent areas stay white.
    private init?(width: Int, height: Int, draw: (CGContext) -> Void) {
        var pixels = [UInt8](repeating: 255, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .high
            draw(context)
            return true
        }
        guard drawn else { return nil }
        self.init(width: width, height: height, pixels: pixels)
    }
}

extension Bitmap {
    var image: UIImage? {
        guard width > 0, height > 0,
              let provider = CGDataProvider(data: Data(grayPixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// "48 × 57 mm" for a print of the given size in dots.
func millimeterLabel(width: Int, height: Int) -> String {
    let perMillimeter = Double(PhomemoEncoder.dotsPerMillimeter)
    let w = Int((Double(width) / perMillimeter).rounded())
    let h = Int((Double(height) / perMillimeter).rounded())
    return "\(w) × \(h) mm"
}
