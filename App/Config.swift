import Foundation
import SwiftUI

/// Point this at the same backend your WebUI uses.
let BACKEND_BASE_URL: String = {
    // If you ever want to override from an environment variable when
    // running from the command line, use EDULENS_BACKEND_URL.
    if let env = ProcessInfo.processInfo.environment["EDULENS_BACKEND_URL"],
       !env.isEmpty {
        return env
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .removingTrailingSlash()
    }

    // Default: your Render backend
    return "https://edulens-api.onrender.com".removingTrailingSlash()
}()

func edulensAPI(_ path: String) -> URL {
    let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
    return URL(string: BACKEND_BASE_URL + "/" + trimmed)!
}

private extension String {
    func removingTrailingSlash() -> String {
        var s = self
        while s.hasSuffix("/") {
            s.removeLast()
        }
        return s
    }
}

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
