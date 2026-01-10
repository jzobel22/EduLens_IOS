import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState

    @State private var isRefreshing: Bool = false
    @State private var refreshError: String? = nil
    @State private var isLoggingOut: Bool = false

    private var brandColor: Color {
        Color(hex: appState.branding?.primary_color) ?? .accentColor
    }

    var body: some View {
        List {
            // MARK: - Identity
            Section(header: Text("Student")) {
                row("Email", appState.email ?? "Unknown")
                row("Role", (appState.role ?? "student"))
                row("User ID", (appState.userId ?? "—"))
            }

            // MARK: - Institution
            Section(header: Text("Institution")) {
                row("Name", appState.branding?.school_name ?? "Not set")
            }

            // MARK: - Courses
            Section(header: Text("Courses")) {
                if appState.courses.isEmpty {
                    Text("No active courses")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                } else {
                    ForEach(appState.courses) { course in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(course.code)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                if appState.selectedCourse?.id == course.id {
                                    Text("Selected")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(brandColor)
                                }
                            }
                            if let title = course.title, !title.isEmpty {
                                Text(title)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.selectedCourse = course
                        }
                    }
                }
            }

            // MARK: - Actions
            Section(header: Text("Actions")) {
                Button {
                    Task { await refreshStudentContext() }
                } label: {
                    HStack {
                        Text("Refresh data")
                        Spacer()
                        if isRefreshing { ProgressView().scaleEffect(0.9) }
                    }
                }
                .disabled(!appState.isAuthenticated || isRefreshing)

                if let refreshError {
                    Text(refreshError)
                        .font(.footnote)
                        .foregroundColor(.red)
                }

                Button(role: .destructive) {
                    Task { await logout() }
                } label: {
                    HStack {
                        Text("Log out")
                        Spacer()
                        if isLoggingOut { ProgressView().scaleEffect(0.9) }
                    }
                }
                .disabled(isLoggingOut)
            }

            // MARK: - Diagnostics (pilot/dev helper)
            Section(header: Text("Diagnostics")) {
                row("Authenticated", appState.isAuthenticated ? "Yes" : "No")
                row("Selected course", appState.selectedCourse?.code ?? "None")

                // If you have a central Config.swift exposing base URL, swap this in.
                // For now, we just show the resolved base used by edulensAPI(path).
                row("Backend", backendDisplayValue)
            }
        }
        .navigationTitle("Profile")
    }

    // MARK: - Helpers

    @ViewBuilder
    private func row(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left)
            Spacer()
            Text(right)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var backendDisplayValue: String {
        // Best-effort; if you have a Config.swift with BACKEND_BASE_URL, use that instead.
        // This is intentionally conservative so it compiles without requiring other files.
        "Configured in edulensAPI()"
    }

    private func refreshStudentContext() async {
        guard appState.isAuthenticated else { return }

        isRefreshing = true
        refreshError = nil
        defer { isRefreshing = false }

        do {
            async let branding = StudentService.fetchBranding()
            async let courses = StudentService.fetchMyCourses()
            async let weekly = StudentService.fetchWeeklyReflectionStatus()
            async let today = StudentService.fetchTodayAllCourses()
            async let sessions = ChatService.listChatSessions(limit: 50)

            let (b, c, w, t, s) = try await (branding, courses, weekly, today, sessions)

            appState.branding = b
            appState.courses = c
            appState.weeklyReflectionStatus = w
            appState.todayAllCourses = t
            appState.chatSessions = s

            if appState.selectedCourse == nil {
                appState.selectedCourse = c.first
            } else if let selected = appState.selectedCourse,
                      !c.contains(where: { $0.id == selected.id }) {
                appState.selectedCourse = c.first
            }
        } catch {
            refreshError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func logout() async {
        isLoggingOut = true
        defer { isLoggingOut = false }
        await AuthService.logout(appState: appState)
    }
}
