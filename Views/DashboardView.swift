import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var loadingToday: Bool = false
    @State private var todayError: String? = nil
    @State private var hasAppeared: Bool = false

    // Brand color derived from institution branding (fallback to accentColor)
    private var brandColor: Color {
        Color(hex: appState.branding?.primary_color) ?? .accentColor
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                termProgressSection
                todayAllCoursesSection
                coursesSection
            }
            .padding(16)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 12)
            .animation(.spring(response: 0.4, dampingFraction: 0.9), value: hasAppeared)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
            }
            Task {
                await refreshIfNeeded()
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("My learning dashboard")
                .font(.title2.bold())
            Text("Quick overview of your courses, reflections, and AI support.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var termProgressSection: some View {
        Group {
            if let first = appState.courses.first {
                TermProgressCard(course: first, brandColor: brandColor)
            }
        }
    }

    private var todayAllCoursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today across your courses")
                    .font(.headline)
                Spacer()
                if loadingToday {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let err = todayError {
                Text(err)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            if let today = appState.todayAllCourses, !today.tasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(today.tasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if let code = task.course_code {
                                    Text(code)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(brandColor.opacity(0.12))
                                        )
                                }
                                Text(task.title)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                            }
                            if let desc = task.description {
                                Text(desc)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }

                    if !today.note.isEmpty {
                        Text(today.note)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            } else {
                Text("Tap below to let EduLens suggest what to focus on today across your enrolled courses.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Button {
                Task { await generateToday() }
            } label: {
                Text("Suggest a cross-course focus list")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(brandColor.opacity(0.15))
                    )
                    .foregroundColor(brandColor)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
    }

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("My courses")
                    .font(.headline)
                Spacer()
            }

            if appState.courses.isEmpty {
                Text("You don't have any active courses yet.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.courses) { course in
                        CourseCard(course: course, brandColor: brandColor)
                            .environmentObject(appState)
                            .onTapGesture {
                                appState.selectedCourse = course
                            }
                    }
                }
            }
        }
    }

    // MARK: - Data loading

    private func refreshIfNeeded() async {
        guard let token = appState.accessToken else { return }
        if appState.courses.isEmpty {
            do {
                let courses = try await StudentService.fetchMyCourses(accessToken: token)
                let weekly = try await StudentService.fetchWeeklyReflectionStatus(accessToken: token)
                await MainActor.run {
                    appState.courses = courses
                    appState.selectedCourse = courses.first
                    appState.weeklyReflectionStatus = weekly
                }
            } catch {
                // ignore for now; dashboard will just be sparse
            }
        }
    }

    private func generateToday() async {
        guard let token = appState.accessToken else { return }
        loadingToday = true
        todayError = nil
        do {
            let resp = try await StudentService.fetchTodayAllCourses(accessToken: token)
            await MainActor.run {
                appState.todayAllCourses = resp
            }
        } catch {
            await MainActor.run {
                todayError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
        await MainActor.run {
            loadingToday = false
        }
    }
}

// MARK: - Term progress card

struct TermProgressCard: View {
    let course: Course
    let brandColor: Color

    // Parse backend date strings like:
    // "2025-08-26T00:00:00" or "2025-08-26T00:00:00Z" or "2025-08-26"
    private func parseCourseDate(_ value: String?) -> Date? {
        guard let value = value else { return nil }

        // Try ISO8601 first
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: value) {
            return d
        }

        // Fallback patterns
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX", // e.g. 2025-08-26T00:00:00Z or with offset
            "yyyy-MM-dd'T'HH:mm:ss",      // e.g. 2025-08-26T00:00:00
            "yyyy-MM-dd"                  // e.g. 2025-08-26
        ]

        for format in formats {
            df.dateFormat = format
            if let d = df.date(from: value) {
                return d
            }
        }

        return nil
    }

    private var weekInfo: (current: Int?, total: Int?) {
        guard
            let startDate = parseCourseDate(course.start_date),
            let endDate = parseCourseDate(course.end_date)
        else {
            return (nil, nil)
        }

        let today = Date()
        let calendar = Calendar.current

        // Total weeks in course
        let totalDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let totalWeeks = max(1, Int(ceil(Double(max(totalDays, 1)) / 7.0)))

        // Current week (clamped to [1, totalWeeks])
        let daysFromStart = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
        var currentWeek = Int(floor(Double(daysFromStart) / 7.0)) + 1
        if currentWeek < 1 { currentWeek = 1 }
        if currentWeek > totalWeeks { currentWeek = totalWeeks }

        return (currentWeek, totalWeeks)
    }

    private var progressFraction: Double {
        guard let current = weekInfo.current, let total = weekInfo.total, total > 0 else {
            return 0.4
        }
        return min(1.0, max(0.0, Double(current) / Double(total)))
    }

    private var progressPercentText: String? {
        guard let current = weekInfo.current, let total = weekInfo.total, total > 0 else {
            return nil
        }
        let pct = Int(round(100.0 * Double(current) / Double(total)))
        return "\(pct)% of the term complete"
    }
    
    private var info: (hasSchedule: Bool, currentWeek: Int?, totalWeeks: Int?, progressPct: Double) {
            computeWeekInfo(
                startDateStr: course.start_date,
                endDateStr: course.end_date,
                graceDays: course.grace_days
            )
        }

    var body: some View {
            HStack(spacing: 16) {
                // Ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat((info.progressPct / 100)))
                        .stroke(brandColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack {
                        if let c = info.currentWeek, let t = info.totalWeeks {
                            Text("Week \(c)")
                                .font(.caption2.weight(.medium))
                            Text("of \(t)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Week")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("in progress")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(width: 76, height: 76)

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text("Term progress")
                        .font(.headline)
                    if let term = course.term {
                        Text(term)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    if info.hasSchedule, let c = info.currentWeek, let t = info.totalWeeks {
                        Text("\(Int(info.progressPct))% of the term complete")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(brandColor)
                    }

                    Text("EduLens uses your course schedule to keep you oriented in the term timeline.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
            )
        }
    }

// MARK: - Course card

struct CourseCard: View {
    @EnvironmentObject var appState: AppState
    let course: Course
    let brandColor: Color

    private var weeklyStatus: StudentWeeklyReflectionStatus? {
        appState.weeklyReflectionStatus.first(where: { $0.course_id == course.id })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(course.code)
                        .font(.subheadline.weight(.semibold))
                    if let title = course.title {
                        Text(title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                reflectionPill
            }

            HStack(spacing: 12) {
                Button {
                    NotificationCenter.default.post(name: .openChatForCourse, object: course.id)
                } label: {
                    Text("Open chat")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(brandColor.opacity(0.16))
                        )
                        .foregroundColor(brandColor)
                }

                Button {
                    NotificationCenter.default.post(name: .openAssignmentsForCourse, object: course.id)
                } label: {
                    Text("Open assignments")
                        .font(.footnote)
                        .foregroundColor(.primary)
                }

                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Reflection pill

    @ViewBuilder
    private var reflectionPill: some View {
        if let status = weeklyStatus {
            
            // Required & not required
            if !status.require_weekly_reflection {
                pillBackground(
                    label: "No reflection required",
                    textColor: .secondary,
                    bgColor: Color(.systemGray6),
                    icon: "minus.circle"
                )
            }
            
            // Required & submitted
            else if status.has_submitted {
                pillBackground(
                    label: "Reflection submitted",
                    textColor: .white,
                    bgColor: Color.green,
                    icon: "checkmark.seal.fill"
                )
            }
            
            // Required & DUE (not submitted)
            else {
                pillBackground(
                    label: "Reflection due this week",
                    textColor: .white,
                    bgColor: Color.orange,
                    icon: "exclamationmark.triangle.fill"
                )
            }
        } else {
            // No weekly reflection info at all
            pillBackground(
                label: "No weekly reflection",
                textColor: .secondary,
                bgColor: Color(.systemGray6),
                icon: nil
            )
        }
    }

    @ViewBuilder
    private func pillBackground(
        label: String,
        textColor: Color,
        bgColor: Color,
        icon: String?
    ) -> some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .imageScale(.small)
            }
            Text(label)
                .font(.caption2.weight(.semibold))
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(bgColor.opacity(bgColor == Color(.systemGray6) ? 1.0 : 0.9))
        )
        .foregroundColor(textColor)
    }

}


// MARK: - Notifications

extension Notification.Name {
    static let openChatForCourse = Notification.Name("EduLensOpenChatForCourse")
    static let openAssignmentsForCourse = Notification.Name("EduLensOpenAssignmentsForCourse")
}
