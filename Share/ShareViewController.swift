import AppKit
import UniformTypeIdentifiers

class ShareViewController: NSViewController {
    override var nibName: NSNib.Name? { nil }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        openImageInApp()
    }

    private func openImageInApp() {
        guard let extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
            return
        }

        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, error in
                    DispatchQueue.main.async {
                        if let data, let url = self?.saveToTemp(data),
                           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.fauxmemo.Fauxmemo") {
                            NSWorkspace.shared.open(
                                [url],
                                withApplicationAt: appURL,
                                configuration: NSWorkspace.OpenConfiguration()
                            )
                        }
                        self?.extensionContext?.completeRequest(returningItems: nil)
                    }
                }
                return
            }
        }
        extensionContext.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }

    private func saveToTemp(_ data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
