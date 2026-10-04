import SwiftUI

@main
struct FauxmemoApp: App {
    @State private var printer = PhomemoPrinter()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(printer)
                .preferredColorScheme(.light)
                .tint(Palette.accent)
        }
    }
}
