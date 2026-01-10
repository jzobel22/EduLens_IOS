import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState

    @State private var email: String = ""
    @State private var pilotKey: String = ""   // NEW
    @State private var isSubmitting: Bool = false
    @State private var error: String? = nil
    @State private var showSSOComingSoon: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 80)

                    VStack(spacing: 12) {
                        Image("EduLensLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)

                        Text("Student AI Companion")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Email + Pilot password
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sign in for the pilot")
                            .font(.subheadline.weight(.medium))

                        TextField("student@university.edu", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )

                        SecureField("Pilot password", text: $pilotKey)
                            .textContentType(.password)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )

                        Text("Ask your instructor for the pilot password.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    if let error = error, !error.isEmpty {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                            .multilineTextAlignment(.leading)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 10) {
                            if isSubmitting { ProgressView().progressViewStyle(.circular) }
                            Text("Continue")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(canSubmit ? Color.accentColor : Color(.systemGray4))
                        )
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .disabled(!canSubmit || isSubmitting)

                    Button { showSSOComingSoon = true } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.key")
                                .imageScale(.medium)
                            Text("Sign in with institution SSO")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)
                    .foregroundColor(.accentColor)

                    Spacer().frame(height: 40)

                    Text("For pilot/demo use only")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Spacer().frame(height: 40)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert("SSO sign-in coming soon", isPresented: $showSSOComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("For the RIT pilot we’ll support direct SSO sign-in here. For now, use your pilot credentials above to continue.")
        }
        .task {
            await bootstrapIfAlreadyAuthenticated()
        }
    }

    private var canSubmit: Bool {
        !email.trimmed.isEmpty && !pilotKey.trimmed.isEmpty
    }

    private func submit() async {
        error = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let trimmedEmail = email.trimmed
            let trimmedKey = pilotKey.trimmed

            try await AuthService.devLoginAndStoreSession(
                appState: appState,
                email: trimmedEmail,
                role: "student",
                secret: trimmedKey,
                validateMe: true
            )

            try await loadInitialStudentContext()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func bootstrapIfAlreadyAuthenticated() async {
        guard appState.isAuthenticated else { return }
        await appState.validateSessionWithMe()
        guard appState.isAuthenticated else { return }
        do { try await loadInitialStudentContext() } catch { /* ignore */ }
    }

    private func loadInitialStudentContext() async throws {
        // You can eventually remove explicit tokens from StudentService calls,
        // but leaving this as-is is fine since StudentService has overloads.
        async let branding = StudentService.fetchBranding()
        async let courses = StudentService.fetchMyCourses()
        async let weekly = StudentService.fetchWeeklyReflectionStatus()

        do {
            let (b, c, w) = try await (branding, courses, weekly)
            appState.branding = b
            appState.courses = c
            appState.selectedCourse = appState.selectedCourse ?? c.first
            appState.weeklyReflectionStatus = w
        } catch {
            // Non-fatal
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
