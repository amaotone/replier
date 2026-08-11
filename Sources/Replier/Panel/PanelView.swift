import SwiftUI
import ReplierCore

struct PanelView: View {
    @Bindable var model: PanelModel
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool
    @State private var customInstructionDraft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            contextPreview
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
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.upArrow) {
            model.moveSelection(-1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            model.moveSelection(1)
            return .handled
        }
        .onKeyPress(.return) {
            guard let text = model.selectedText else { return .ignored }
            onConfirm(text)
            return .handled
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
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
            TextField("自由指示…", text: $customInstructionDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submitCustomInstruction)
        }
        .disabled(isGenerating)
    }

    private func intentButton(_ title: String, intent: ReplyIntent) -> some View {
        Button(title) {
            Task { await model.choose(intent: intent) }
        }
        .buttonStyle(.bordered)
    }

    private func submitCustomInstruction() {
        let instruction = customInstructionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { return }
        Task { await model.choose(intent: .custom(instruction)) }
    }

    private var tonePicker: some View {
        Picker("トーン", selection: $model.tone) {
            Text("ビジネス").tag(Tone.business)
            Text("カジュアル").tag(Tone.casual)
        }
        .pickerStyle(.segmented)
        .disabled(isGenerating)
    }

    private var isGenerating: Bool {
        if case .generating = model.phase { return true }
        return false
    }

    @ViewBuilder
    private var contentArea: some View {
        switch model.phase {
        case .choosing:
            centered {
                Text("上のボタンから返信の意図を選んでください")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .generating(let charCount):
            centered {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("生成中… (\(charCount)文字)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
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
                        model.resetToChoosing()
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
            ForEach(Array(model.candidates.enumerated()), id: \.offset) { index, candidate in
                candidateRow(index: index, candidate: candidate)
            }
        }
    }

    private func candidateRow(index: Int, candidate: ReplyCandidate) -> some View {
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
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            model.moveSelection(index - model.selectedIndex)
            onConfirm(candidate.text)
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
