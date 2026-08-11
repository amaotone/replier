import SwiftUI
#if canImport(ReplierCore)
import ReplierCore
#endif

/// Keyboard/focus scheme (Japanese IME safe):
/// - Instruction field: a multi-line `TextField(axis: .vertical)` showing ~3 lines. On a
///   native AppKit macOS app (this is not Mac Catalyst) that field type keeps the classic
///   AppKit field-editor behavior: plain Return still fires `.onSubmit` (not a newline) and
///   Option+Return inserts a literal newline via the standard `insertNewlineIgnoringFieldEditor:`
///   key binding — both handled entirely by AppKit/SwiftUI's own Return handling, so no
///   `onKeyPress(.return)` interception is added here. `.onSubmit` does not fire for an IME
///   composition-confirm Enter, so kana→kanji confirmation never triggers generation. ↑↓ are
///   never intercepted here — IME candidate navigation needs them.
/// - Presets: tapping a preset button sets the instruction text to that preset's gist and
///   immediately generates, so the user sees what was used and can edit + resubmit.
/// - ⌘Return confirms the selected candidate from anywhere (Cmd-modified keys are not
///   consumed by IME); handled once at the root view and left unhandled everywhere else so
///   it bubbles up.
/// - Esc closes the panel from anywhere (root-level, plus the instruction field itself so
///   NSTextField's native cancel behavior can't swallow it first). During active IME
///   composition, Esc is consumed by the IME to cancel composition first — expected/fine.
/// - Tab moves focus from the instruction field to the candidate area (once candidates
///   exist) and back; a mouse click on a candidate also focuses the candidate area.
/// - Candidate area focused: ←→ and ↑↓ both toggle selection between the two candidates,
///   Return confirms, Esc closes, Tab returns to the field.
struct PanelView: View {
    @Bindable var model: PanelModel
    /// Soft cap on the panel's total content height (derived by `PanelController` from the
    /// target screen's visible frame), so a long generated reply grows the panel but never
    /// past ~70% of the screen — beyond that, candidate text scrolls inside its card instead.
    let maxContentHeight: CGFloat
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    private static let presets = ["わかりました", "ごめんなさい", "確認します", "後で連絡します"]

    private enum FocusTarget: Hashable {
        case instruction
        case candidates
    }

    @FocusState private var focusedTarget: FocusTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            instructionField
            presetsRow
            pickersRow
            Divider()
            contentArea
        }
        .padding(16)
        .frame(width: 760)
        .frame(maxHeight: maxContentHeight)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onChange(of: model.focusRequest) { _, _ in
            Task { @MainActor in
                focusedTarget = .instruction
            }
        }
        .onKeyPress(.return, phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            return attemptConfirm() ? .handled : .ignored
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
    }

    private var instructionField: some View {
        TextField("返信の要旨を一言(Option+Enterで改行)", text: $model.instruction, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(3...5)
            .focused($focusedTarget, equals: .instruction)
            .onSubmit {
                model.submit()
            }
            .onKeyPress(.tab) {
                guard !model.partials.isEmpty else { return .ignored }
                focusedTarget = .candidates
                return .handled
            }
            .onKeyPress(.escape) {
                onCancel()
                return .handled
            }
    }

    @discardableResult
    private func attemptConfirm() -> Bool {
        guard let text = model.confirmSelection() else { return false }
        onConfirm(text)
        return true
    }

    private var presetsRow: some View {
        HStack(spacing: 8) {
            ForEach(Self.presets, id: \.self) { gist in
                Button(gist) {
                    model.applyPreset(gist)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// Tone/situation only update state here — no regenerate-on-change wiring. They take
    /// effect at the next explicit generation (Enter or a preset tap).
    private var pickersRow: some View {
        HStack(spacing: 12) {
            situationPicker
            tonePicker
        }
    }

    private var situationPicker: some View {
        Picker("送信先", selection: $model.situation) {
            Text("メール").tag(Situation.mail)
            Text("チャット").tag(Situation.chat)
        }
        .pickerStyle(.segmented)
    }

    private var tonePicker: some View {
        Picker("トーン", selection: $model.tone) {
            Text("ビジネス").tag(Tone.business)
            Text("カジュアル").tag(Tone.casual)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var contentArea: some View {
        switch model.phase {
        case .composing:
            centered {
                Text("返信の要旨を入力してEnter、または上のボタンから作成してください")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .generating:
            if model.partials.isEmpty {
                centered {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("生成中…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                candidateArea
            }
        case .ready:
            candidateArea
        case .failed(let message):
            centered {
                VStack(spacing: 8) {
                    Text("生成に失敗しました")
                        .font(.callout.bold())
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("やり直す") {
                        model.regenerate()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }

    private var candidateArea: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(model.partials.enumerated()), id: \.offset) { index, candidate in
                candidateCard(index: index, candidate: candidate)
            }
        }
        .focusable()
        .focused($focusedTarget, equals: .candidates)
        .onKeyPress(.leftArrow) { moveSelection(-1) }
        .onKeyPress(.rightArrow) { moveSelection(1) }
        .onKeyPress(.upArrow) { moveSelection(-1) }
        .onKeyPress(.downArrow) { moveSelection(1) }
        .onKeyPress(.return, phases: .down) { _ in attemptConfirm() ? .handled : .ignored }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
        .onKeyPress(.tab) {
            focusedTarget = .instruction
            return .handled
        }
    }

    private func moveSelection(_ delta: Int) -> KeyPress.Result {
        model.moveSelection(delta)
        return .handled
    }

    private func candidateCard(index: Int, candidate: PartialCandidate) -> some View {
        let isSelected = index == model.selectedIndex
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(badgeLabel(candidate.label))
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(isSelected ? 0.3 : 0.12))
                    .clipShape(Capsule())
                if !candidate.isComplete {
                    ProgressView()
                        .controlSize(.mini)
                }
                Spacer()
            }
            ScrollView {
                Text(candidate.text)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .opacity(candidate.isComplete ? 1.0 : 0.7)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard candidate.isComplete else { return }
            focusedTarget = .candidates
            model.moveSelection(index - model.selectedIndex)
            attemptConfirm()
        }
        .onTapGesture(count: 1) {
            focusedTarget = .candidates
            model.moveSelection(index - model.selectedIndex)
        }
    }

    private func badgeLabel(_ label: ReplyCandidate.Label) -> String {
        switch label {
        case .short: return "短め"
        case .long: return "長め"
        }
    }
}
