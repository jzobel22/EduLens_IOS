import SwiftUI

struct AssignmentsView: View {
    @EnvironmentObject var appState: AppState

    @State private var isLoading: Bool = false
    @State private var loadError: String? = nil
    @State private var assignments: [StudentLMSAssignment] = []

    @State private var selectedAssignment: StudentLMSAssignment? = nil
    @State private var isPlanning: Bool = false
    @State private var planText: String? = nil
    @State private var planError: String? = nil
    @State private var showPlanSheet: Bool = false

    private var brandColor: Color {
        Color(hex: appState.branding?.primary_color) ?? .accentColor
    }

    var body: some View {
        NavigationStack {
            Group {
                if let course = appState.selectedCourse {
                    content(for: course)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Assignments")
                            .font(.title2.bold())
                        Text("Select a course on the dashboard to view its assignments and AI study plans.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Assignments")
        }
        .onAppear {
            Task { await loadIfNeeded() }
        }
        .sheet(isPresented: $showPlanSheet) {
            AssignmentPlanSheet(
                assignment: selectedAssignment,
                planText: planText,
                isPlanning: isPlanning,
                errorText: planError,
                brandColor: brandColor,
                onClose: { showPlanSheet = false }
            )
        }
    }

    // MARK: - Main content

    private func content(for course: Course) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Assignments for \(course.code)")
                    .font(.title3.bold())
                if let title = course.title {
                    Text(title)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading assignments from your LMS…")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } else if let err = loadError {
                Text(err)
                    .font(.footnote)
                    .foregroundColor(.red)
            } else if assignments.isEmpty {
                Text("No upcoming assignments were found for this course in the connected LMS.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                List {
                    ForEach(assignments) { a in
                        AssignmentRow(
                            assignment: a,
                            brandColor: brandColor,
                            onPlan: {
                                Task { await plan(for: a) }
                            }
                        )
                    }
                }
                .listStyle(.insetGrouped)
            }

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Data loading

    private func loadIfNeeded() async {
        guard let token = appState.accessToken else { return }
        guard let course = appState.selectedCourse else { return }

        isLoading = true
        loadError = nil
        do {
            let resp = try await StudentService.fetchAssignments(
                courseId: course.id,
                accessToken: token
            )
            await MainActor.run {
                assignments = resp.assignments
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

    private func plan(for assignment: StudentLMSAssignment) async {
        guard let token = appState.accessToken,
              let course = appState.selectedCourse else { return }

        await MainActor.run {
            selectedAssignment = assignment
            planText = nil
            planError = nil
            isPlanning = true
            showPlanSheet = true   // show sheet AFTER assignment is set
        }

        do {
            let res = try await StudentService.generateAssignmentPlan(
                courseId: course.id,
                assignmentId: assignment.id,
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

// MARK: - Row

struct AssignmentRow: View {
    let assignment: StudentLMSAssignment
    let brandColor: Color
    let onPlan: () -> Void

    private var dueText: String {
        guard let dueStr = assignment.due_at,
              let date = parseCourseDate(dueStr) else {
            return "No due date"
        }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return "Due \(df.string(from: date))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(assignment.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Text(dueText)
                .font(.caption)
                .foregroundColor(.secondary)

            if let desc = assignment.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
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

// MARK: - Plan sheet

struct AssignmentPlanSheet: View {
    let assignment: StudentLMSAssignment?
    let planText: String?
    let isPlanning: Bool
    let errorText: String?
    let brandColor: Color
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {

                if let assignment = assignment {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assignment.title)
                            .font(.headline)
                        if let desc = assignment.description, !desc.isEmpty {
                            Text(desc)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                } else {
                    Text("Preparing assignment…")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Divider()

                if isPlanning {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Generating a study plan…")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } else if let err = errorText {
                    Text(err)
                        .font(.footnote)
                        .foregroundColor(.red)
                } else if let plan = planText {
                    ScrollView {
                        Text(plan)
                            .font(.footnote)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.primary)
                            .padding(.top, 4)
                    }
                } else {
                    Text("Tap “Plan work” on an assignment to generate a plan.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("Study plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onClose() }
                }
            }
        }
    }
}
