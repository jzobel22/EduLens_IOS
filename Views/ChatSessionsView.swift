import SwiftUI

struct ChatSessionsView: View {
    @EnvironmentObject var appState: AppState

    @State private var isLoading: Bool = false
    @State private var error: String? = nil

    @State private var selectedSession: ChatSessionSummary? = nil
    @State private var showingDetail: Bool = false
    @State private var sessionToRename: ChatSessionSummary? = nil

    private var brandColor: Color {
        Color(hex: appState.branding?.primary_color) ?? .accentColor
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - New chat card
                Section {
                    Button {
                        startNewChat()
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(brandColor.opacity(0.12))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "plus")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(brandColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("New chat")
                                    .font(.subheadline.weight(.semibold))
                                if let course = appState.selectedCourse {
                                    Text("Start a fresh conversation for \(course.code)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Select a course to start a conversation")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // MARK: - State blocks
                if appState.selectedCourse == nil {
                    Section {
                        Text("Select a course on the dashboard to view its conversations.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } else if !appState.isAuthenticated {
                    Section {
                        Text("Please sign in to view your conversations.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } else if isLoading {
                    Section { ProgressView() }
                } else if let error = error {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                } else if weekSections.isEmpty {
                    Section {
                        Text("No conversations yet for this course. Start a new chat to begin.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(weekSections, id: \.weekNumber) { section in
                        Section(header: Text("Week \(section.weekNumber)")) {
                            ForEach(section.sessions) { session in
                                Button {
                                    selectedSession = session
                                    showingDetail = true
                                } label: {
                                    ChatSessionRow(session: session)
                                }
                                .contextMenu {
                                    Button("Rename conversation") {
                                        sessionToRename = session
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Chat")
            .task {
                // Load once on first appearance
                await reloadSessions()
            }
            .refreshable {
                await reloadSessions(force: true)
            }
            .sheet(isPresented: $showingDetail) {
                ChatDetailView(session: selectedSession)
                    .environmentObject(appState)
            }
            .sheet(item: $sessionToRename) { session in
                RenameSessionView(
                    session: session,
                    onSave: { newTitle in
                        Task { await rename(session: session, to: newTitle) }
                    },
                    onCancel: {
                        sessionToRename = nil
                    }
                )
                .presentationDetents([.fraction(0.35)])
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openChatForCourse)) { _ in
            Task { await reloadSessions(force: true) }
        }
        .onChange(of: appState.selectedCourse?.id) { _ in
            // When course changes, refresh sessions for the new course.
            Task { await reloadSessions(force: true) }
        }
    }

    // MARK: - Derived data

    private var filteredSessions: [ChatSessionSummary] {
        guard let course = appState.selectedCourse else { return [] }

        // Only sessions that belong to this course
        let matching = appState.chatSessions.filter { $0.course_id == course.id }

        // Sort newest → oldest, then limit to 20
        let sorted = matching.sorted {
            sessionDate($0) ?? .distantPast > sessionDate($1) ?? .distantPast
        }
        return Array(sorted.prefix(20))
    }

    struct WeekSection {
        let weekNumber: Int
        let sessions: [ChatSessionSummary]
    }

    private var weekSections: [WeekSection] {
        guard let course = appState.selectedCourse else { return [] }
        let sessions = filteredSessions
        if sessions.isEmpty { return [] }

        let info = computeWeekInfo(
            startDateStr: course.start_date,
            endDateStr: course.end_date,
            graceDays: course.grace_days
        )

        guard let start = parseCourseDate(course.start_date) else {
            // If no start date → all sessions = Week 1
            return [WeekSection(weekNumber: 1, sessions: sessions)]
        }

        var buckets: [Int: [ChatSessionSummary]] = [:]
        let secondsPerWeek = 7.0 * 24.0 * 60.0 * 60.0

        for session in sessions {
            let d = sessionDate(session) ?? Date()
            let elapsed = d.timeIntervalSince(start) / secondsPerWeek
            var week = Int(floor(elapsed)) + 1

            if let total = info.totalWeeks {
                week = min(total, max(1, week))
            }

            buckets[week, default: []].append(session)
        }

        return buckets
            .map { WeekSection(weekNumber: $0.key, sessions: $0.value) }
            .sorted { $0.weekNumber > $1.weekNumber }
    }

    // MARK: - Networking

    private func reloadSessions(force: Bool = false) async {
        guard appState.isAuthenticated else { return }
        guard appState.selectedCourse != nil else { return }

        // Simple "do nothing" guard: if we already have sessions and not forcing, don't spam network.
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

    private func startNewChat() {
        selectedSession = nil
        showingDetail = true
    }

    private func rename(session: ChatSessionSummary, to newTitle: String) async {
        guard appState.isAuthenticated else {
            sessionToRename = nil
            return
        }

        do {
            try await ChatService.renameSession(sessionId: session.id, newTitle: newTitle)
            let sessions = try await ChatService.listChatSessions(limit: 50)
            appState.chatSessions = sessions
            sessionToRename = nil
        } catch {
            // You can add a toast here later if desired.
            sessionToRename = nil
        }
    }

    // MARK: - Date parsing (file-local helpers to avoid duplicate symbols across files)

    private func sessionDate(_ session: ChatSessionSummary) -> Date? {
        let value = session.started_at
        return parseCourseDate(value)
    }

    private func parseCourseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

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

    private func computeWeekInfo(
        startDateStr: String?,
        endDateStr: String?,
        graceDays: Int?
    ) -> (hasSchedule: Bool, currentWeek: Int?, totalWeeks: Int?, progressPct: Double) {

        guard let startStr = startDateStr,
              let endStr = endDateStr,
              let start = parseCourseDate(startStr),
              let end = parseCourseDate(endStr)
        else {
            return (false, nil, nil, 0)
        }

        let grace = graceDays ?? 0
        let cutoff = Calendar.current.date(byAdding: .day, value: grace, to: end) ?? end
        let secondsPerWeek = 7.0 * 24.0 * 60.0 * 60.0

        let totalWeeksRaw = cutoff.timeIntervalSince(start) / secondsPerWeek
        let totalWeeks = max(1, Int(round(totalWeeksRaw)))

        let today = Date()
        var currentWeek: Int

        if today < start {
            currentWeek = 1
        } else if today > cutoff {
            currentWeek = totalWeeks
        } else {
            let elapsed = today.timeIntervalSince(start) / secondsPerWeek
            currentWeek = Int(floor(elapsed)) + 1
            currentWeek = min(totalWeeks, max(1, currentWeek))
        }

        let pct = min(100, max(0, (Double(currentWeek) / Double(totalWeeks)) * 100))

        return (true, currentWeek, totalWeeks, pct)
    }
}

// MARK: - Row view

struct ChatSessionRow: View {
    let session: ChatSessionSummary

    private var subtitle: String {
        session.course_code ?? ""
    }

    private var reflectionStatusText: String? {
        if session.submitted_reflection == true {
            return "Reflection submitted"
        } else if let text = session.reflection_text, !text.isEmpty {
            return "Reflection saved"
        } else {
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title ?? "Untitled conversation")
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let rs = reflectionStatusText {
                Text(rs)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
