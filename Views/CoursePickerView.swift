import SwiftUI

struct CoursePickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if appState.courses.isEmpty {
                    Text("No active courses to select.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(appState.courses) { course in
                        Button {
                            appState.selectedCourse = course
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(course.code)
                                        .font(.subheadline.weight(.semibold))
                                    if let title = course.title {
                                        Text(title)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if appState.selectedCourse?.id == course.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .imageScale(.medium)
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select course")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
