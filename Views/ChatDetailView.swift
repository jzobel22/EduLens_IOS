import SwiftUI

struct ChatDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var session: ChatSessionSummary?

    @State private var messages: [TranscriptMessage] = []
    @State private var inputText: String = ""
    @State private var isSending: Bool = false
    @State private var error: String? = nil
    @State private var currentSessionId: String?

    private var brandColor: Color {
        Color(hex: appState.branding?.primary_color) ?? .accentColor
    }

    private var conversationTitle: String {
        session?.title ?? "New conversation"
    }

    private var courseLabel: String {
        if let course = appState.selectedCourse {
            if let title = course.title, !title.isEmpty {
                return "\(course.code) • \(title)"
            } else {
                return course.code
            }
        }
        return "No course selected"
    }

    private var placeholder: String {
        if let course = appState.selectedCourse {
            return "Ask a question about \(course.code) or its assignments…"
        } else {
            return "Ask a question about your courses or study plan…"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            // Messages
            List {
                ForEach(messages) { msg in
                    ChatBubbleView(
                        message: msg,
                        brandColor: brandColor
                    )
                    .listRowSeparator(.hidden)
                }

                if isSending {
                    TypingIndicatorView(brandColor: brandColor)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)

            if let error = error {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            // Input bar
            HStack(alignment: .bottom, spacing: 8) {
                TextField(placeholder, text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    Task { await send() }
                } label: {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .imageScale(.medium)
                    }
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(12)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            currentSessionId = session?.id
            Task {
                await loadTranscriptIfExisting()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .imageScale(.medium)
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(courseLabel)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(conversationTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("EduLens")
                .font(.caption)
                .foregroundColor(brandColor)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color(.systemBackground))
    }

    // MARK: - Data

    private func loadTranscriptIfExisting() async {
        guard let token = appState.accessToken else { return }
        guard let sid = currentSessionId else { return }
        do {
            let resp = try await ChatService.getTranscript(sessionId: sid, accessToken: token)
            await MainActor.run {
                self.messages = resp.messages
            }
        } catch {
            // If transcript isn't available (e.g., save_content=false), just start fresh.
        }
    }

    private func send() async {
        guard let token = appState.accessToken else { return }
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let now = ISO8601DateFormatter().string(from: Date())

        let userMsg = TranscriptMessage(role: "user", content: trimmed, ts: now)
        await MainActor.run {
            messages.append(userMsg)
            inputText = ""
            isSending = true
            error = nil
        }

        var payload = ChatRequestBody(
            session_id: currentSessionId,
            course_id: appState.selectedCourse?.id,
            week: nil,
            message: trimmed,
            mode: "mini",
            private_mode: false
        )

        do {
            let resp = try await ChatService.sendMessage(payload: payload, accessToken: token)

            await MainActor.run {
                currentSessionId = resp.session_id
                let aiMsg = TranscriptMessage(role: "assistant", content: resp.reply, ts: now)
                withAnimation(.easeIn(duration: 0.15)) {
                    messages.append(aiMsg)
                }
            }

            // Refresh sessions list so Web + iOS stay in sync.
            let sessions = try await ChatService.listChatSessions(accessToken: token)
            await MainActor.run {
                appState.chatSessions = sessions
            }
        } catch {
            await MainActor.run {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }

        await MainActor.run {
            isSending = false
        }
    }
}

// MARK: - Bubble view

struct ChatBubbleView: View {
    let message: TranscriptMessage
    let brandColor: Color

    private var isUser: Bool {
        message.role == "user"
    }

    var body: some View {
        HStack {
            if isUser { Spacer() }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(isUser ? .white : .primary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isUser ? brandColor : Color(.secondarySystemBackground))
            )
            .shadow(color: Color.black.opacity(isUser ? 0.10 : 0.04),
                    radius: isUser ? 4 : 2,
                    x: 0, y: isUser ? 2 : 1)

            if !isUser { Spacer() }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Typing indicator

struct TypingIndicatorView: View {
    let brandColor: Color

    @State private var phase: CGFloat = 0

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(.secondarySystemFill))
                        .frame(width: 28, height: 28)
                        .overlay(
                            HStack(spacing: 3) {
                                Circle().fill(brandColor).frame(width: 4, height: 4)
                                Circle().fill(brandColor.opacity(0.7)).frame(width: 4, height: 4)
                                Circle().fill(brandColor.opacity(0.4)).frame(width: 4, height: 4)
                            }
                        )
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .onAppear {
            withAnimation(Animation.linear(duration: 0.9).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}
