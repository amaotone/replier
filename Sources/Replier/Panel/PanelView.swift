import SwiftUI
#if canImport(ReplierCore)
import ReplierCore
#endif

/// Keyboard/focus scheme (Japanese IME safe):
/// - Instruction field: `GistTextEditor`, an `NSTextView`-backed editor showing ~3 lines,
///   growing to ~5 then scrolling. Plain Return submits; Shift+Return inserts a literal
///   newline; a Return that confirms an IME conversion (`hasMarkedText()`) is always passed
///   through to the IME and never submits or inserts a newline — see
///   `ReturnAction`/`returnAction(hasMarkedText:shiftPressed:)` in ReplierCore for the exact
///   (unit-tested) decision logic. ↑↓ are never intercepted — IME candidate navigation needs
///   them.
/// - Presets: tapping a preset button sets the instruction text to that preset's gist and
///   immediately generates, so the user sees what was used and can edit + resubmit.
/// - ⌘Return confirms the selected candidate from anywhere (Cmd-modified keys are not
///   consumed by IME); handled once at the root view and left unhandled everywhere else so
///   it bubbles up.
/// - Esc closes the panel regardless of focus: `FloatingPanel.cancelOperation`/`keyDown`
///   handle it at the AppKit level (see `FloatingPanel.swift`), independent of SwiftUI focus
///   state — necessary now that the instruction editor is a raw `NSTextView` that SwiftUI's
///   `.onKeyPress` can't reliably intercept. The root/candidate-area `.onKeyPress(.escape)`
///   handlers below are kept as a secondary path for when a SwiftUI-managed focus target
///   (e.g. the candidate area) is focused; `PanelController.hide()` is idempotent so both
///   paths firing for the same keypress is harmless.
/// - Tab moves focus from the instruction field to the candidate area (once candidates
///   exist) and back; a mouse click on a candidate also focuses the candidate area.
/// - Candidate area focused: ←→ and ↑↓ both toggle selection between the two candidates,
///   Return confirms, Esc closes, Tab returns to the field.
struct PanelView: View {
    @Bindable var model: PanelModel
    /// Soft cap on the candidates area's height only (derived by `PanelController` from the
    /// target screen's visible frame), so a long generated reply grows the panel but never
    /// past ~70% of the screen — beyond that, candidate text scrolls inside its card. The
    /// rest of the panel hugs its natural content height (see `body`).
    let maxContentHeight: CGFloat
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    private static let presets = ["わかりました", "ごめんなさい", "確認します", "後で連絡します"]
    /// Approximate height of everything around the candidates area (outer padding,
    /// instruction editor at its max height, presets, pickers, divider) — subtracted from
    /// `maxContentHeight` to get the candidates area's own cap.
    private static let chromeHeight: CGFloat = 190
    private static let minCandidatesHeight: CGFloat = 160

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
        GistTextEditor(
            text: $model.instruction,
            placeholder: "返信の要旨を一言(Shift+Enterで改行)",
            onSubmit: { model.submit() },
            onCancel: onCancel
        )
        .focused($focusedTarget, equals: .instruction)
        .onKeyPress(.tab) {
            guard !model.partials.isEmpty else { return .ignored }
            focusedTarget = .candidates
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

    /// Tone/situation/format only update state here — no regenerate-on-change wiring. They
    /// take effect at the next explicit generation (Enter or a preset tap).
    private var pickersRow: some View {
        HStack(spacing: 12) {
            situationPicker
            tonePicker
            formatPicker
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

    private var formatPicker: some View {
        Picker("形式", selection: $model.format) {
            Text("平文").tag(OutputFormat.plain)
            Text("構造化").tag(OutputFormat.structured)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var contentArea: some View {
        switch model.phase {
        case .composing:
            hintRow {
                Text("返信の要旨を入力してEnter、または上のボタンから作成してください")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .generating:
            if model.partials.isEmpty {
                hintRow {
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
            hintRow {
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

    /// A single compact, non-expanding row for hint/status/error content in the
    /// composing/generating/failed states — deliberately no `Spacer`s or `maxHeight: .infinity`
    /// so the root view hugs this row's natural height instead of stretching to fill leftover
    /// panel height.
    private func hintRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
    }

    private var candidatesMaxHeight: CGFloat {
        max(Self.minCandidatesHeight, maxContentHeight - Self.chromeHeight)
    }

    private var candidateArea: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(model.partials.enumerated()), id: \.offset) { index, candidate in
                candidateCard(index: index, candidate: candidate)
            }
        }
        .frame(maxHeight: candidatesMaxHeight)
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
