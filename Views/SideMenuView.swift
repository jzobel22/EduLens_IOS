import SwiftUI

struct SideMenuView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selected: MainSection
    @Binding var showMenu: Bool

    @State private var isLoggingOut: Bool = false

    private var brandColor: Color {
        Color(hex: appState.branding?.primary_color) ?? .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            VStack(spacing: 6) {
                ForEach(MainSection.allCases) { section in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selected = section
                            showMenu = false
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section.systemImage)
                                .imageScale(.medium)
                                .foregroundColor(selected == section ? brandColor : .secondary)

                            Text(section.label)
                                .font(.subheadline.weight(selected == section ? .semibold : .regular))
                                .foregroundColor(.primary)

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selected == section ? brandColor.opacity(0.10) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!appState.isAuthenticated) // optional safety
                    .opacity(appState.isAuthenticated ? 1.0 : 0.6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            Spacer()

            Divider()

            // MARK: - Sign out
            Button {
                Task { await logout() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .imageScale(.medium)

                    Text(isLoggingOut ? "Signing out…" : "Sign out")
                        .font(.subheadline)

                    Spacer()

                    if isLoggingOut {
                        ProgressView()
                            .scaleEffect(0.85)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
            .disabled(isLoggingOut)

            Spacer().frame(height: 16)
        }
        .frame(maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EduLens")
                .font(.title3.bold())

            if let name = appState.branding?.school_name, !name.isEmpty {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Student app")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 14)
    }

    private func logout() async {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        defer { isLoggingOut = false }

        // Close the menu immediately for cleaner UX
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.2)) {
                showMenu = false
            }
        }

        // Proper logout clears Keychain + state
        await AuthService.logout(appState: appState)
    }
}
