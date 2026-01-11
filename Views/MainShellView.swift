import SwiftUI

enum MainSection: String, CaseIterable, Identifiable {
    case dashboard
    case liveClass
    case chat
    case assignments
    case reflections
    case calendar
    case profile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .liveClass: return "Live Class"
        case .chat: return "Assistant"
        case .assignments: return "Assignments"
        case .reflections: return "Reflections"
        case .calendar: return "Calendar"
        case .profile: return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "house"
        case .liveClass: return "dot.radiowaves.left.and.right"
        case .chat: return "sparkles"
        case .assignments: return "checklist"
        case .reflections: return "text.bubble"
        case .calendar: return "calendar"
        case .profile: return "person"
        }
    }
}

struct MainShellView: View {
    @EnvironmentObject var appState: AppState

    @State private var showMenu: Bool = false
    @State private var section: MainSection = .dashboard
    @State private var showCoursePicker: Bool = false

    @State private var didHydrateOnce: Bool = false
    @State private var isHydrating: Bool = false
    @State private var hydrateError: String? = nil

    private var institutionName: String {
        appState.branding?.school_name ?? "Your Institution"
    }

    private var headerColor: Color {
        Color(hex: appState.branding?.primary_color) ?? .accentColor
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NavigationStack {
                VStack(spacing: 0) {
                    header
                    content
                }
                .navigationBarHidden(true)
            }

            if showMenu {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showMenu = false
                        }
                    }

                SideMenuView(selected: $section, showMenu: $showMenu)
                    .frame(width: 260)
                    .transition(.move(edge: .leading))
            }
        }
        .task {
            await hydrateInitialContextIfNeeded()
        }
        // From Dashboard course card
        .onReceive(NotificationCenter.default.publisher(for: .openChatForCourse)) { note in
            if let courseId = note.object as? String,
               let course = appState.courses.first(where: { $0.id == courseId }) {
                appState.selectedCourse = course
            }
            withAnimation(.easeOut(duration: 0.2)) {
                section = .chat
                showMenu = false
            }
        }
        // NEW: Live Class pill
        .onReceive(NotificationCenter.default.publisher(for: .openLiveClassForCourse)) { note in
            if let courseId = note.object as? String,
               let course = appState.courses.first(where: { $0.id == courseId }) {
                appState.selectedCourse = course
            }
            withAnimation(.easeOut(duration: 0.2)) {
                section = .liveClass
                showMenu = false
            }
        }
        // From Dashboard course card
        .onReceive(NotificationCenter.default.publisher(for: .openAssignmentsForCourse)) { note in
            if let courseId = note.object as? String,
               let course = appState.courses.first(where: { $0.id == courseId }) {
                appState.selectedCourse = course
            }
            withAnimation(.easeOut(duration: 0.2)) {
                section = .assignments
                showMenu = false
            }
        }
        .sheet(isPresented: $showCoursePicker) {
            CoursePickerView()
                .environmentObject(appState)
        }
        .alert("Couldn’t refresh data", isPresented: .constant(hydrateError != nil)) {
            Button("OK", role: .cancel) { hydrateError = nil }
        } message: {
            Text(hydrateError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showMenu.toggle()
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .imageScale(.medium)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("EduLens for \(institutionName)")
                        .font(.headline)
                        .foregroundColor(headerColor)

                    Button {
                        showCoursePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            if let course = appState.selectedCourse {
                                Text("\(course.code) • \(course.title ?? "")")
                                    .lineLimit(1)
                            } else {
                                Text("Select a course")
                            }
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isHydrating {
                    ProgressView()
                        .scaleEffect(0.85)
                } else {
                    Button {
                        Task { await hydrateInitialContext(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .imageScale(.small)
                            .foregroundColor(.secondary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Refresh")
                }

                if let email = appState.email {
                    Text(email)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 6)

            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(headerColor.opacity(0.3))
        }
        .background(Color(.systemBackground).ignoresSafeArea(edges: .top))
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .dashboard: DashboardView()
        case .liveClass: LiveClassView()
        case .chat: ChatSessionsView()
        case .assignments: AssignmentsView()
        case .reflections: ReflectionsView()
        case .calendar: CalendarView()
        case .profile: ProfileView()
        }
    }

    // MARK: - Initial data hydration

    private func hydrateInitialContextIfNeeded() async {
        guard appState.isAuthenticated else { return }
        guard !didHydrateOnce else { return }
        await hydrateInitialContext(force: false)
    }

    private func hydrateInitialContext(force: Bool) async {
        guard appState.isAuthenticated else { return }
        if isHydrating { return }

        isHydrating = true
        defer { isHydrating = false }

        // ✅ IMPORTANT: Read @MainActor state up front into locals
        let needsBranding: Bool = force || (appState.branding == nil)
        let needsCourses: Bool = force || appState.courses.isEmpty
        let needsWeekly: Bool = force || appState.weeklyReflectionStatus.isEmpty
        let needsToday: Bool = force || (appState.todayAllCourses == nil)
        let needsSessions: Bool = force || appState.chatSessions.isEmpty

        do {
            async let branding: Branding? = needsBranding ? StudentService.fetchBranding() : nil
            async let courses: [Course]? = needsCourses ? StudentService.fetchMyCourses() : nil
            async let weekly: [StudentWeeklyReflectionStatus]? = needsWeekly ? StudentService.fetchWeeklyReflectionStatus() : nil
            async let today: MultiCourseTodayResponse? = needsToday ? StudentService.fetchTodayAllCourses() : nil
            async let sessions: [ChatSessionSummary]? = needsSessions ? ChatService.listChatSessions(limit: 50) : nil

            let (b, c, w, t, s) = try await (branding, courses, weekly, today, sessions)

            if let b { appState.branding = b }

            if let c {
                appState.courses = c
                if appState.selectedCourse == nil {
                    appState.selectedCourse = c.first
                } else if let selected = appState.selectedCourse,
                          !c.contains(where: { $0.id == selected.id }) {
                    appState.selectedCourse = c.first
                }
            }

            if let w { appState.weeklyReflectionStatus = w }
            if let t { appState.todayAllCourses = t }
            if let s { appState.chatSessions = s }

            didHydrateOnce = true
        } catch {
            hydrateError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
