import FauxmemoKit
import SwiftUI

struct PhotoPrintView: View {
    let image: UIImage

    @AppStorage("dither") private var dither: Dither = .atkinson
    @State private var brightness = 0.0
    @State private var bitmap: Bitmap?

    var body: some View {
        VStack(spacing: 20) {
            PhotoPreview(image: image, dither: dither, brightness: brightness, bitmap: $bitmap)
                .frame(maxHeight: .infinity)

            VStack(spacing: 16) {
                DitherPicker(selection: $dither)
                HStack(spacing: 14) {
                    Text("Bright").frame(width: 72, alignment: .leading)
                    Slider(value: $brightness, in: -1...1)
                }
                PrintButton(bitmap: bitmap)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Palette.ground)
        .navigationTitle("Photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PrinterStatusChip()
            }
        }
    }
}
