import SwiftUI

@main
struct EduLensStudentApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Enable verbose networking logs in dev / staging
        #if DEBUG
        APIClient.shared.enableDebugLogging = true
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
