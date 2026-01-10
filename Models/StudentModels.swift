import Foundation

// MARK: - Weekly reflection status

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

// MARK: - "Today across courses" planning

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

    private enum CodingKeys: String, CodingKey {
        case id
        case course_id, course_code, course_title
        case title, description
        case assignment_id, due_date
        case estimated_minutes, reason
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // id may be missing (older backend), string, or number
        if let s = try? c.decode(String.self, forKey: .id), !s.isEmpty {
            id = s
        } else if let n = try? c.decode(Int.self, forKey: .id) {
            id = String(n)
        } else {
            // Fallback stable-ish id
            let courseId = (try? c.decodeIfPresent(String.self, forKey: .course_id)) ?? ""
            let title = (try? c.decode(String.self, forKey: .title)) ?? "Task"
            let due = (try? c.decodeIfPresent(String.self, forKey: .due_date)) ?? ""
            let base = "\(courseId)|\(title)|\(due)"
            id = "task_" + String(base.hashValue)
        }

        course_id = try? c.decodeIfPresent(String.self, forKey: .course_id)
        course_code = try? c.decodeIfPresent(String.self, forKey: .course_code)
        course_title = try? c.decodeIfPresent(String.self, forKey: .course_title)

        title = (try? c.decode(String.self, forKey: .title)) ?? "Task"
        description = try? c.decodeIfPresent(String.self, forKey: .description)

        assignment_id = try? c.decodeIfPresent(String.self, forKey: .assignment_id)
        due_date = try? c.decodeIfPresent(String.self, forKey: .due_date)

        estimated_minutes = try? c.decodeIfPresent(Int.self, forKey: .estimated_minutes)
        reason = try? c.decodeIfPresent(String.self, forKey: .reason)
    }

    // Convenience (UI-only)
    var courseDisplay: String {
        let code = (course_code ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (course_title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !code.isEmpty, !title.isEmpty { return "\(code) • \(title)" }
        if !code.isEmpty { return code }
        if !title.isEmpty { return title }
        return "Course"
    }
}

struct MultiCourseTodayResponse: Decodable {
    let generated_at: String?
    let tasks: [MultiCourseTodayTask]
    let note: String

    var generatedAtDisplay: String { generated_at ?? "" }
}
