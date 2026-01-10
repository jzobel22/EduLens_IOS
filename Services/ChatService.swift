import Foundation

// MARK: - Requests

struct RenameTitleRequest: Encodable {
    let title: String
}

// MARK: - ChatService

enum ChatService {

    // MARK: - Sessions

    /// List chat sessions (mirrors WebUI behavior).
    /// Uses APIClient token hooks; no explicit access token required.
    static func listChatSessions(limit: Int = 50) async throws -> [ChatSessionSummary] {
        try await APIClient.shared.request(
            "GET",
            path: "/sessions?feature=chat&limit=\(limit)",
            body: Optional<String>.none,
            accessToken: nil,
            requiresAuth: true
        )
    }

    /// Backward-compatible overload
    static func listChatSessions(accessToken: String) async throws -> [ChatSessionSummary] {
        try await listChatSessions()
    }

    // MARK: - Transcript

    static func getTranscript(sessionId: String) async throws -> TranscriptResponse {
        try await APIClient.shared.request(
            "GET",
            path: "/sessions/\(sessionId)/transcript",
            body: Optional<String>.none,
            accessToken: nil,
            requiresAuth: true
        )
    }

    /// Backward-compatible overload
    static func getTranscript(sessionId: String, accessToken: String) async throws -> TranscriptResponse {
        try await getTranscript(sessionId: sessionId)
    }

    // MARK: - Send message

    /// Send a chat message to the AI.
    /// APIClient will attach Authorization and refresh on 401 automatically.
    static func sendMessage(payload: ChatRequestBody) async throws -> ChatResponseBody {
        try await APIClient.shared.request(
            "POST",
            path: "/ai/chat",
            body: payload,
            accessToken: nil,
            requiresAuth: true
        )
    }

    /// Backward-compatible overload
    static func sendMessage(
        payload: ChatRequestBody,
        accessToken: String
    ) async throws -> ChatResponseBody {
        try await sendMessage(payload: payload)
    }

    // MARK: - Rename session

    static func renameSession(
        sessionId: String,
        newTitle: String
    ) async throws {
        let body = RenameTitleRequest(title: newTitle)
        let _: EmptyResponse = try await APIClient.shared.request(
            "PATCH",
            path: "/sessions/\(sessionId)/title",
            body: body,
            accessToken: nil,
            requiresAuth: true
        )
    }

    /// Backward-compatible overload
    static func renameSession(
        sessionId: String,
        newTitle: String,
        accessToken: String
    ) async throws {
        try await renameSession(sessionId: sessionId, newTitle: newTitle)
    }
}
