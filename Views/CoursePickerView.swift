import SwiftUI

struct CoursePickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""

    private var brandColor: Color {
        Color(hex: appState.branding?.primary_color) ?? .accentColor
    }

    private var filteredCourses: [Course] {
        let courses = appState.courses
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return courses }

        return courses.filter { c in
            let code = c.code.lowercased()
            let title = (c.title ?? "").lowercased()
            let term = (c.term ?? "").lowercased()
            return code.contains(q) || title.contains(q) || term.contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if appState.courses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No active courses to select.")
                            .font(.subheadline.weight(.semibold))
                        Text("Once you’re enrolled in courses in EduLens, they’ll appear here.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                } else if filteredCourses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No matches")
                            .font(.subheadline.weight(.semibold))
                        Text("Try searching by course code, title, or term.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                } else {
                    ForEach(filteredCourses) { course in
                        Button {
                            appState.selectedCourse = course
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(course.code)
                                        .font(.subheadline.weight(.semibold))

                                    if let title = course.title, !title.isEmpty {
                                        Text(title)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }

                                    if let meta = courseMetaLine(course), !meta.isEmpty {
                                        Text(meta)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                if appState.selectedCourse?.id == course.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .imageScale(.medium)
                                        .foregroundColor(brandColor)
                                } else {
                                    Image(systemName: "circle")
                                        .imageScale(.medium)
                                        .foregroundColor(Color(.systemGray4))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
            .navigationTitle("Select course")
            .searchable(text: $query, prompt: "Search courses")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func courseMetaLine(_ course: Course) -> String? {
        // Prefer term if present
        if let term = course.term, !term.isEmpty {
            return term
        }

        // Otherwise show start–end date if available
        let start = shortDate(course.start_date)
        let end = shortDate(course.end_date)
        if start != nil || end != nil {
            if let start, let end { return "\(start) – \(end)" }
            if let start { return "Starts \(start)" }
            if let end { return "Ends \(end)" }
        }

        return nil
    }

    private func shortDate(_ value: String?) -> String? {
        guard let value, let date = parseDate(value) else { return nil }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }

    private func parseDate(_ value: String) -> Date? {
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
