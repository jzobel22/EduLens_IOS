import Foundation

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case invalidURL(String)
    case transport(Error)
    case notHTTPResponse
    case httpError(status: Int, body: String, requestId: String?)
    case decodingError(String)
    case unauthenticated
    case refreshFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let s):
            return "Invalid API URL: \(s)"
        case .transport(let e):
            return "Network error: \(e.localizedDescription)"
        case .notHTTPResponse:
            return "No HTTP response."
        case .httpError(let status, let body, let requestId):
            if let requestId, !requestId.isEmpty {
                return "HTTP \(status) (request_id=\(requestId)): \(body)"
            }
            return "HTTP \(status): \(body)"
        case .decodingError(let msg):
            return "Failed to decode server response: \(msg)"
        case .unauthenticated:
            return "You are not authenticated. Please log in again."
        case .refreshFailed(let msg):
            return "Session refresh failed: \(msg)"
        case .unknown(let msg):
            return msg
        }
    }
}

// MARK: - Response helpers

struct EmptyResponse: Decodable {}

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { _encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}

// MARK: - Token provider / refresher

/// APIClient stays UI-agnostic: it asks for tokens via closures.
/// Wire these closures in AppState (or a dedicated AuthStore) when you update that next.
struct APITokenHooks {
    /// Return the current access token (if any).
    var getAccessToken: () -> String?
    /// Return the current refresh token (if any).
    var getRefreshToken: () -> String?
    /// Persist newly issued tokens.
    var setTokens: (_ access: String, _ refresh: String) -> Void
    /// Clear tokens (e.g., refresh failed).
    var clearTokens: () -> Void

    static let none = APITokenHooks(
        getAccessToken: { nil },
        getRefreshToken: { nil },
        setTokens: { _, _ in },
        clearTokens: {}
    )
}

// MARK: - APIClient

final class APIClient {
    static let shared = APIClient()
    private init() {}

    /// Optional auth hooks. Set this once at app startup.
    /// Example in your App init / AppState init:
    /// APIClient.shared.tokenHooks = ...
    var tokenHooks: APITokenHooks = .none

    /// Set true during local debugging if you want request logging.
    var enableDebugLogging: Bool = false

    /// Prevent concurrent refresh stampedes.
    private let refreshLock = AsyncLock()

    // MARK: Public request API

    /// Standard JSON request. Adds Authorization automatically if available.
    /// If a request returns 401, it will attempt a single refresh + retry once.
    func request<T: Decodable>(
        _ method: String,
        path: String,
        body: Encodable? = nil,
        accessToken: String? = nil,
        requiresAuth: Bool = true,
        timeout: TimeInterval = 30
    ) async throws -> T {

        // Attempt 1
        do {
            return try await performRequest(
                method,
                path: path,
                body: body,
                accessToken: accessToken,
                requiresAuth: requiresAuth,
                timeout: timeout
            )
        } catch let err as APIError {
            // If 401 and we have refresh token -> refresh once and retry.
            if case .httpError(let status, _, _) = err, status == 401 {
                let refreshed = try await refreshIfPossible()
                if refreshed {
                    return try await performRequest(
                        method,
                        path: path,
                        body: body,
                        accessToken: tokenHooks.getAccessToken(),
                        requiresAuth: requiresAuth,
                        timeout: timeout
                    )
                } else {
                    throw APIError.unauthenticated
                }
            }
            throw err
        } catch {
            throw error
        }
    }

    // MARK: - Core request implementation

    private func performRequest<T: Decodable>(
        _ method: String,
        path: String,
        body: Encodable?,
        accessToken: String?,
        requiresAuth: Bool,
        timeout: TimeInterval
    ) async throws -> T {

        let url = edulensAPI(path)
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method.uppercased()

        // Headers
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        // Only set Content-Type when a JSON body is present.
        if body != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // Auth: prefer explicit token; else consult hooks (unless requiresAuth=false).
        let tokenToUse: String? = {
            if let accessToken, !accessToken.isEmpty { return accessToken }
            if requiresAuth { return tokenHooks.getAccessToken() }
            return nil
        }()

        if let tokenToUse {
            req.setValue("Bearer \(tokenToUse)", forHTTPHeaderField: "Authorization")
        } else if requiresAuth {
            // If auth required but no token, fail fast to avoid confusing 401s.
            throw APIError.unauthenticated
        }

        // Body
        if let body {
            do {
                req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
            } catch {
                throw APIError.unknown("Failed to encode request body: \(error.localizedDescription)")
            }
        }

        if enableDebugLogging {
            debugLogRequest(req)
        }

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.transport(error)
        }

        guard let http = resp as? HTTPURLResponse else {
            throw APIError.notHTTPResponse
        }

        let requestId = http.value(forHTTPHeaderField: "x-request-id")
            ?? http.value(forHTTPHeaderField: "x-requestid")
            ?? http.value(forHTTPHeaderField: "request-id")

        if enableDebugLogging {
            debugLogResponse(http: http, data: data, requestId: requestId)
        }

        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(status: http.statusCode, body: text, requestId: requestId)
        }

        // Empty response support
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        // Some endpoints may return 204 with no body; treat as EmptyResponse only.
        if data.isEmpty {
            throw APIError.decodingError("Empty response body for \(T.self)")
        }

        let decoder = JSONDecoder()
        // If you later adopt ISO dates from backend, you can switch to .iso8601 here.
        decoder.keyDecodingStrategy = .useDefaultKeys

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let snippet = String(data: data.prefix(800), encoding: .utf8) ?? "<non-utf8>"
            throw APIError.decodingError("\(error.localizedDescription). Body snippet: \(snippet)")
        }
    }

    // MARK: - Refresh logic

    /// Attempts token refresh if refresh token exists.
    /// Returns true if refreshed and tokens updated.
    private func refreshIfPossible() async throws -> Bool {
        // Ensure only one refresh call is active at a time.
        try await refreshLock.withLock {
            // Another request may have refreshed while we waited.
            // If access token exists, we can proceed (best-effort).
            if let access = tokenHooks.getAccessToken(), !access.isEmpty {
                return true
            }

            guard let refresh = tokenHooks.getRefreshToken(), !refresh.isEmpty else {
                return false
            }

            // Call backend refresh endpoint.
            // IMPORTANT: refresh should NOT attach Bearer (and should not requireAuth).
            struct RefreshBody: Encodable { let refresh_token: String }
            struct RefreshResp: Decodable {
                let access_token: String
                let refresh_token: String?
            }

            do {
                let resp: RefreshResp = try await performRequest(
                    "POST",
                    path: "/auth/refresh",
                    body: RefreshBody(refresh_token: refresh),
                    accessToken: nil,
                    requiresAuth: false,
                    timeout: 30
                )

                let newAccess = resp.access_token
                let newRefresh = resp.refresh_token ?? refresh
                if newAccess.isEmpty {
                    tokenHooks.clearTokens()
                    throw APIError.refreshFailed("Server returned empty access_token.")
                }
                tokenHooks.setTokens(newAccess, newRefresh)
                return true
            } catch {
                tokenHooks.clearTokens()
                if let e = error as? APIError {
                    throw e
                }
                throw APIError.refreshFailed(error.localizedDescription)
            }
        }
    }

    // MARK: - Debug logging

    private func debugLogRequest(_ req: URLRequest) {
        let url = req.url?.absoluteString ?? "<nil>"
        let method = req.httpMethod ?? "<nil>"
        print("[API] \(method) \(url)")
        if let headers = req.allHTTPHeaderFields, !headers.isEmpty {
            // Do not print Authorization.
            let scrubbed = headers.mapValues { key in key }
            var safe = scrubbed
            safe.removeValue(forKey: "Authorization")
            print("[API] headers: \(safe)")
        }
        if let body = req.httpBody, !body.isEmpty,
           let s = String(data: body, encoding: .utf8) {
            print("[API] body: \(s.prefix(1200))")
        }
    }

    private func debugLogResponse(http: HTTPURLResponse, data: Data, requestId: String?) {
        let code = http.statusCode
        let url = http.url?.absoluteString ?? "<nil>"
        if let requestId, !requestId.isEmpty {
            print("[API] ← \(code) \(url) (request_id=\(requestId))")
        } else {
            print("[API] ← \(code) \(url)")
        }
        if !data.isEmpty, let s = String(data: data, encoding: .utf8) {
            print("[API] response: \(s.prefix(1200))")
        }
    }
}

// MARK: - Simple async lock helper

/// A tiny async lock using an actor, to serialize refresh attempts.
private actor AsyncLock {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Error>] = []

    func withLock<T>(_ work: @Sendable () async throws -> T) async throws -> T {
        try await lock()
        defer { unlock() }
        return try await work()
    }

    private func lock() async throws {
        if !isLocked {
            isLocked = true
            return
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            waiters.append(cont)
        }
    }

    private func unlock() {
        if waiters.isEmpty {
            isLocked = false
            return
        }
        let next = waiters.removeFirst()
        next.resume()
    }
}
