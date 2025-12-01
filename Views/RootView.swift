import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainShellView()
            } else {
                LoginView()
            }
        }
        // Make sure the whole window uses the app background
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
