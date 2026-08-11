import SwiftUI
import ReplierCore

struct PanelView: View {
    @Bindable var model: PanelModel
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    /// Two focus targets: the instruction field (where typing happens) and the panel
    /// itself (which backs candidate ↑↓ navigation). See `instructionField`'s and the
    /// root view's `onKeyPress` handlers below for the full Enter/arrow-key scheme.
    private enum FocusTarget: Hashable {
        case instruction
        case panel
    }

    @FocusState private var focusedTarget: FocusTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            contextPreview
            instructionField
            intentRow
            tonePicker
            Divider()
            contentArea
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .focusable()
        .focused($focusedTarget, equals: .panel)
        .onAppear { focusedTarget = .instruction }
        .onKeyPress(.upArrow) {
            model.moveSelection(-1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            model.moveSelection(1)
            return .handled
        }
        .onKeyPress(.return, phases: .down) { press in
            if press.modifiers.contains(.command) {
                return attemptConfirm() ? .handled : .ignored
            }
            if model.phase == .composing {
                model.submitInstruction()
                return .handled
            }
            return attemptConfirm() ? .handled : .ignored
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
    }

    /// Enter submits the instruction (composing or otherwise, since the field is
    /// focused). ⌘Enter is the always-available confirm fast path. ↑↓ move candidate
    /// selection and hand focus to the panel, so a second ↑↓ (or a plain Enter) then
    /// acts on the candidate list per the root view's handlers above.
    private var instructionField: some View {
        TextField("返信の要旨を一言(空のままEnterでおまかせ)", text: $model.instruction)
            .textFieldStyle(.roundedBorder)
            .focused($focusedTarget, equals: .instruction)
            .onKeyPress(.upArrow) {
                guard !model.partials.isEmpty else { return .ignored }
                model.moveSelection(-1)
                focusedTarget = .panel
                return .handled
            }
            .onKeyPress(.downArrow) {
                guard !model.partials.isEmpty else { return .ignored }
                model.moveSelection(1)
                focusedTarget = .panel
                return .handled
            }
            .onKeyPress(.return, phases: .down) { press in
                if press.modifiers.contains(.command) {
                    return attemptConfirm() ? .handled : .ignored
                }
                model.submitInstruction()
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

    private var contextPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("受信したメッセージ")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $model.contextText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(maxHeight: 100)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var intentRow: some View {
        HStack(spacing: 8) {
            intentButton("承諾", intent: .accept)
            intentButton("お断り", intent: .decline)
            intentButton("質問", intent: .question)
            intentButton("後で連絡", intent: .followUp)
        }
    }

    private func intentButton(_ title: String, intent: ReplyIntent) -> some View {
        Button(title) {
            model.choose(intent: intent)
        }
        .buttonStyle(.bordered)
    }

    private var tonePicker: some View {
        Picker("トーン", selection: $model.tone) {
            Text("ビジネス").tag(Tone.business)
            Text("カジュアル").tag(Tone.casual)
        }
        .pickerStyle(.segmented)
        .onChange(of: model.tone) { _, _ in
            model.regenerate()
        }
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
                candidateList
            }
        case .ready:
            candidateList
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

    private var candidateList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(model.partials.enumerated()), id: \.offset) { index, candidate in
                candidateRow(index: index, candidate: candidate)
            }
        }
    }

    private func candidateRow(index: Int, candidate: PartialCandidate) -> some View {
        let isSelected = index == model.selectedIndex
        return HStack(alignment: .top, spacing: 8) {
            Text(badgeLabel(candidate.label))
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(isSelected ? 0.3 : 0.12))
                .clipShape(Capsule())
            Text(candidate.text)
                .font(.system(size: 13))
                .multilineTextAlignment(.leading)
            if !candidate.isComplete {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(candidate.isComplete ? 1.0 : 0.6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard candidate.isComplete else { return }
            model.moveSelection(index - model.selectedIndex)
            attemptConfirm()
        }
        .onTapGesture(count: 1) {
            model.moveSelection(index - model.selectedIndex)
        }
    }

    private func badgeLabel(_ label: ReplyCandidate.Label) -> String {
        switch label {
        case .short: return "短め"
        case .standard: return "標準"
        case .polite: return "丁寧"
        }
    }
}
