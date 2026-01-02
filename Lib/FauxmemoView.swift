import SwiftUI
import UniformTypeIdentifiers

// MARK: - Image Well

struct ImageWell: View {
    var image: CGImage?
    var onImageDropped: (NSImage) -> Void

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onDrop(of: [.image], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadDataRepresentation(for: .image) { data, _ in
                guard let data, let nsImage = NSImage(data: data) else { return }
                DispatchQueue.main.async { onImageDropped(nsImage) }
            }
            return true
        }
        .onPasteCommand(of: [.image]) { providers in
            guard let provider = providers.first else { return }
            _ = provider.loadDataRepresentation(for: .image) { data, _ in
                guard let data, let nsImage = NSImage(data: data) else { return }
                DispatchQueue.main.async { onImageDropped(nsImage) }
            }
        }
    }
}
