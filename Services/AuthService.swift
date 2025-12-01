import Foundation

struct DevLoginRequest: Encodable {
    let email: String
    let role: String
}

enum AuthService {
    static func devLogin(email: String) async throws -> TokenResponse {
        let body = DevLoginRequest(email: email, role: "student")
        return try await APIClient.shared.request(
            "POST",
            path: "/auth/dev-login",
            body: body,
            accessToken: nil
        )
    }
}
