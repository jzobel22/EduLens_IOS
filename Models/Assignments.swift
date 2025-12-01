import Foundation

struct StudentLMSAssignment: Identifiable, Decodable {
    let id: String
    let title: String
    let description: String?
    let due_at: String?
    let points: Double?

    enum CodingKeys: String, CodingKey {
        case id, title, description, due_at, points
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // id can be string or number coming from LMS
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let n = try? c.decode(Int.self, forKey: .id) {
            id = String(n)
        } else {
            id = UUID().uuidString
        }

        title = (try? c.decode(String.self, forKey: .title)) ?? "Untitled assignment"
        description = try? c.decode(String.self, forKey: .description)
        due_at = try? c.decode(String.self, forKey: .due_at)
        if let p = try? c.decode(Double.self, forKey: .points) {
            points = p
        } else if let i = try? c.decode(Int.self, forKey: .points) {
            points = Double(i)
        } else {
            points = nil
        }
    }
}

struct StudentCourseLMSAssignments: Decodable {
    let course_id: String
    let external_lms_type: String?
    let external_lms_id: String?
    let assignments: [StudentLMSAssignment]
}

struct AssignmentPlanResponse: Decodable {
    let course_id: String
    let assignment: StudentLMSAssignment
    let plan_markdown: String
}

struct AssignmentPlanRequestBody: Encodable {
    let assignment_id: String
    let hours_available: Double?
    let notes: String?
}
