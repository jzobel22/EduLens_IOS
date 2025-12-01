import Foundation

enum StudentService {
    static func fetchBranding(accessToken: String) async throws -> Branding {
        try await APIClient.shared.request(
            "GET",
            path: "/branding",
            body: Optional<String>.none,
            accessToken: accessToken
        )
    }

    static func fetchMyCourses(accessToken: String) async throws -> [Course] {
        try await APIClient.shared.request(
            "GET",
            path: "/my/courses",
            body: Optional<String>.none,
            accessToken: accessToken
        )
    }

    static func fetchWeeklyReflectionStatus(accessToken: String) async throws -> [StudentWeeklyReflectionStatus] {
        try await APIClient.shared.request(
            "GET",
            path: "/student/reflections/weekly_status",
            body: Optional<String>.none,
            accessToken: accessToken
        )
    }

    static func fetchTodayAllCourses(accessToken: String) async throws -> MultiCourseTodayResponse {
        try await APIClient.shared.request(
            "GET",
            path: "/agent/students/today_all_courses",
            body: Optional<String>.none,
            accessToken: accessToken
        )
    }

    // MARK: - Assignments (LMS)

    static func fetchAssignments(
        courseId: String,
        accessToken: String
    ) async throws -> StudentCourseLMSAssignments {
        try await APIClient.shared.request(
            "GET",
            path: "/student/courses/\(courseId)/lms_assignments",
            body: Optional<String>.none,
            accessToken: accessToken
        )
    }

    static func generateAssignmentPlan(
        courseId: String,
        assignmentId: String,
        accessToken: String
    ) async throws -> AssignmentPlanResponse {

        let body = AssignmentPlanRequestBody(
            assignment_id: assignmentId,
            hours_available: nil,
            notes: nil
        )

        return try await APIClient.shared.request(
            "POST",
            path: "/student/courses/\(courseId)/assignment_plan",
            body: body,
            accessToken: accessToken
        )
    }
}
