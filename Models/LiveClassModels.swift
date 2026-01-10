import Foundation

// Backend literals in schemas.py:
// LiveSignalType = Literal["key","confused","important","connection"]
// LiveResolutionState = Optional[Literal["resolved","still_unclear"]]

enum LiveSignalType: String, Codable, CaseIterable, Identifiable {
    case key
    case confused
    case important
    case connection

    var id: String { rawValue }

    var label: String {
        switch self {
        case .key: return "Key point"
        case .confused: return "Confused"
        case .important: return "Important"
        case .connection: return "Connection"
        }
    }

    var systemImage: String {
        switch self {
        case .key: return "key.fill"
        case .confused: return "questionmark.circle.fill"
        case .important: return "exclamationmark.triangle.fill"
        case .connection: return "link"
        }
    }
}

enum LiveResolutionState: String, Codable, Identifiable {
    case resolved
    case stillUnclear = "still_unclear"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .resolved: return "Resolved"
        case .stillUnclear: return "Still unclear"
        }
    }
}

struct LiveSignalCreateBody: Encodable {
    let course_id: String
    let signal_type: LiveSignalType
    let note_text: String?
    let session_date: String?
}

struct LiveSignalUpdateBody: Encodable {
    let note_text: String?
    let resolution_state: LiveResolutionState?
}

struct LiveSignalOut: Identifiable, Decodable {
    let id: String
    let course_id: String
    let signal_type: LiveSignalType
    let note_text: String?
    let created_at: String
    let resolution_state: LiveResolutionState?
    let resolved_at: String?
}

struct LiveScratchpadUpdateBody: Encodable {
    let course_id: String
    let session_date: String?
    let scratchpad_text: String?
}

struct LiveRecapRequestBody: Encodable {
    let course_id: String
    let session_date: String?
    let use_ai: Bool?
    let mode: String?   // "mini" or "deep" (backend ModelTier)
}

struct LiveRecapOut: Identifiable, Decodable {
    let id: String
    let course_id: String
    let session_date: String
    let recap_text: String
    let open_confusions: Int
    let created_at: String
    let updated_at: String?

    let scratchpad_text: String?

    let token_in: Int?
    let token_out: Int?
    let model_tier: String?
    let ai_mode: String?
}

struct LMSAssignmentSummary: Decodable, Identifiable {
    // Backend schemas.py
    // title, description?, due_at?
    var id: String { "\(title)|\(due_at ?? "")" }

    let title: String
    let description: String?
    let due_at: String?
}

struct LiveContextOut: Decodable {
    let course_id: String
    let session_date: String
    let unresolved_confusions_today: Int
    let upcoming_assignments: [LMSAssignmentSummary]
}
