import Foundation

struct StudentWeeklyReflectionStatus: Identifiable, Decodable {
    var id: String { course_id }
    let course_id: String
    let course_code: String
    let course_title: String?
    let require_weekly_reflection: Bool
    let has_submitted: Bool
    let submitted_count: Int
    let last_submitted_at: String?
}

struct MultiCourseTodayTask: Identifiable, Decodable {
    let id: String
    let course_id: String?
    let course_code: String?
    let course_title: String?
    let title: String
    let description: String?
    let assignment_id: String?
    let due_date: String?
    let estimated_minutes: Int?
    let reason: String?
}

struct MultiCourseTodayResponse: Decodable {
    let generated_at: String
    let tasks: [MultiCourseTodayTask]
    let note: String
}
