import SwiftUI

@main
struct WorldCup26App: App {
    @State private var env = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env.store)
                .environment(env.localization)
                .environment(env.theme)
                .environment(env.votes)
                .task {
                    env.scheduler.start()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { env.scheduler.appBecameActive() }
                }
        }
    }
}
