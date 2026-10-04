import FauxmemoKit
import SwiftUI

enum Palette {
    static let ground = Color(hex: 0xECEAE4)
    static let surface = Color(hex: 0xF8F7F3)
    static let ink = Color(hex: 0x171716)
    static let line = Color(hex: 0xD3D0C8)
    static let muted = Color(hex: 0x5E5C57)
    static let mutedOnInk = Color(hex: 0xB9B6AE)
    static let accent = Color(hex: 0x2340C8)
    static let ok = Color(hex: 0x1F8A4C)
    static let busy = Color(hex: 0xC27A12)
    static let bad = Color(hex: 0xB3261E)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}

/// Printer status; tap to look for the printer again.
struct PrinterStatusChip: View {
    @Environment(PhomemoPrinter.self) private var printer

    var body: some View {
        Button {
            printer.reconnect()
        } label: {
            HStack(spacing: 6) {
                Circle().fill(dotColor).frame(width: 8, height: 8)
                Text(label).font(.system(.caption, design: .monospaced))
            }
            .foregroundStyle(Palette.ink)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Printer: \(printer.state.summary)")
    }

    private var label: String {
        switch printer.state {
        case .notReady, .error: printer.state.summary
        default: "T02"
        }
    }

    private var dotColor: Color {
        switch printer.state {
        case .ready: Palette.ok
        case .scanning, .connecting, .printing: Palette.busy
        case .notReady, .error: Palette.bad
        case .disconnected: Palette.line
        }
    }
}

/// A print as it will come out, at 0.75 pt per dot.
struct PaperPreview: View {
    let bitmap: Bitmap?

    static let displayWidth: CGFloat = 288

    var body: some View {
        VStack(spacing: 10) {
            Group {
                if let image = bitmap?.image {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.white
                        .aspectRatio(4 / 5, contentMode: .fit)
                        .overlay(ProgressView())
                }
            }
            .background(.white)
            .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
            .frame(maxWidth: Self.displayWidth, maxHeight: .infinity)

            if let bitmap {
                Text(millimeterLabel(width: bitmap.width, height: bitmap.height))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.muted)
            }
        }
    }
}

/// Dithers a photo for the printer whenever the settings change.
struct PhotoPreview: View {
    let image: UIImage
    let dither: Dither
    let brightness: Double
    @Binding var bitmap: Bitmap?

    @State private var gray: GrayImage?

    private struct Settings: Hashable {
        let dither: Dither
        let brightness: Double
        let ready: Bool
    }

    var body: some View {
        PaperPreview(bitmap: bitmap)
            .task {
                let image = image
                gray = await Task.detached { GrayImage(printing: image) }.value
            }
            .task(id: Settings(dither: dither, brightness: brightness, ready: gray != nil)) {
                guard let gray else { return }
                let dither = dither
                let brightness = brightness
                let result = await Task.detached { dither.apply(to: gray, brightness: brightness) }.value
                guard !Task.isCancelled else { return }
                bitmap = result
            }
    }
}

struct DitherPicker: View {
    @Binding var selection: Dither

    var body: some View {
        Picker("Dither", selection: $selection) {
            ForEach(Dither.allCases) { dither in
                Text(dither.name).tag(dither)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct PrintButton: View {
    @Environment(PhomemoPrinter.self) private var printer
    let bitmap: Bitmap?
    var onPrint: () -> Void = {}

    var body: some View {
        Button {
            guard let bitmap, case .ready(let ready) = printer.state else { return }
            ready.print(bitmap)
            onPrint()
        } label: {
            HStack(spacing: 10) {
                if printer.state.isPrinting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "printer")
                }
                Text("Print")
            }
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 7)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .tint(Palette.accent)
        .disabled(bitmap == nil || !printer.state.isReady)
    }
}

extension PrinterState {
    var isPrinting: Bool {
        if case .printing = self { return true }
        return false
    }
}
