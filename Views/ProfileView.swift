import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            Section(header: Text("Student")) {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(appState.email ?? "Unknown")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Role")
                    Spacer()
                    Text(appState.role ?? "student")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Institution")) {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(appState.branding?.school_name ?? "Not set")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Courses")) {
                if appState.courses.isEmpty {
                    Text("No active courses")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                } else {
                    ForEach(appState.courses) { course in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(course.code)
                                .font(.subheadline.weight(.medium))
                            if let title = course.title {
                                Text(title)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Profile")
    }
}
