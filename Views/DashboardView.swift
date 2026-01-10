import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    @State private var loadingToday: Bool = false
    @State private var todayError: String? = nil
    @State private var hasAppeared: Bool = false

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
            if !hasAppeared { hasAppeared = true }
            // MainShellView now hydrates branding/courses/weekly/today.
            // Dashboard should be lightweight and not re-fetch unless user taps.
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
            } else {
                EmptyView()
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
            .disabled(loadingToday || !appState.isAuthenticated)
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

            if !appState.isAuthenticated {
                Text("Please sign in to view your courses.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else if appState.courses.isEmpty {
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

    // MARK: - Actions

    private func generateToday() async {
        guard appState.isAuthenticated else { return }

        loadingToday = true
        todayError = nil
        defer { loadingToday = false }

        do {
            let resp = try await StudentService.fetchTodayAllCourses()
            appState.todayAllCourses = resp
        } catch {
            todayError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Term progress card

struct TermProgressCard: View {
    let course: Course
    let brandColor: Color

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

                if info.hasSchedule, let _ = info.currentWeek, let _ = info.totalWeeks {
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

    // MARK: - File-local date helpers to avoid duplicate symbols

    private func computeWeekInfo(
        startDateStr: String?,
        endDateStr: String?,
        graceDays: Int?
    ) -> (hasSchedule: Bool, currentWeek: Int?, totalWeeks: Int?, progressPct: Double) {

        guard let startStr = startDateStr,
              let endStr = endDateStr,
              let start = parseDate(startStr),
              let end = parseDate(endStr)
        else {
            return (false, nil, nil, 0)
        }

        let grace = graceDays ?? 0
        let cutoff = Calendar.current.date(byAdding: .day, value: grace, to: end) ?? end

        let secondsPerWeek = 7.0 * 24.0 * 60.0 * 60.0

        let totalWeeksRaw = cutoff.timeIntervalSince(start) / secondsPerWeek
        let totalWeeks = max(1, Int(round(totalWeeksRaw)))

        let today = Date()
        let currentWeek: Int
        if today < start {
            currentWeek = 1
        } else if today > cutoff {
            currentWeek = totalWeeks
        } else {
            let elapsed = today.timeIntervalSince(start) / secondsPerWeek
            currentWeek = min(totalWeeks, max(1, Int(floor(elapsed)) + 1))
        }

        let pct = min(100, max(0, (Double(currentWeek) / Double(totalWeeks)) * 100))
        return (true, currentWeek, totalWeeks, pct)
    }

    private func parseDate(_ value: String) -> Date? {
        // First ISO8601 (common backend format)
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: value) { return d }

        // Then common fallback formats
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
            if !status.require_weekly_reflection {
                pillBackground(
                    label: "No reflection required",
                    textColor: .secondary,
                    bgColor: Color(.systemGray6),
                    icon: "minus.circle"
                )
            } else if status.has_submitted {
                pillBackground(
                    label: "Reflection submitted",
                    textColor: .white,
                    bgColor: Color.green,
                    icon: "checkmark.seal.fill"
                )
            } else {
                pillBackground(
                    label: "Reflection due this week",
                    textColor: .white,
                    bgColor: Color.orange,
                    icon: "exclamationmark.triangle.fill"
                )
            }
        } else {
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
