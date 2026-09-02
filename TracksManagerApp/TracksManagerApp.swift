import SwiftUI

@main
struct TracksManagerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .windowStyle(.automatic)
    }
}
