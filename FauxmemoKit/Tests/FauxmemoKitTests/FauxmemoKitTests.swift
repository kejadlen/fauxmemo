import Foundation
import XCTest
@testable import FauxmemoKit

final class DitherTests: XCTestCase {
    func testWhiteStaysWhite() {
        let image = GrayImage(width: 16, height: 16, fill: 255)
        for dither in Dither.allCases {
            XCTAssertFalse(dither.apply(to: image).dots.contains(true), "\(dither)")
        }
    }

    func testBlackStaysBlack() {
        let image = GrayImage(width: 16, height: 16, fill: 0)
        for dither in Dither.allCases {
            XCTAssertFalse(dither.apply(to: image).dots.contains(false), "\(dither)")
        }
    }

    func testMidGrayIsRoughlyHalfBlack() {
        let image = GrayImage(width: 64, height: 64, fill: 128)
        for dither in [Dither.atkinson, .floydSteinberg] {
            let black = dither.apply(to: image).dots.filter { $0 }.count
            let ratio = Double(black) / Double(64 * 64)
            XCTAssertEqual(ratio, 0.5, accuracy: 0.1, "\(dither)")
        }
    }

    func testThresholdSplitsAt128() {
        let image = GrayImage(width: 2, height: 1, pixels: [127, 128])
        XCTAssertEqual(Dither.threshold.apply(to: image).dots, [true, false])
    }

    func testBrightnessLightens() {
        let image = GrayImage(width: 1, height: 1, pixels: [100])
        XCTAssertEqual(Dither.threshold.apply(to: image).dots, [true])
        XCTAssertEqual(Dither.threshold.apply(to: image, brightness: 0.5).dots, [false])
    }
}

final class EncoderTests: XCTestCase {
    func testFramesOneBlock() {
        var bitmap = Bitmap(width: 384, height: 2)
        bitmap[0, 0] = true
        let data = PhomemoEncoder.encode(bitmap)

        let header = PhomemoEncoder.header()
        let marker = PhomemoEncoder.marker(lines: 1)
        let footer = PhomemoEncoder.footer()
        XCTAssertEqual(data.count, header.count + marker.count + 2 * 48 + footer.count)
        XCTAssertEqual(data.prefix(header.count), header)
        XCTAssertEqual(data.suffix(footer.count), footer)

        let firstDot = header.count + marker.count
        XCTAssertEqual(data[data.startIndex + firstDot], 0x80)
    }

    func testSplitsIntoBlocksOf256Lines() {
        let data = PhomemoEncoder.encode(Bitmap(width: 384, height: 300))
        let expected = PhomemoEncoder.header().count
            + 2 * PhomemoEncoder.marker(lines: 0).count
            + 300 * 48
            + PhomemoEncoder.footer().count
        XCTAssertEqual(data.count, expected)
    }

    func testAvoidsLineFeedBytes() {
        // 0b0000_1010 == 0x0a
        var bitmap = Bitmap(width: 384, height: 1)
        bitmap[4, 0] = true
        bitmap[6, 0] = true
        XCTAssertEqual(PhomemoEncoder.line(bitmap, row: 0).first, 0x14)
    }

    func testPadsNarrowBitmaps() {
        let line = PhomemoEncoder.line(Bitmap(width: 100, height: 1), row: 0)
        XCTAssertEqual(line.count, 48)
    }
}

final class IconSheetLayoutTests: XCTestCase {
    func testFourAcross() {
        let layout = IconSheetLayout(count: 6, perRow: 4)
        XCTAssertEqual(layout.cellSize, 96)
        XCTAssertEqual(layout.rows, 2)
        XCTAssertEqual(layout.height, 192)
        XCTAssertEqual(layout.cell(5), .init(x: 96, y: 96, size: 96))
    }

    func testCentersUnevenWidths() {
        let layout = IconSheetLayout(count: 1, perRow: 5)
        XCTAssertEqual(layout.cellSize, 76)
        XCTAssertEqual(layout.cell(0).x, 2)
    }

    func testEmpty() {
        XCTAssertEqual(IconSheetLayout(count: 0, perRow: 3).height, 0)
    }
}

final class BitmapDrawTests: XCTestCase {
    private func solid(width: Int, height: Int) -> Bitmap {
        var bitmap = Bitmap(width: width, height: height)
        for y in 0..<height { for x in 0..<width { bitmap[x, y] = true } }
        return bitmap
    }

    private func blackPoints(_ bitmap: Bitmap) -> Set<[Int]> {
        var points = Set<[Int]>()
        for y in 0..<bitmap.height { for x in 0..<bitmap.width where bitmap[x, y] { points.insert([x, y]) } }
        return points
    }

    func testDrawsAtOffset() {
        var canvas = Bitmap(width: 4, height: 4)
        canvas.draw(solid(width: 2, height: 1), x: 1, y: 2)
        XCTAssertEqual(blackPoints(canvas), [[1, 2], [2, 2]])
    }

    func testWhiteDoesNotErase() {
        var canvas = solid(width: 2, height: 2)
        canvas.draw(Bitmap(width: 2, height: 2), x: 0, y: 0)
        XCTAssertFalse(canvas.dots.contains(false))
    }

    func testClipsPastTheEdges() {
        var canvas = Bitmap(width: 3, height: 3)
        canvas.draw(solid(width: 2, height: 2), x: 2, y: 2)
        XCTAssertEqual(blackPoints(canvas), [[2, 2]])
    }

    func testClipsNegativeOffsets() {
        var canvas = Bitmap(width: 3, height: 3)
        canvas.draw(solid(width: 2, height: 2), x: -1, y: -1)
        XCTAssertEqual(blackPoints(canvas), [[0, 0]])
    }

    func testIgnoresBitmapsEntirelyOutside() {
        var canvas = Bitmap(width: 3, height: 3)
        canvas.draw(solid(width: 2, height: 2), x: 5, y: -5)
        XCTAssertFalse(canvas.dots.contains(true))
    }
}
