import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var appState: AppState

    @State private var isLoading: Bool = false
    @State private var loadError: String? = nil
    @State private var calendarAssignments: [CalendarAssignment] = []

    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())

    @State private var selectedAssignment: CalendarAssignment? = nil
    @State private var isPlanning: Bool = false
    @State private var planText: String? = nil
    @State private var planError: String? = nil
    @State private var showPlanSheet: Bool = false

    private var brandColor: Color {
        Color(hex: appState.branding?.primary_color) ?? .accentColor
    }

    // Show a true 7-day week
    private let daysAhead: Int = 7

    var body: some View {
        NavigationStack {
            Group {
                if !appState.isAuthenticated {
                    emptyState(
                        title: "Calendar",
                        subtitle: "Please sign in to view your weekly calendar."
                    )
                } else if appState.courses.isEmpty {
                    emptyState(
                        title: "Calendar",
                        subtitle: "Once you’re enrolled in courses, EduLens will show a weekly calendar of upcoming assignments across your classes."
                    )
                } else {
                    content
                }
            }
            .navigationTitle("Calendar")
        }
        .task {
            await loadAssignmentsForAllCourses(force: false)
        }
        .refreshable {
            await loadAssignmentsForAllCourses(force: true)
        }
        .onChange(of: appState.courses.count) { _ in
            Task { await loadAssignmentsForAllCourses(force: true) }
        }
        .sheet(isPresented: $showPlanSheet) {
            AssignmentPlanSheet(
                assignment: selectedAssignment?.assignment,
                planText: planText,
                isPlanning: isPlanning,
                errorText: planError,
                brandColor: brandColor,
                onClose: { showPlanSheet = false }
            )
        }
    }

    // MARK: - Empty state helper

    private func emptyState(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(16)
    }

    // MARK: - Main content

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("This week")
                    .font(.title3.bold())
                Text("Tap a day to see a focused view of what's due.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Week strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(weekDays, id: \.self) { day in
                        DayCardView(
                            date: day,
                            isSelected: isSameDay(day, selectedDay),
                            itemCount: assignments(on: day).count,
                            brandColor: brandColor
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedDay = day
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading assignments from your LMS…")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
            } else if let err = loadError {
                Text(err)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
            } else {
                // Focused day view
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayTitle(selectedDay))
                        .font(.headline)
                    Text(daySubtitle(selectedDay))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                let todaysItems = assignments(on: selectedDay)

                if todaysItems.isEmpty {
                    Text("No assignments due on this day.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    Spacer()
                } else {
                    List {
                        ForEach(todaysItems) { ca in
                            CalendarAssignmentRow(
                                item: ca,
                                brandColor: brandColor,
                                onPlan: { Task { await plan(for: ca) } }
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }

            Spacer()
        }
    }

    // MARK: - Week helper data

    struct CalendarAssignment: Identifiable {
        let id: String
        let assignment: StudentLMSAssignment
        let course: Course
        let dueDate: Date
    }

    private var weekDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return (0..<daysAhead).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }

    private func assignments(on day: Date) -> [CalendarAssignment] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }

        return calendarAssignments
            .filter { ca in (ca.dueDate >= dayStart) && (ca.dueDate < dayEnd) }
            .sorted(by: { $0.dueDate < $1.dueDate })
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    private func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = calendar.startOfDay(for: date)

        if day == today {
            return "Today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
                  day == calendar.startOfDay(for: tomorrow) {
            return "Tomorrow"
        } else {
            let df = DateFormatter()
            df.dateFormat = "EEEE"
            return df.string(from: date)
        }
    }

    private func daySubtitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }

    // MARK: - Loading assignments for all courses

    private func loadAssignmentsForAllCourses(force: Bool) async {
        guard appState.isAuthenticated else { return }
        let courses = appState.courses
        if courses.isEmpty { return }

        if !force, !calendarAssignments.isEmpty { return }

        isLoading = true
        loadError = nil
        defer { isLoading = false }

        var aggregated: [CalendarAssignment] = []
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let lastDay = calendar.date(byAdding: .day, value: daysAhead, to: startOfToday) ?? startOfToday

        do {
            for course in courses {
                // Uses APIClient hooks now.
                let resp = try await StudentService.fetchAssignments(courseId: course.id)

                for a in resp.assignments {
                    guard let dueStr = a.due_at,
                          let dueDate = parseDate(dueStr) else {
                        continue
                    }

                    if dueDate >= startOfToday && dueDate <= lastDay {
                        aggregated.append(
                            CalendarAssignment(
                                id: "\(course.id)|\(a.id)",
                                assignment: a,
                                course: course,
                                dueDate: dueDate
                            )
                        )
                    }
                }
            }

            calendarAssignments = aggregated.sorted(by: { $0.dueDate < $1.dueDate })
        } catch let apiErr as APIError {
            switch apiErr {
            case .httpError(let status, _, _):
                if status == 404 || status == 403 {
                    loadError = "Calendar assignments aren’t enabled for students yet.\n\n(Backend returned \(status). Once student LMS assignment access is enabled, this calendar will populate automatically.)"
                } else if status == 401 {
                    loadError = "Session expired. Please sign in again."
                } else {
                    loadError = apiErr.localizedDescription
                }
            default:
                loadError = apiErr.localizedDescription
            }
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Plan from calendar

    private func plan(for item: CalendarAssignment) async {
        guard appState.isAuthenticated else { return }

        selectedAssignment = item
        planText = nil
        planError = nil
        isPlanning = true
        showPlanSheet = true

        do {
            let res = try await StudentService.generateAssignmentPlan(
                courseId: item.course.id,
                assignmentId: item.assignment.id
            )
            planText = res.plan_markdown
        } catch let apiErr as APIError {
            switch apiErr {
            case .httpError(let status, _, _):
                if status == 404 || status == 403 {
                    planError = "Study plan generation isn’t enabled for students yet.\n\n(Backend returned \(status).)"
                } else if status == 401 {
                    planError = "Session expired. Please sign in again."
                } else {
                    planError = apiErr.localizedDescription
                }
            default:
                planError = apiErr.localizedDescription
            }
        } catch {
            planError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isPlanning = false
    }

    // MARK: - File-local date parsing

    private func parseDate(_ value: String) -> Date? {
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

// MARK: - Day card

struct DayCardView: View {
    let date: Date
    let isSelected: Bool
    let itemCount: Int
    let brandColor: Color

    private var daySymbol: String {
        let df = DateFormatter()
        df.dateFormat = "E"
        return df.string(from: date)
    }

    private var dayNumber: String {
        let df = DateFormatter()
        df.dateFormat = "d"
        return df.string(from: date)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(daySymbol.uppercased())
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)

            Text(dayNumber)
                .font(.headline.weight(.semibold))

            if itemCount > 0 {
                HStack {
                    Spacer()
                    Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(brandColor.opacity(0.8))
                        )
                        .foregroundColor(.white)
                    Spacer()
                }
            } else {
                Text("No work")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(10)
        .frame(width: 80)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? brandColor.opacity(0.1) : Color(.systemBackground))
                .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.03),
                        radius: isSelected ? 5 : 3,
                        x: 0, y: isSelected ? 3 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? brandColor : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Row for selected day

struct CalendarAssignmentRow: View {
    let item: CalendarView.CalendarAssignment
    let brandColor: Color
    let onPlan: () -> Void

    private var timeText: String {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df.string(from: item.dueDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.assignment.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer()
            }

            HStack(spacing: 8) {
                Text(item.course.code)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(brandColor.opacity(0.12))
                    )
                Text("Due \(timeText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let desc = item.assignment.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Button { onPlan() } label: {
                    Text("Plan work")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(brandColor.opacity(0.16)))
                        .foregroundColor(brandColor)
                }
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}
