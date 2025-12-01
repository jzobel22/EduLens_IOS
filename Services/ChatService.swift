import Foundation

struct RenameTitleRequest: Encodable {
    let title: String
}

enum ChatService {
    static func listChatSessions(accessToken: String) async throws -> [ChatSessionSummary] {
        // feature=chat to mirror WebUI
        try await APIClient.shared.request(
            "GET",
            path: "/sessions?feature=chat&limit=50",
            body: Optional<String>.none,
            accessToken: accessToken
        )
    }
    
    static func getTranscript(sessionId: String, accessToken: String) async throws -> TranscriptResponse {
        try await APIClient.shared.request(
            "GET",
            path: "/sessions/\(sessionId)/transcript",
            body: Optional<String>.none,
            accessToken: accessToken
        )
    }
    
    static func sendMessage(
        payload: ChatRequestBody,
        accessToken: String
    ) async throws -> ChatResponseBody {
        try await APIClient.shared.request(
            "POST",
            path: "/ai/chat",
            body: payload,
            accessToken: accessToken
        )
    }
    
    static func renameSession(
        sessionId: String,
        newTitle: String,
        accessToken: String
    ) async throws {
        let body = RenameTitleRequest(title: newTitle)
        // We don't care about the body of the response, just success/failure
        let _: EmptyResponse = try await APIClient.shared.request(
            "PATCH",
            path: "/sessions/\(sessionId)/title",
            body: body,
            accessToken: accessToken
        )
    }
}
