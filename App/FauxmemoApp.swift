import SwiftUI

@main
struct FauxmemoApp: App {
    @State private var viewModel = FauxmemoViewModel()

    var body: some Scene {
        Window("Fauxmemo", id: "main") {
            ContentView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
