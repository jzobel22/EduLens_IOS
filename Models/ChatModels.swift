import Foundation

// MARK: - Session summary

struct ChatSessionSummary: Identifiable, Decodable {
    let id: String
    let started_at: String
    let ended_at: String?
    let feature: String?
    let model_tier: String?
    let save_content: Bool?
    let title: String?

    // Extra fields returned by backend list_sessions (not in Pydantic model)
    let has_reflection: Bool?
    let reflection_text: String?
    let submitted_reflection: Bool?
    let course_id: String?
    let course_code: String?
    let course_title: String?

    private enum CodingKeys: String, CodingKey {
        case id, started_at, ended_at, feature, model_tier, save_content, title
        case has_reflection, reflection_text, submitted_reflection
        case course_id, course_code, course_title
    }

    // Convenience (UI-only)
    var courseDisplay: String? {
        if let code = course_code, !code.isEmpty { return code }
        if let title = course_title, !title.isEmpty { return title }
        return nil
    }

    var startedAtDate: Date? {
        Self.parseDate(started_at)
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

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

// MARK: - Chat request/response

struct ChatRequestBody: Encodable {
    var session_id: String?
    var course_id: String?
    var week: Int?
    var message: String
    var mode: String = "mini"
    var private_mode: Bool = false
}

struct ChatResponseBody: Decodable {
    let session_id: String
    let reply: String
    let token_in: Int
    let token_out: Int
    let model_tier: String
    let reflection_suggestion: String?
    let resolved_week: Int?
}

// MARK: - Transcript

struct TranscriptMessage: Identifiable, Decodable {
    let role: String
    let content: String
    let ts: String

    /// Stable-ish ID so SwiftUI list diffs don't churn on every reload.
    /// If you later add a backend message_id, switch to that.
    var id: String {
        // NOTE: hashValue is not guaranteed stable across launches, but is stable within a run,
        // which is what SwiftUI diffing needs during a view session.
        let base = "\(role)|\(ts)|\(content)"
        return "msg_" + String(base.hashValue)
    }

    var isUser: Bool { role == "user" }
}

struct TranscriptResponse: Decodable {
    let session_id: String
    let messages: [TranscriptMessage]
}
