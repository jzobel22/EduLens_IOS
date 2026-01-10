import SwiftUI

struct ReflectionsView: View {
    @EnvironmentObject var appState: AppState

    @State private var isLoading: Bool = false
    @State private var error: String? = nil
    @State private var showAllCourses: Bool = false

    private var selectedCourseId: String? { appState.selectedCourse?.id }

    private var reflectionSessions: [ChatSessionSummary] {
        let sessions = appState.chatSessions

        // 1) Only sessions that actually have reflections (saved or submitted)
        let withReflections = sessions.filter {
            ($0.submitted_reflection == true) ||
            (($0.reflection_text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        }

        // 2) If a course is selected and showAllCourses is false, scope to that course
        let scoped: [ChatSessionSummary]
        if showAllCourses {
            scoped = withReflections
        } else if let cid = selectedCourseId {
            scoped = withReflections.filter { $0.course_id == cid }
        } else {
            scoped = withReflections
        }

        // 3) Sort newest → oldest
        return scoped.sorted {
            parseISODate($0.started_at) ?? .distantPast > parseISODate($1.started_at) ?? .distantPast
        }
    }

    var body: some View {
        List {
            // MARK: - Scope toggle
            Section {
                Toggle(isOn: $showAllCourses) {
                    Text("Show reflections from all courses")
                        .font(.subheadline)
                }
            }

            // MARK: - Status
            if isLoading {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading reflections…")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let error = error {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }

            // MARK: - Reflections list
            Section(header: Text("Reflections linked to conversations")) {
                if !appState.isAuthenticated {
                    Text("Please sign in to view reflections.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else if reflectionSessions.isEmpty {
                    Text(emptyText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(reflectionSessions) { session in
                        ReflectionSessionRow(session: session)
                    }
                }
            }
        }
        .navigationTitle("Reflections")
        .task {
            await loadSessionsIfNeeded(force: false)
        }
        .refreshable {
            await loadSessionsIfNeeded(force: true)
        }
        .onChange(of: appState.selectedCourse?.id) { _ in
            // When course changes, keep UX consistent and refresh view data if needed.
            // (We don't force fetch unless you want to. If you do, flip force: true.)
        }
    }

    private var emptyText: String {
        if showAllCourses {
            return "Reflections you save from conversations will show up here."
        }
        if appState.selectedCourse == nil {
            return "Select a course to see reflections for that course, or enable “all courses”."
        }
        return "No saved reflections yet for this course. Reflections you save from conversations will show up here."
    }

    // MARK: - Networking

    private func loadSessionsIfNeeded(force: Bool) async {
        guard appState.isAuthenticated else { return }

        if !force, !appState.chatSessions.isEmpty { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let sessions = try await ChatService.listChatSessions(limit: 50)
            appState.chatSessions = sessions
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Date helper (file-local)

    private func parseISODate(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: value) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]
        for f in formats {
            df.dateFormat = f
            if let d = df.date(from: value) { return d }
        }
        return nil
    }
}

// MARK: - Row

private struct ReflectionSessionRow: View {
    let session: ChatSessionSummary

    private var reflectionText: String {
        (session.reflection_text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasReflectionText: Bool {
        !reflectionText.isEmpty
    }

    private var statusLabel: (text: String, color: Color) {
        if session.submitted_reflection == true {
            return ("Submitted to instructor", .blue)
        }
        if hasReflectionText {
            return ("Saved (not submitted)", .secondary)
        }
        return ("Not submitted", .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.title ?? "Untitled conversation")
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            if hasReflectionText {
                Text(reflectionText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            } else if session.submitted_reflection == true {
                Text("This reflection was submitted, but the text isn’t available on this device.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(statusLabel.text)
                    .font(.caption2)
                    .foregroundColor(statusLabel.color)
                Spacer()
                if let courseCode = session.course_code, !courseCode.isEmpty {
                    Text(courseCode)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
