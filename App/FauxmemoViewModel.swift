import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers
import AppKit

@Observable
final class FauxmemoViewModel: FauxmemoManagerDelegate {
    private(set) var state: PrinterState = .disconnected
    private var fauxmemoImage: FauxmemoImage?
    private var manager: FauxmemoManager!

    private(set) var printCompleted: Bool = false

    var canPrint: Bool {
        guard case .ready = state, previewImage != nil else { return false }
        return true
    }

    var isConnecting: Bool {
        switch state {
        case .disconnected, .scanning, .connecting:
            return true
        case .ready, .printing, .notReady, .error:
            return false
        }
    }

    var showProgress: Bool {
        switch state {
        case .disconnected, .scanning, .connecting, .printing:
            return true
        case .ready, .notReady, .error:
            return false
        }
    }

    var buttonLabel: String {
        switch state {
        case .disconnected, .scanning:
            return "Scanning…"
        case .connecting:
            return "Connecting…"
        case .ready:
            return "Print"
        case .printing:
            return "Printing…"
        case .notReady(let reason):
            if reason.contains(.noPaper) { return "No Paper" }
            if reason.contains(.coverOpen) { return "Cover Open" }
            if reason.contains(.overheated) { return "Overheated" }
            return "Not Ready"
        case .error(let message):
            return message
        }
    }

    var previewImage: CGImage? {
        fauxmemoImage?.dithered
    }

    init() {
        manager = FauxmemoManager(delegate: self)
    }

    func loadImage(from url: URL) {
        guard let image = FauxmemoImage(url: url) else {
            return
        }

        fauxmemoImage = image
    }

    func loadImage(from nsImage: NSImage) {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let image = FauxmemoImage(cgImage: cgImage) else {
            return
        }

        fauxmemoImage = image
    }

    func loadImage(from itemProviders: [NSItemProvider]) {
        guard let provider = itemProviders.first else { return }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
                guard let data else { return }
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("png")
                do {
                    try data.write(to: tempURL)
                    DispatchQueue.main.async {
                        self?.loadImage(from: tempURL)
                    }
                } catch {}
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                if let url = item as? URL {
                    DispatchQueue.main.async {
                        self?.loadImage(from: url)
                    }
                }
            }
        }
    }

    func printImage() {
        guard case .ready(let printer) = state, let image = fauxmemoImage else { return }
        printer.print(image)
    }

    func clearImage() {
        fauxmemoImage = nil
    }

    // MARK: - FauxmemoManagerDelegate

    func manager(_ manager: FauxmemoManager, didChangeState state: PrinterState) {
        // Detect print completion: .printing → .ready
        if case .printing = self.state, case .ready = state {
            printCompleted = true
        }
        self.state = state
    }
}
