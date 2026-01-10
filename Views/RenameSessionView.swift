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

    private var trimmed: String {
        titleText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedTitle: String {
        trimmed.isEmpty ? "Untitled conversation" : trimmed
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Conversation title"), footer: footer) {
                    TextField("Untitled conversation", text: $titleText)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .onSubmit { save() }
                }
            }
            .navigationTitle("Rename")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var footer: some View {
        Text("This updates the title everywhere you use EduLens.")
            .font(.footnote)
    }

    private func save() {
        onSave(resolvedTitle)
    }
}
