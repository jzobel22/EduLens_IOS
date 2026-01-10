import SwiftUI
import Combine
import Security

// MARK: - Models you already use

struct Branding: Decodable {
    let school_name: String?
    let logo_url: String?
    let primary_color: String?
    let accent_color: String?
}

struct TokenResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let token_type: String
    let role: String
    let user_id: String
}

// MARK: - Keychain helper (drop-in, no extra file needed)

private enum KeychainStore {
    // Change this if you want to isolate between dev/staging/prod:
    private static let service = "com.edulens.ios"
    private static func key(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func set(_ value: String?, for account: String) {
        let q = key(account)
        SecItemDelete(q as CFDictionary)

        guard let value else { return }
        let data = Data(value.utf8)

        var add = q
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(_ account: String) -> String? {
        var q = key(account)
        q[kSecReturnData as String] = kCFBooleanTrue
        q[kSecMatchLimit as String] = kSecMatchLimitOne

        var out: AnyObject?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ account: String) {
        let q = key(account)
        SecItemDelete(q as CFDictionary)
    }

    static func clearAll(_ accounts: [String]) {
        for a in accounts { delete(a) }
    }
}

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {

    // MARK: Auth (published)

    @Published private(set) var accessToken: String? = nil
    @Published private(set) var refreshToken: String? = nil
    @Published private(set) var role: String? = nil
    @Published private(set) var userId: String? = nil
    @Published var email: String? = nil

    // MARK: App data (unchanged from your original)

    @Published var branding: Branding? = nil
    @Published var courses: [Course] = []
    @Published var selectedCourse: Course? = nil

    @Published var chatSessions: [ChatSessionSummary] = []
    @Published var currentSessionTranscript: TranscriptResponse? = nil

    @Published var weeklyReflectionStatus: [StudentWeeklyReflectionStatus] = []
    @Published var todayAllCourses: MultiCourseTodayResponse? = nil

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: Keychain keys

    private enum KC {
        static let access = "edulens.access_token"
        static let refresh = "edulens.refresh_token"
        static let role = "edulens.role"
        static let userId = "edulens.user_id"
        static let email = "edulens.email"
        static let all = [access, refresh, role, userId, email]
    }

    // MARK: Init / bootstrap

    init() {
        // Restore persisted session immediately.
        let restoredAccess = KeychainStore.get(KC.access)
        let restoredRefresh = KeychainStore.get(KC.refresh)
        let restoredRole = KeychainStore.get(KC.role)
        let restoredUserId = KeychainStore.get(KC.userId)
        let restoredEmail = KeychainStore.get(KC.email)

        self.accessToken = restoredAccess
        self.refreshToken = restoredRefresh
        self.role = restoredRole
        self.userId = restoredUserId
        self.email = restoredEmail

        // Wire APIClient token hooks once. This enables:
        // - auto Authorization injection
        // - refresh-on-401 + retry
        APIClient.shared.tokenHooks = APITokenHooks(
            getAccessToken: { [weak self] in self?.accessToken },
            getRefreshToken: { [weak self] in self?.refreshToken },
            setTokens: { [weak self] access, refresh in
                Task { @MainActor in
                    self?.setSession(access: access, refresh: refresh, role: self?.role, userId: self?.userId, email: self?.email)
                }
            },
            clearTokens: { [weak self] in
                Task { @MainActor in
                    self?.logout(reason: nil)
                }
            }
        )
    }

    var isAuthenticated: Bool {
        guard let t = accessToken, !t.isEmpty else { return false }
        return true
    }

    // MARK: Session setters

    /// Call this after successful login or refresh.
    func setSession(access: String, refresh: String, role: String?, userId: String?, email: String?) {
        self.accessToken = access
        self.refreshToken = refresh
        self.role = role
        self.userId = userId
        self.email = email

        KeychainStore.set(access, for: KC.access)
        KeychainStore.set(refresh, for: KC.refresh)
        if let role { KeychainStore.set(role, for: KC.role) }
        if let userId { KeychainStore.set(userId, for: KC.userId) }
        if let email { KeychainStore.set(email, for: KC.email) }
    }

    /// Convenience for your existing AuthService usage.
    func applyTokenResponse(_ tr: TokenResponse, email: String? = nil) {
        setSession(access: tr.access_token, refresh: tr.refresh_token, role: tr.role, userId: tr.user_id, email: email)
    }

    // MARK: Logout / reset

    /// Clears tokens + keychain + in-memory app data.
    func logout(reason: String?) {
        if let reason { self.errorMessage = reason }

        KeychainStore.clearAll(KC.all)

        accessToken = nil
        refreshToken = nil
        role = nil
        userId = nil
        email = nil

        // Clear app data too
        branding = nil
        courses = []
        selectedCourse = nil
        chatSessions = []
        currentSessionTranscript = nil
        weeklyReflectionStatus = []
        todayAllCourses = nil
        isLoading = false
    }

    /// Kept for compatibility with your existing code; now calls logout().
    func reset() {
        logout(reason: nil)
    }

    // MARK: Optional: lightweight session validation (recommended)

    /// Call this on app launch (e.g., in RootView .task) to validate the restored token.
    /// If invalid/expired and refresh fails, user is logged out.
    func validateSessionWithMe() async {
        guard isAuthenticated else { return }
        do {
            // You likely already have a MeResponse model somewhere; if not, create it in the next step.
            let _: MeResponse = try await APIClient.shared.request("GET", path: "/me")
        } catch {
            // If /me 401s, APIClient will try refresh+retry automatically.
            // If it still fails, we should logout for a clean UX.
            logout(reason: "Session expired. Please log in again.")
        }
    }
}

// MARK: - Minimal /me model (keep here if you don't already have one)

struct MeResponse: Decodable {
    let id: String?
    let role: String?
    let institution_id: String?
}
