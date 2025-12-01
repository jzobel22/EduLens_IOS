import SwiftUI

enum MainSection: String, CaseIterable, Identifiable {
    case dashboard
    case chat
    case reflections
    case assignments
    case calendar
    case profile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .chat: return "Chat"
        case .reflections: return "Reflections"
        case .assignments: return "Assignments"
        case .calendar: return "Calendar"
        case .profile: return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "house"
        case .chat: return "bubble.left.and.bubble.right"
        case .reflections: return "text.bubble"
        case .assignments: return "checklist"
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
        // Handle "open chat" / "open assignments" from dashboard course cards
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
    }

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
                        .foregroundColor(headerColor) // branded text

                    if let course = appState.selectedCourse {
                        Button {
                            showCoursePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("\(course.code) • \(course.title ?? "")")
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            showCoursePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Select a course")
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                if let email = appState.email {
                    Text(email)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)      // smaller top padding
            .padding(.bottom, 6)   // smaller bottom padding

            // Thin accent line instead of a big colored band
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(headerColor.opacity(0.3))
        }
        .background(
            Color(.systemBackground)  // just the normal background, no heavy tint
                .ignoresSafeArea(edges: .top)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .dashboard:
            DashboardView()
        case .chat:
            ChatSessionsView()
        case .reflections:
            ReflectionsView()
        case .assignments:
            AssignmentsView()
        case .calendar:
            CalendarView()
        case .profile:
            ProfileView()
        }
    }
}
