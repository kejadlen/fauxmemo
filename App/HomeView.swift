import PhosphorSwift
import PhotosUI
import SwiftUI

struct HomeView: View {
    @State private var photo: PickedPhoto?
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: paste) {
                            Tile(title: "Paste", subtitle: "Image on clipboard", icon: Ph.clipboardText.regular, dark: true)
                        }
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Tile(title: "Photos", icon: Ph.image.regular)
                        }
                    }
                    NavigationLink {
                        IconSheetView()
                    } label: {
                        Tile(title: "Icon sheet", icon: Ph.shapes.regular)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Palette.ground)
            .navigationTitle("Fauxmemo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PrinterStatusChip()
                }
            }
            .navigationDestination(item: $photo) { photo in
                PhotoPrintView(image: photo.image)
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage.downsampled(from: data) {
                        photo = PickedPhoto(image: image)
                    }
                    pickerItem = nil
                }
            }
        }
    }

    private func paste() {
        guard let image = UIPasteboard.general.image else { return }
        photo = PickedPhoto(image: image)
    }
}

struct PickedPhoto: Hashable {
    let id = UUID()
    let image: UIImage

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private struct Tile: View {
    let title: String
    var subtitle: String?
    let icon: Image
    var dark = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            icon.frame(width: 30, height: 30)
            Spacer(minLength: 0)
            Text(title).font(.title3.weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(dark ? Palette.mutedOnInk : Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 148 - 36)
        .padding(18)
        .foregroundStyle(dark ? Palette.surface : Palette.ink)
        .background(dark ? Palette.ink : Palette.surface, in: .rect(cornerRadius: 20))
        .overlay {
            if !dark {
                RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.line)
            }
        }
        .contentShape(.rect(cornerRadius: 20))
    }
}
