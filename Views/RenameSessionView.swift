import SwiftUI

struct RenameSessionView: View {
    let session: ChatSessionSummary
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var titleText: String

    init(
        session: ChatSessionSummary,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.session = session
        self.onSave = onSave
        self.onCancel = onCancel
        _titleText = State(initialValue: session.title ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Conversation title")) {
                    TextField("Untitled conversation", text: $titleText)
                        .textInputAutocapitalization(.sentences)
                }
            }
            .navigationTitle("Rename")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmed.isEmpty ? "Untitled conversation" : trimmed)
                    }
                }
            }
        }
    }
}
