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

    @State private var didLoadTranscript: Bool = false

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

            ScrollViewReader { proxy in
                List {
                    ForEach(messages) { msg in
                        ChatBubbleView(message: msg, brandColor: brandColor)
                            .listRowSeparator(.hidden)
                            .id(msg.id)
                    }

                    if isSending {
                        TypingIndicatorView(brandColor: brandColor)
                            .listRowSeparator(.hidden)
                            .id("typing")
                    }
                }
                .listStyle(.plain)
                .onChange(of: messages.count) { _ in
                    scrollToBottom(proxy: proxy, animated: true)
                }
                .onChange(of: isSending) { _ in
                    scrollToBottom(proxy: proxy, animated: true)
                }
                .onAppear {
                    // First paint scroll
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }

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
                .disabled(trimmedInput.isEmpty || isSending || !appState.isAuthenticated)
            }
            .padding(12)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            // Capture session id once
            currentSessionId = session?.id

            // Load transcript once per appearance
            Task { await loadTranscriptIfExisting() }
        }
    }

    private var trimmedInput: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard !didLoadTranscript else { return }
        didLoadTranscript = true

        guard appState.isAuthenticated else { return }
        guard let sid = currentSessionId, !sid.isEmpty else { return }

        do {
            let resp = try await ChatService.getTranscript(sessionId: sid)
            self.messages = resp.messages
        } catch {
            // If transcript isn't available (e.g., save_content=false), just start fresh.
            // We'll intentionally stay silent here to keep UX clean.
        }
    }

    private func send() async {
        guard appState.isAuthenticated else {
            self.error = "Please log in again."
            return
        }

        let text = trimmedInput
        guard !text.isEmpty else { return }

        // Optimistic append user message
        let userTs = isoNow()
        let userMsg = TranscriptMessage(role: "user", content: text, ts: userTs)

        messages.append(userMsg)
        inputText = ""
        isSending = true
        error = nil

        let payload = ChatRequestBody(
            session_id: currentSessionId,
            course_id: appState.selectedCourse?.id,
            week: nil,
            message: text,
            mode: "mini",
            private_mode: false
        )

        do {
            let resp = try await ChatService.sendMessage(payload: payload)

            currentSessionId = resp.session_id

            let aiTs = isoNow()
            let aiMsg = TranscriptMessage(role: "assistant", content: resp.reply, ts: aiTs)
            withAnimation(.easeIn(duration: 0.15)) {
                messages.append(aiMsg)
            }

            // Refresh sessions list so Web + iOS stay in sync.
            let sessions = try await ChatService.listChatSessions(limit: 50)
            appState.chatSessions = sessions
        } catch {
            // If send fails, keep the user's message but show the error.
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isSending = false
    }

    private func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        // Prefer typing indicator if present
        if isSending {
            if animated {
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo("typing", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("typing", anchor: .bottom)
            }
            return
        }

        guard let lastId = messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }
}

// MARK: - Bubble view

struct ChatBubbleView: View {
    let message: TranscriptMessage
    let brandColor: Color

    private var isUser: Bool { message.role == "user" }

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
            .shadow(
                color: Color.black.opacity(isUser ? 0.10 : 0.04),
                radius: isUser ? 4 : 2,
                x: 0, y: isUser ? 2 : 1
            )

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
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}
