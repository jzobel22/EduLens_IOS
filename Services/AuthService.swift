import Foundation

struct DevLoginRequest: Encodable {
    let email: String
    let role: String
    let secret: String?
}

enum AuthService {

    /// Dev login (student by default) using /auth/dev-login.
    /// If your backend requires a pilot password, pass it via `secret`.
    static func devLogin(
        email: String,
        role: String = "student",
        secret: String? = nil
    ) async throws -> TokenResponse {
        let body = DevLoginRequest(email: email, role: role, secret: secret)
        return try await APIClient.shared.request(
            "POST",
            path: "/auth/dev-login",
            body: body,
            accessToken: nil,
            requiresAuth: false
        )
    }

    /// Convenience: login + store Keychain-backed tokens + optional /me validation.
    @MainActor
    static func devLoginAndStoreSession(
        appState: AppState,
        email: String,
        role: String = "student",
        secret: String? = nil,
        validateMe: Bool = true
    ) async throws {
        let tokens = try await devLogin(email: email, role: role, secret: secret)
        appState.applyTokenResponse(tokens, email: email)

        if validateMe {
            await appState.validateSessionWithMe()
        }
    }

    @MainActor
    static func logout(appState: AppState) async {
        // Best-effort server logout (ignore failures)
        do {
            let _: EmptyResponse = try await APIClient.shared.request(
                "POST",
                path: "/auth/logout",
                body: nil as EmptyBody?,
                accessToken: nil,
                requiresAuth: true
            )
        } catch {
            // ignore
        }

        appState.logout(reason: nil)
    }
}

private struct EmptyBody: Encodable {}
