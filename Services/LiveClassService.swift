import Foundation

enum LiveClassService {

    // MARK: - Signals

    static func listSignals(courseId: String, sessionDate: String, limit: Int = 200) async throws -> [LiveSignalOut] {
        let q = "?course_id=\(courseId)&day=\(sessionDate)&limit=\(limit)"
        return try await APIClient.shared.request(
            "GET",
            path: "/student/live/signals\(q)",
            body: Optional<String>.none,
            accessToken: nil,
            requiresAuth: true
        )
    }

    static func createSignal(courseId: String, type: LiveSignalType, note: String?, sessionDate: String?) async throws -> LiveSignalOut {
        let body = LiveSignalCreateBody(
            course_id: courseId,
            signal_type: type,
            note_text: note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            session_date: sessionDate
        )
        return try await APIClient.shared.request(
            "POST",
            path: "/student/live/signals",
            body: body,
            accessToken: nil,
            requiresAuth: true
        )
    }

    static func updateSignal(signalId: String, resolution: LiveResolutionState?, note: String?) async throws -> LiveSignalOut {
        let body = LiveSignalUpdateBody(
            note_text: note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            resolution_state: resolution
        )
        return try await APIClient.shared.request(
            "PATCH",
            path: "/student/live/signals/\(signalId)",
            body: body,
            accessToken: nil,
            requiresAuth: true
        )
    }

    // MARK: - Scratchpad

    static func saveScratchpad(courseId: String, sessionDate: String?, text: String?) async throws -> LiveRecapOut {
        let body = LiveScratchpadUpdateBody(
            course_id: courseId,
            session_date: sessionDate,
            scratchpad_text: text?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return try await APIClient.shared.request(
            "PATCH",
            path: "/student/live/scratchpad",
            body: body,
            accessToken: nil,
            requiresAuth: true
        )
    }

    // MARK: - Recap

    /// Backend returns `null` when no recap exists yet.
    static func getRecap(courseId: String, sessionDate: String) async throws -> LiveRecapOut? {
        let q = "?course_id=\(courseId)&session_date=\(sessionDate)"
        return try await APIClient.shared.request(
            "GET",
            path: "/student/live/recap\(q)",
            body: Optional<String>.none,
            accessToken: nil,
            requiresAuth: true
        )
    }

    static func generateRecap(courseId: String, sessionDate: String?, useAI: Bool, mode: String = "mini") async throws -> LiveRecapOut {
        let body = LiveRecapRequestBody(
            course_id: courseId,
            session_date: sessionDate,
            use_ai: useAI,
            mode: mode
        )
        return try await APIClient.shared.request(
            "POST",
            path: "/student/live/recap",
            body: body,
            accessToken: nil,
            requiresAuth: true
        )
    }

    // MARK: - Context (today only)

    static func getContext(courseId: String) async throws -> LiveContextOut {
        let q = "?course_id=\(courseId)"
        return try await APIClient.shared.request(
            "GET",
            path: "/student/live/context\(q)",
            body: Optional<String>.none,
            accessToken: nil,
            requiresAuth: true
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
