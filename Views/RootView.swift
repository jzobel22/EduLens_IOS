import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    @State private var didBootstrap: Bool = false
    @State private var bootError: String? = nil

    var body: some View {
        Group {
            // Avoid a "login flash" on cold start when tokens are restored from Keychain.
            if !didBootstrap {
                bootSplash
            } else if appState.isAuthenticated {
                MainShellView()
            } else {
                LoginView()
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .task {
            await bootstrap()
        }
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        // Only run once even if SwiftUI re-evaluates.
        guard !didBootstrap else { return }

        // If tokens exist, validate them (APIClient will refresh if needed).
        if appState.isAuthenticated {
            await appState.validateSessionWithMe()
            // If validateSessionWithMe logs the user out, they'll fall through to LoginView.
        }

        // If you want to prefetch global student context here instead of LoginView, you can later move it here.
        // For now, keep it simple: auth validation only.

        didBootstrap = true
    }

    // MARK: - Views

    private var bootSplash: some View {
        VStack(spacing: 16) {
            Image("EduLensLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)

            Text("EduLens")
                .font(.headline)

            ProgressView()
                .progressViewStyle(.circular)

            if let bootError, !bootError.isEmpty {
                Text(bootError)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading EduLens")
    }
}
