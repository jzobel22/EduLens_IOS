import SwiftUI

struct ReflectionsView: View {
    @EnvironmentObject var appState: AppState

    var reflectionSessions: [ChatSessionSummary] {
        appState.chatSessions.filter { $0.reflection_text != nil || $0.submitted_reflection == true }
    }

    var body: some View {
        List {
            Section(header: Text("Reflections linked to conversations")) {
                if reflectionSessions.isEmpty {
                    Text("Reflections you save from conversations will show up here.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(reflectionSessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title ?? "Untitled conversation")
                                .font(.subheadline.weight(.medium))
                            if let text = session.reflection_text {
                                Text(text)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                            HStack {
                                if session.submitted_reflection == true {
                                    Text("Submitted to instructor")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                } else {
                                    Text("Not submitted")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Reflections")
    }
}
