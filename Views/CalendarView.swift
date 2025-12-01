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
                if appState.courses.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Calendar")
                            .font(.title2.bold())
                        Text("Once you’re enrolled in courses, EduLens will show a weekly calendar of upcoming assignments across your classes.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(16)
                } else {
                    content
                }
            }
            .navigationTitle("Calendar")
        }
        .onAppear {
            Task { await loadAssignmentsForAllCourses() }
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
                                onPlan: {
                                    Task { await plan(for: ca) }
                                }
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

        return calendarAssignments.filter { ca in
            (ca.dueDate >= dayStart) && (ca.dueDate < dayEnd)
        }.sorted(by: { $0.dueDate < $1.dueDate })
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
            return df.string(from: date)   // e.g. "Wednesday"
        }
    }

    private func daySubtitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)      // e.g. "Nov 26"
    }

    // MARK: - Loading assignments for all courses

    private func loadAssignmentsForAllCourses() async {
        guard let token = appState.accessToken else { return }
        let courses = appState.courses
        if courses.isEmpty { return }

        isLoading = true
        loadError = nil

        var aggregated: [CalendarAssignment] = []
        let calendar = Calendar.current

        do {
            for course in courses {
                let resp = try await StudentService.fetchAssignments(
                    courseId: course.id,
                    accessToken: token
                )
                for a in resp.assignments {
                    guard let dueStr = a.due_at,
                          let dueDate = parseCourseDate(dueStr) else {
                        continue
                    }

                    let startOfToday = calendar.startOfDay(for: Date())
                    guard let lastDay = calendar.date(byAdding: .day, value: daysAhead, to: startOfToday) else { continue }

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

            await MainActor.run {
                calendarAssignments = aggregated
            }
        } catch {
            await MainActor.run {
                loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    // MARK: - Plan from calendar

    private func plan(for item: CalendarAssignment) async {
        guard let token = appState.accessToken else { return }

        await MainActor.run {
            selectedAssignment = item
            planText = nil
            planError = nil
            isPlanning = true
            showPlanSheet = true
        }

        do {
            let res = try await StudentService.generateAssignmentPlan(
                courseId: item.course.id,
                assignmentId: item.assignment.id,
                accessToken: token
            )
            await MainActor.run {
                planText = res.plan_markdown
            }
        } catch {
            await MainActor.run {
                planError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }

        await MainActor.run {
            isPlanning = false
        }
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
        df.dateFormat = "E"   // Mon, Tue, etc.
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
                        .padding(.horizontal, 4)   // slightly less padding
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(brandColor.opacity(0.8))
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
        .frame(width: 80)   // a bit wider so "2 items" fits
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
                Button {
                    onPlan()
                } label: {
                    Text("Plan work")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(brandColor.opacity(0.16))
                        )
                        .foregroundColor(brandColor)
                }
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}
