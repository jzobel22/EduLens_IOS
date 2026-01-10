import SwiftUI

struct LiveClassView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var isLoading: Bool = false
    @State private var error: String? = nil

    @State private var scratchpadText: String = ""
    @State private var scratchpadSaveTask: Task<Void, Never>? = nil
    @State private var isSavingScratchpad: Bool = false

    @State private var signals: [LiveSignalOut] = []
    @State private var context: LiveContextOut? = nil
    @State private var recap: LiveRecapOut? = nil

    @State private var newSignalType: LiveSignalType = .confused
    @State private var newSignalNote: String = ""
    @State private var isCreatingSignal: Bool = false

    @State private var isGeneratingRecap: Bool = false
    @State private var useAIRecap: Bool = true
    @State private var recapMode: String = "mini"   // keep simple on mobile

    private var brandColor: Color {
        Color(hex: appState.branding?.primary_color) ?? .accentColor
    }

    private var course: Course? { appState.selectedCourse }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                header

                if let error = error {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }

                if !appState.isAuthenticated {
                    Text("Please sign in to use Live Class.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else if course == nil {
                    Text("Select a course to use Live Class.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {

                    dayStrip

                    if isTodaySelected {
                        contextCard
                    }

                    scratchpadCard

                    signalComposerCard
                    signalsCard

                    recapCard
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task {
            await reloadAll(force: false)
        }
        .onChange(of: appState.selectedCourse?.id) { _, _ in
            Task { await reloadAll(force: true) }
        }
        .onChange(of: selectedDay) { _, _ in
            Task { await reloadAll(force: true) }
        }
    }

    // MARK: - UI sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Live Class")
                .font(.title2.bold())
            Text("Capture key moments, questions, and generate a recap you can reuse.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var dayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(recentDays, id: \.self) { day in
                    DayChip(
                        date: day,
                        isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDay),
                        brandColor: brandColor
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDay = Calendar.current.startOfDay(for: day)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today’s context")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await reloadContextOnly() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .imageScale(.small)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            let unresolved = context?.unresolved_confusions_today ?? 0
            HStack(spacing: 10) {
                Label("\(unresolved) open confusion\(unresolved == 1 ? "" : "s")", systemImage: "questionmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(unresolved > 0 ? .orange : .secondary)

                Spacer()
            }

            if let upcoming = context?.upcoming_assignments, !upcoming.isEmpty {
                Text("Upcoming")
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(upcoming.prefix(5)) { a in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                            if let due = a.due_at, !due.isEmpty {
                                Text("Due \(due)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                    }
                }
            } else {
                Text("No upcoming items found.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3))
    }

    private var scratchpadCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Scratchpad")
                    .font(.headline)
                Spacer()
                if isSavingScratchpad {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Text("Autosaves")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            TextEditor(text: $scratchpadText)
                .frame(minHeight: 120)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                .onChange(of: scratchpadText) { _ in
                    scheduleScratchpadSave()
                }

            Text("Jot down what happened in class. EduLens will use this to generate a recap.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3))
    }

    private var signalComposerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add a signal")
                .font(.headline)

            HStack(spacing: 10) {
                Menu {
                    ForEach(LiveSignalType.allCases) { t in
                        Button {
                            newSignalType = t
                        } label: {
                            Label(t.label, systemImage: t.systemImage)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: newSignalType.systemImage)
                        Text(newSignalType.label)
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(brandColor.opacity(0.12)))
                    .foregroundColor(brandColor)
                }

                TextField("Optional note…", text: $newSignalNote)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await createSignal() }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                        .foregroundColor(brandColor)
                }
                .disabled(isCreatingSignal || course == nil)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3))
    }

    private var signalsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Signals")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await reloadSignalsOnly() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .imageScale(.small)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if signals.isEmpty {
                Text("No signals yet for this day. Add one above.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(signalsSorted) { s in
                        LiveSignalRow(signal: s, brandColor: brandColor) { resolution in
                            Task { await setResolution(signal: s, resolution: resolution) }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3))
    }

    private var recapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Class recap")
                    .font(.headline)
                Spacer()

                if isGeneratingRecap {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Button {
                        Task { await generateRecap() }
                    } label: {
                        Text("Generate")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(brandColor.opacity(0.15)))
                            .foregroundColor(brandColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(course == nil)
                }
            }

            Toggle("Use AI recap", isOn: $useAIRecap)
                .font(.footnote)

            if let recap = recap {
                Text(recap.recap_text)
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))

                HStack {
                    Button {
                        UIPasteboard.general.string = recap.recap_text
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.footnote.weight(.semibold))
                    }

                    Spacer()

                    Text("\(recap.open_confusions) open")
                        .font(.caption)
                        .foregroundColor(recap.open_confusions > 0 ? .orange : .secondary)
                }
                .padding(.top, 4)

            } else {
                Text("No recap yet. Capture notes and generate one when you’re ready.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3))
    }

    // MARK: - Derived

    private var isTodaySelected: Bool {
        Calendar.current.isDate(selectedDay, inSameDayAs: Date())
    }

    private var recentDays: [Date] {
        // Today + previous 6 days
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: today)
        }.reversed()
    }

    private var sessionDateString: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: selectedDay)
    }

    private var signalsSorted: [LiveSignalOut] {
        // newest first
        return signals.sorted { $0.created_at > $1.created_at }
    }

    // MARK: - Networking

    private func reloadAll(force: Bool) async {
        guard appState.isAuthenticated, let course = course else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let sigs = LiveClassService.listSignals(courseId: course.id, sessionDate: sessionDateString)
            async let recapOpt = LiveClassService.getRecap(courseId: course.id, sessionDate: sessionDateString)
            async let ctx = isTodaySelected ? LiveClassService.getContext(courseId: course.id) : nil

            let (s, r, c) = try await (sigs, recapOpt, ctx)

            signals = s
            recap = r
            context = c

            // seed scratchpad from recap row (backend stores it there)
            scratchpadText = r?.scratchpad_text ?? ""
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func reloadSignalsOnly() async {
        guard appState.isAuthenticated, let course = course else { return }
        do {
            signals = try await LiveClassService.listSignals(courseId: course.id, sessionDate: sessionDateString)
        } catch { /* ignore */ }
    }

    private func reloadContextOnly() async {
        guard appState.isAuthenticated, let course = course else { return }
        guard isTodaySelected else { return }
        do {
            context = try await LiveClassService.getContext(courseId: course.id)
        } catch { /* ignore */ }
    }

    private func createSignal() async {
        guard appState.isAuthenticated, let course = course else { return }
        guard !isCreatingSignal else { return }

        isCreatingSignal = true
        defer { isCreatingSignal = false }

        do {
            _ = try await LiveClassService.createSignal(
                courseId: course.id,
                type: newSignalType,
                note: newSignalNote,
                sessionDate: sessionDateString
            )
            newSignalNote = ""
            await reloadSignalsOnly()
            if isTodaySelected { await reloadContextOnly() }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func setResolution(signal: LiveSignalOut, resolution: LiveResolutionState) async {
        do {
            _ = try await LiveClassService.updateSignal(signalId: signal.id, resolution: resolution, note: signal.note_text)
            await reloadSignalsOnly()
            if isTodaySelected { await reloadContextOnly() }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func scheduleScratchpadSave() {
        scratchpadSaveTask?.cancel()
        scratchpadSaveTask = Task { [scratchpadText] in
            // mirror WebUI debounce (~900ms)
            try? await Task.sleep(nanoseconds: 900_000_000)
            await saveScratchpad(text: scratchpadText)
        }
    }

    @MainActor
    private func saveScratchpad(text: String) async {
        guard appState.isAuthenticated, let course = course else { return }
        isSavingScratchpad = true
        defer { isSavingScratchpad = false }

        do {
            // backend returns recap row
            let updated = try await LiveClassService.saveScratchpad(
                courseId: course.id,
                sessionDate: sessionDateString,
                text: text
            )
            recap = updated
        } catch {
            // non-fatal, but you may want a subtle toast later
        }
    }

    private func generateRecap() async {
        guard appState.isAuthenticated, let course = course else { return }
        guard !isGeneratingRecap else { return }

        isGeneratingRecap = true
        defer { isGeneratingRecap = false }

        do {
            // Flush scratchpad before generating recap (matches WebUI intent)
            _ = try? await LiveClassService.saveScratchpad(
                courseId: course.id,
                sessionDate: sessionDateString,
                text: scratchpadText
            )

            let r = try await LiveClassService.generateRecap(
                courseId: course.id,
                sessionDate: sessionDateString,
                useAI: useAIRecap,
                mode: recapMode
            )
            recap = r
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Small UI helpers

private struct DayChip: View {
    let date: Date
    let isSelected: Bool
    let brandColor: Color

    private var label: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let df = DateFormatter()
        df.dateFormat = "EEE"
        return df.string(from: date)
    }

    private var sub: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
            Text(sub)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? brandColor.opacity(0.15) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? brandColor : Color(.systemGray5), lineWidth: 1)
                )
        )
    }
}

private struct LiveSignalRow: View {
    let signal: LiveSignalOut
    let brandColor: Color
    let onResolve: (LiveResolutionState) -> Void

    private var title: String {
        switch signal.signal_type {
        case .key: return "Key point"
        case .confused: return "Confused"
        case .important: return "Important"
        case .connection: return "Connection"
        }
    }

    private var icon: String {
        switch signal.signal_type {
        case .key: return "key.fill"
        case .confused: return "questionmark.circle.fill"
        case .important: return "exclamationmark.triangle.fill"
        case .connection: return "link"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(brandColor)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let rs = signal.resolution_state {
                    Text(rs.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(rs == .resolved ? .green : .orange)
                }
            }

            if let note = signal.note_text, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if signal.signal_type == .confused {
                HStack {
                    Button {
                        onResolve(.resolved)
                    } label: {
                        Text("Resolved")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                            .foregroundColor(.green)
                    }

                    Button {
                        onResolve(.stillUnclear)
                    } label: {
                        Text("Still unclear")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                            .foregroundColor(.orange)
                    }

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}
