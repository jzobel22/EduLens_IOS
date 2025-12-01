import Foundation

struct ChatSessionSummary: Identifiable, Decodable {
    let id: String
    let started_at: String
    let ended_at: String?
    let feature: String
    let model_tier: String
    let save_content: Bool
    let title: String?

    // Extra fields returned by backend list_sessions (not in Pydantic model)
    let has_reflection: Bool?
    let reflection_text: String?
    let submitted_reflection: Bool?
    let course_id: String?
    let course_code: String?
    let course_title: String?

    // Allow decoding unknown keys gracefully
    private enum CodingKeys: String, CodingKey {
        case id, started_at, ended_at, feature, model_tier, save_content, title
        case has_reflection, reflection_text, submitted_reflection
        case course_id, course_code, course_title
    }
}

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

struct TranscriptMessage: Identifiable, Decodable {
    let id = UUID()
    let role: String
    let content: String
    let ts: String
}

struct TranscriptResponse: Decodable {
    let session_id: String
    let messages: [TranscriptMessage]
}
