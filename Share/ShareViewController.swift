import FauxmemoKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let printer = PhomemoPrinter()
    private let shared = SharedImage()

    override func viewDidLoad() {
        super.viewDidLoad()

        let root = ShareSheetView(shared: shared) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        .environment(printer)
        .preferredColorScheme(.light)
        .tint(Palette.accent)

        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        Task {
            shared.image = await loadImage()
            shared.loaded = true
        }
    }

    private func loadImage() async -> UIImage? {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) })
        else { return nil }

        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier) { item, _ in
                switch item {
                case let url as URL:
                    continuation.resume(returning: UIImage.downsampled(from: url))
                case let data as Data:
                    continuation.resume(returning: UIImage.downsampled(from: data))
                case let image as UIImage:
                    continuation.resume(returning: image)
                default:
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

@Observable
final class SharedImage {
    var image: UIImage?
    var loaded = false
}

struct ShareSheetView: View {
    let shared: SharedImage
    let close: () -> Void

    @AppStorage("dither") private var dither: Dither = .atkinson
    @State private var bitmap: Bitmap?
    @State private var printed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let image = shared.image {
                    PhotoPreview(image: image, dither: dither, brightness: 0, bitmap: $bitmap)
                        .frame(maxHeight: .infinity)
                } else if shared.loaded {
                    ContentUnavailableView("No image", systemImage: "photo")
                        .frame(maxHeight: .infinity)
                } else {
                    ProgressView().frame(maxHeight: .infinity)
                }

                DitherPicker(selection: $dither)
                PrintButton(bitmap: bitmap) { printed = true }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .background(Palette.ground)
            .navigationTitle("Fauxmemo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(printed ? "Done" : "Cancel", action: close)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PrinterStatusChip()
                }
            }
        }
    }
}
