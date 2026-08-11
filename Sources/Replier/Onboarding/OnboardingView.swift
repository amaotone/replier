import AppKit
import SwiftUI
#if canImport(ReplierCore)
import ReplierCore
#endif

struct OnboardingView: View {
    @State private var model: OnboardingModel
    let onFinish: () -> Void

    init(styleProfileStore: StyleProfileStore, onFinish: @escaping () -> Void) {
        _model = State(wrappedValue: OnboardingModel(styleProfileStore: styleProfileStore))
        self.onFinish = onFinish
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("replierへようこそ")
                        .font(.title2.bold())
                    Text("使い始める前に、いくつかの設定を確認しましょう。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                accessibilitySection
                Divider()
                codexSection
                Divider()
                dataControlsSection
                Divider()
                styleSection
                Divider()

                Button("開始する") {
                    model.completeOnboarding()
                    onFinish()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(24)
        }
        .frame(width: 520, height: 640)
        .onAppear {
            model.refreshAccessibilityStatus()
            model.loadStyleSamples()
            Task { await model.recheckCodex() }
        }
    }

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("① アクセシビリティ権限").font(.headline)
            HStack(spacing: 8) {
                statusBadge(model.accessibilityGranted, onLabel: "許可済み", offLabel: "未許可")
                Spacer()
                Button("権限をリクエスト") { model.requestAccessibilityPermission() }
                Button("システム設定を開く") { model.openAccessibilitySettings() }
            }
            Text("選択中のテキストを読み取るために必要です。未許可でもパネルは開けますが、本文をコピー&ペーストしてください。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var codexSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("② Codex接続").font(.headline)

            if model.codexCheckInProgress {
                ProgressView().controlSize(.small)
            } else if !model.codexExecutableFound {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Codexの実行ファイルが見つかりませんでした。")
                        .foregroundStyle(.orange)
                    HStack(spacing: 6) {
                        Text("brew install codex")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(6)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Button {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString("brew install codex", forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                    Text("Codexアプリ/CLIでログイン済みなら追加設定は不要です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("インストール済みなのに見つからない場合は、下の「実行ファイルを手動で指定」からパスを指定できます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let status = model.codexAccountStatus {
                if status.isLoggedIn {
                    Text("ログイン済み\(status.plan.map { " (\($0))" } ?? "")")
                        .foregroundStyle(.green)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("未ログインです。")
                            .foregroundStyle(.orange)
                        Text("ターミナルで `codex login` を実行してください。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let error = model.codexCheckError {
                Text("接続確認に失敗しました: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let path = model.resolvedCodexExecutablePath {
                HStack(spacing: 4) {
                    Text("検出パス:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(path.path)
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            if let overridePath = model.codexExecutableOverridePath {
                HStack(spacing: 4) {
                    Text("手動指定:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(overridePath)
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            HStack(spacing: 8) {
                Button("再チェック") {
                    Task { await model.recheckCodex() }
                }
                .disabled(model.codexCheckInProgress)

                Button("実行ファイルを手動で指定") { model.pickCodexExecutable() }

                if model.codexExecutableOverridePath != nil {
                    Button("クリア") { model.clearCodexExecutableOverride() }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("モデル").font(.caption).foregroundStyle(.secondary)
                TextField("モデル名", text: $model.codexModel)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Reasoning Effort").font(.caption).foregroundStyle(.secondary)
                Picker("Reasoning Effort", selection: $model.codexReasoningEffort) {
                    ForEach(CodexSettings.reasoningEffortOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Text("変更は次回の返信生成から反映されます(再起動不要)。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dataControlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("③ データ設定の確認").font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("① ChatGPT設定 → Data Controls → 「Improve the model for everyone」をOFF")
                Text("② Codex設定の学習許可もOFF")
            }
            .font(.callout)
            Button("ChatGPTのデータ設定を開く") {
                guard let url = URL(string: "https://chatgpt.com/#settings/DataControls") else { return }
                NSWorkspace.shared.open(url)
            }
            Toggle("確認しました", isOn: $model.dataControlsConfirmed)
            Text("APIキー運用やBusiness/Enterpriseプランでは不要です。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("④ 文体サンプル(スキップ可)").font(.headline)
            Text("過去に自分が書いた返信文を貼り付けると、その文体を模倣した返信が生成されます。")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $model.newSampleText)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(height: 80)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button("追加") { model.addStyleSample() }
                .disabled(model.newSampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let error = model.styleErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            ForEach(model.styleSamples) { sample in
                HStack(alignment: .top, spacing: 8) {
                    Text(sample.text)
                        .font(.caption)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        model.removeStyleSample(id: sample.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }

    private func statusBadge(_ isOn: Bool, onLabel: String, offLabel: String) -> some View {
        Text(isOn ? onLabel : offLabel)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((isOn ? Color.green : Color.orange).opacity(0.2))
            .foregroundStyle(isOn ? .green : .orange)
            .clipShape(Capsule())
    }
}
