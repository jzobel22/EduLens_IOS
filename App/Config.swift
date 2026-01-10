import Foundation
import SwiftUI

// MARK: - AppConfig

enum AppConfig {
    /// Supported environments. You can switch via:
    /// - EDULENS_ENV=prod|staging|dev  (Scheme -> Run -> Arguments -> Environment Variables)
    /// - or by directly setting EDULENS_BACKEND_URL (wins over env preset)
    enum Environment: String {
        case prod
        case staging
        case dev
    }

    /// Optional explicit override (wins).
    static var backendOverrideURL: String? {
        let v = ProcessInfo.processInfo.environment["EDULENS_BACKEND_URL"]
        let trimmed = (v ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.removingTrailingSlash()
    }

    /// Env selector (fallbacks to prod if not set / invalid).
    static var environment: Environment {
        let v = ProcessInfo.processInfo.environment["EDULENS_ENV"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return Environment(rawValue: v ?? "") ?? .prod
    }

    /// Default base URLs per env.
    /// Update these to match your actual domains when ready.
    static var defaultBaseURL: String {
        switch environment {
        case .prod:
            // Prefer your stable custom domain if/when you have it:
            // return "https://api.edulens.net"
            return "https://edulens-api.onrender.com"
        case .staging:
            // Example staging host; update if you have one.
            // return "https://staging-api.edulens.net"
            return "https://edulens-api.onrender.com"
        case .dev:
            // iOS Simulator -> Mac localhost:
            // If your FastAPI is on your Mac, this works on Simulator:
            return "http://127.0.0.1:8000"
            // If running on a physical device, you'll need your Mac LAN IP instead.
        }
    }

    /// Effective backend base URL (override wins).
    static var backendBaseURL: String {
        (backendOverrideURL ?? defaultBaseURL).removingTrailingSlash()
    }
}

/// Backwards-compatible constant (so other files don’t break).
/// Prefer AppConfig.backendBaseURL going forward.
let BACKEND_BASE_URL: String = AppConfig.backendBaseURL

// MARK: - URL builder

/// Build an absolute URL for the EduLens backend.
///
/// - Note: This will *not* crash on invalid URLs; it returns a safe fallback.
func edulensAPI(_ path: String) -> URL {
    let base = AppConfig.backendBaseURL
    let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
    let combined = base + "/" + trimmedPath

    if let url = URL(string: combined) {
        return url
    }

    // Fallback: return base URL if path is malformed
    return URL(string: base) ?? URL(fileURLWithPath: "/")
}

// MARK: - String helpers

private extension String {
    func removingTrailingSlash() -> String {
        var s = self
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }
}

// MARK: - Color helper

extension Color {
    /// Create a Color from a hex string like "#2563eb" or "2563eb".
    init?(hex: String?) {
        guard let hex = hex else { return nil }
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6,
              let rgb = Int(cleaned, radix: 16) else { return nil }
        let r = Double((rgb >> 16) & 0xff) / 255.0
        let g = Double((rgb >> 8) & 0xff) / 255.0
        let b = Double(rgb & 0xff) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
