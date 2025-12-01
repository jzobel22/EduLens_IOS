import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var email: String = ""
    @State private var isSubmitting: Bool = false
    @State private var error: String? = nil
    @State private var showSSOComingSoon: Bool = false

    var body: some View {
        ZStack {
            // Full-screen background
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 80)

                    // MARK: - Brand block (logo + subtitle only)
                    VStack(spacing: 12) {
                        Image("EduLensLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)   // larger, carries the brand
                            .shadow(color: Color.black.opacity(0.05),
                                    radius: 8, x: 0, y: 4)

                        Text("Student AI Companion")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // MARK: - Email login block
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sign in with your .edu email")
                            .font(.subheadline.weight(.medium))

                        TextField("student@university.edu", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    // MARK: - Error message
                    if let error = error {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                    }

                    // MARK: - Primary CTA
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                            Text("Continue as Student")
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

                    // MARK: - SSO (future)
                    Button {
                        showSSOComingSoon = true
                    } label: {
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

                    // MARK: - Footer
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
            Text("For the RIT pilot we’ll support direct SSO sign-in here. For now, use your .edu email above to continue.")
        }
    }

    // MARK: - Helpers

    private var canSubmit: Bool {
        !email.trimmed.isEmpty
    }

    private func submit() async {
        error = nil
        isSubmitting = true
        do {
            let trimmed = email.trimmed
            let tokens = try await AuthService.devLogin(email: trimmed)
            await MainActor.run {
                appState.accessToken = tokens.access_token
                appState.refreshToken = tokens.refresh_token
                appState.role = tokens.role
                appState.userId = tokens.user_id
                appState.email = trimmed
            }
            // Prefetch branding + courses
            try await loadInitialStudentContext()
        } catch {
            await MainActor.run {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
        await MainActor.run {
            isSubmitting = false
        }
    }

    private func loadInitialStudentContext() async throws {
        guard let token = appState.accessToken else { return }
        async let branding = StudentService.fetchBranding(accessToken: token)
        async let courses = StudentService.fetchMyCourses(accessToken: token)
        async let weekly = StudentService.fetchWeeklyReflectionStatus(accessToken: token)

        do {
            let (b, c, w) = try await (branding, courses, weekly)
            await MainActor.run {
                appState.branding = b
                appState.courses = c
                appState.selectedCourse = c.first
                appState.weeklyReflectionStatus = w
            }
        } catch {
            // Non-fatal; user is logged in but missing some data
        }
    }
}

// Small helper
private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
