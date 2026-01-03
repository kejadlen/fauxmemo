import SwiftUI

@main
struct FauxmemoApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Window("Fauxmemo", id: "main") {
            ContentView(viewModel: appDelegate.viewModel)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = FauxmemoViewModel()

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        viewModel.loadImage(from: url)
    }
}
