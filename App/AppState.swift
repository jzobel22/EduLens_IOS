import SwiftUI
import Combine

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

final class AppState: ObservableObject {
    @Published var accessToken: String? = nil
    @Published var refreshToken: String? = nil
    @Published var role: String? = nil
    @Published var userId: String? = nil
    @Published var email: String? = nil

    @Published var branding: Branding? = nil
    @Published var courses: [Course] = []
    @Published var selectedCourse: Course? = nil

    @Published var chatSessions: [ChatSessionSummary] = []
    @Published var currentSessionTranscript: TranscriptResponse? = nil

    @Published var weeklyReflectionStatus: [StudentWeeklyReflectionStatus] = []
    @Published var todayAllCourses: MultiCourseTodayResponse? = nil

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    var isAuthenticated: Bool {
        accessToken != nil
    }

    func reset() {
        accessToken = nil
        refreshToken = nil
        role = nil
        userId = nil
        email = nil
        branding = nil
        courses = []
        selectedCourse = nil
        chatSessions = []
        currentSessionTranscript = nil
        weeklyReflectionStatus = []
        todayAllCourses = nil
        isLoading = false
        errorMessage = nil
    }
}
