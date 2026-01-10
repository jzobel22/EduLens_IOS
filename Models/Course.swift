import Foundation

struct Course: Identifiable, Decodable, Hashable {
    let id: String
    let code: String
    let title: String?
    let term: String?
    let start_date: String?
    let end_date: String?
    let grace_days: Int?

    // MARK: - UI helpers (non-breaking)

    var displayTitle: String {
        let t = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return code }
        return "\(code) • \(t)"
    }

    var shortTitle: String {
        let t = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? code : t
    }

    var startDateParsed: Date? { Course.parseDate(start_date) }
    var endDateParsed: Date? { Course.parseDate(end_date) }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: value) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]
        for f in formats {
            df.dateFormat = f
            if let d = df.date(from: value) { return d }
        }
        return nil
    }
}
