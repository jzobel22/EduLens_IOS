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

        let decodedTitle = (try? c.decode(String.self, forKey: .title)) ?? "Untitled assignment"
        let decodedDue = try? c.decode(String.self, forKey: .due_at)

        // id can be string or number coming from LMS
        if let s = try? c.decode(String.self, forKey: .id), !s.isEmpty {
            id = s
        } else if let n = try? c.decode(Int.self, forKey: .id) {
            id = String(n)
        } else {
            // Stable fallback ID (prevents List jitter / duplicates)
            id = StudentLMSAssignment.stableFallbackId(title: decodedTitle, dueAt: decodedDue)
        }

        title = decodedTitle
        description = try? c.decode(String.self, forKey: .description)
        due_at = decodedDue

        if let p = try? c.decode(Double.self, forKey: .points) {
            points = p
        } else if let i = try? c.decode(Int.self, forKey: .points) {
            points = Double(i)
        } else {
            points = nil
        }
    }

    // MARK: - UI helpers (non-breaking)

    var dueDate: Date? {
        guard let due_at else { return nil }
        return StudentLMSAssignment.parseDate(due_at)
    }

    var pointsDisplay: String? {
        guard let points else { return nil }
        if points.rounded(.towardZero) == points {
            return "\(Int(points)) pts"
        }
        return "\(points) pts"
    }

    // MARK: - Private helpers

    private static func stableFallbackId(title: String, dueAt: String?) -> String {
        // Deterministic (no CryptoKit required)
        let base = "\(title.lowercased())|\(dueAt ?? "")"
        return "fallback_" + String(base.hashValue)
    }

    private static func parseDate(_ value: String) -> Date? {
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
