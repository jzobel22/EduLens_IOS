import Foundation

enum StudentService {

    // MARK: - Core student context

    /// Branding is public-ish; does not require auth on many stacks, but safe to treat as authed.
    /// Uses APIClient token hooks, so no accessToken parameter needed.
    static func fetchBranding() async throws -> Branding {
        try await APIClient.shared.request(
            "GET",
            path: "/branding",
            body: Optional<String>.none,
            accessToken: nil,
            requiresAuth: true
        )
    }

    static func fetchMyCourses() async throws -> [Course] {
        try await APIClient.shared.request(
            "GET",
            path: "/my/courses",
            body: Optional<String>.none,
            accessToken: nil,
            requiresAuth: true
        )
    }

    static func fetchWeeklyReflectionStatus() async throws -> [StudentWeeklyReflectionStatus] {
        try await APIClient.shared.request(
            "GET",
            path: "/student/reflections/weekly_status",
            body: Optional<String>.none,
            accessToken: nil,
            requiresAuth: true
        )
    }

    static func fetchTodayAllCourses() async throws -> MultiCourseTodayResponse {
        try await APIClient.shared.request(
            "GET",
            path: "/agent/students/today_all_courses",
            body: Optional<String>.none,
            accessToken: nil,
            requiresAuth: true
        )
    }

    // MARK: - Backward-compatible overloads (so you don't have to update every call site yet)

    static func fetchBranding(accessToken: String) async throws -> Branding {
        try await fetchBranding()
    }

    static func fetchMyCourses(accessToken: String) async throws -> [Course] {
        try await fetchMyCourses()
    }

    static func fetchWeeklyReflectionStatus(accessToken: String) async throws -> [StudentWeeklyReflectionStatus] {
        try await fetchWeeklyReflectionStatus()
    }

    static func fetchTodayAllCourses(accessToken: String) async throws -> MultiCourseTodayResponse {
        try await fetchTodayAllCourses()
    }

    // MARK: - Assignments (LMS)

    /// IMPORTANT NOTE:
    /// Your backend zip you sent earlier appears to scope LMS assignment endpoints under faculty routes,
    /// and may not expose these student endpoints anymore. We'll keep these methods, but expect 404/403
    /// until we align iOS + backend for student assignment access.
    static func fetchAssignments(courseId: String) async throws -> StudentCourseLMSAssignments {
        try await APIClient.shared.request(
            "GET",
            path: "/student/courses/\(courseId)/lms_assignments",
            body: Optional<String>.none,
            accessToken: nil,
            requiresAuth: true
        )
    }

    static func generateAssignmentPlan(
        courseId: String,
        assignmentId: String
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
            accessToken: nil,
            requiresAuth: true
        )
    }

    // MARK: - Backward-compatible overloads for Assignments

    static func fetchAssignments(courseId: String, accessToken: String) async throws -> StudentCourseLMSAssignments {
        try await fetchAssignments(courseId: courseId)
    }

    static func generateAssignmentPlan(
        courseId: String,
        assignmentId: String,
        accessToken: String
    ) async throws -> AssignmentPlanResponse {
        try await generateAssignmentPlan(courseId: courseId, assignmentId: assignmentId)
    }
}
