# replier

![CI](https://github.com/amaotone/replier/actions/workflows/ci.yml/badge.svg)

選択したメッセージへの返信をAIが下書きする、macOSのメニューバー常駐アプリ。追加のAIサブスクは不要——手持ちのChatGPT契約を[Codex](https://developers.openai.com/codex)経由でそのまま利用する。

replier is a macOS menu-bar app that drafts replies to whatever message you've selected, using AI. It requires no separate AI subscription — it reuses your existing ChatGPT plan via the Codex CLI, so there is no server, no API key to manage, and no added cost.

<!-- TODO: screenshot -->

## 特徴

- **⌥⌘R一発で下書き**: 返信したいテキストを選択して⌥⌘Rを押すと、フローティングパネルが出現。返信の要旨を一言入力してEnterすると、短め/長めの2案が並んで生成される
- **状況に合わせて切替**: 送信先(メール/チャット)・トーン・出力形式(平文/構造化)・言語(自動判定/日本語/英語)をパネル上でその場に切替可能
- **日本語IME完全対応**: 入力欄のEnterはIMEの変換確定と衝突しない(変換確定のEnterでは誤って送信されない)
- **完全ローカル・サーバーレス**: replier自身は開発者のサーバーを持たず、メッセージ内容や認証情報にも一切触れない。生成はOpenAIへ直接送信される
- **プライバシーへの配慮**: 学習利用のオプトアウト手順をオンボーディングで案内し、Codexのセッションは履歴に残らないephemeralモードで実行される

## 動作要件

- macOS 15以降
- [Codex CLI](https://developers.openai.com/codex)がインストール済み・ログイン済みであること(ChatGPT Plus/Pro/Business等のサブスクリプション、またはAPIキー)

Codexアプリ・CLI・IDE拡張のいずれかで既にログイン済みであれば、追加設定は不要。認証情報は`~/.codex`に保存され、これらのCodexサーフェス間で共有される。

## インストール

現状はソースからのビルドのみに対応している。

```sh
git clone https://github.com/amaotone/replier.git
cd replier
Scripts/build-app.sh
```

ビルドが成功すると`dist/Replier.app`が生成されるので、`/Applications`にコピーして使う。

**Gatekeeperについて**: 配布物はad-hoc署名のため、初回起動時にGatekeeperの警告が出ることがある。その場合はFinderでアプリを右クリックして「開く」を選ぶか、ターミナルで以下を実行する。

```sh
xattr -cr /Applications/Replier.app
```

将来的にはnotarized配布やHomebrew Caskでのインストールに対応する予定。

## 使い方

### 初回オンボーディング

1. **アクセシビリティ権限の許可**: メニューバー常駐・グローバルホットキー・選択テキスト取得のために必要
2. **Codex接続確認**: `~/.codex`のログイン状態を自動チェック
3. **データ設定の確認**: 学習利用のオプトアウト手順を確認(詳細は下記「プライバシーとデータの扱い」を参照)
4. **文体サンプル登録(任意)**: 過去の自分の返信を貼り付けておくと、下書きの文体が近づく。スキップ可能

### 通常のフロー

1. 返信したいメッセージのテキストを選択(Slack / Mail.app / ブラウザ内Gmailなどアプリを問わない)
2. ⌥⌘Rでフローティングパネルを起動
3. 返信の要旨を一言入力してEnter
4. 生成された短め/長めの2案を↑↓またはTabで切り替え
5. Enterで確定した案をクリップボードへコピーし、パネルを閉じる

<!-- TODO: screenshot -->

キー操作の補足:

- `Shift+Enter`: 入力欄で改行を挿入
- `⌘Enter`: どこからでも候補を確定
- `Esc`: パネルを閉じる
- パネルからフォーカスが外れると自動的に閉じる

## プライバシーとデータの扱い

replierアプリ自体はサーバーを持たず、メッセージ内容や生成結果を外部のどこにも保存しない。返信生成はOpenAIへ直接送信される点で、ChatGPTを直接使う場合と同等の扱いになる。

ChatGPT Plus/Proなど個人プランは学習利用がデフォルトでONになっているため、以下2箇所のオプトアウトをオンボーディングで案内している。

1. ChatGPT設定 → Data Controls → 「Improve the model for everyone」をOFF([手順](https://help.openai.com/en/articles/7730893-data-controls-faq))
2. Codex側の学習許可設定もOFF(上記1では変わらない独立設定。[Codexのプライバシー設定](https://developers.openai.com/codex/privacy))

APIキー(app-serverの`apikey`モード)を使う場合はデフォルトで学習利用がOFFなので、学習ゼロを厳密に求める場合はこちらを推奨する。

また、replier経由のCodexセッションはephemeralモードで実行されるため、Codex側のセッション履歴にも残らない。

## モデル設定

デフォルトのモデルは`gpt-5.6-luna`、reasoning effortは`minimal`。設定画面から変更可能(`none`〜`xhigh`)。

## 開発

SPMパッケージ(`ReplierCore`ライブラリ + テスト)を対象とした通常の開発ワークフロー。

```sh
swift test
```

135以上のテストケースがある。

`.app`ビルドは[XcodeGen](https://github.com/yonaskolb/XcodeGen)が生成する`Replier.xcodeproj`を`xcodebuild`でビルドして作る。`project.yml`が唯一のソースで、`Replier.xcodeproj`はビルドのたびに再生成される(gitignore対象)。

```sh
Scripts/build-app.sh
```

タスク管理には[Backlog.md](https://github.com/MrLesk/Backlog.md)を使用している。

```sh
backlog task list --plain
```

アーキテクチャや設計判断の詳細は[docs/design.md](docs/design.md)を参照。`docs/reference/app-server-schema`配下は`codex app-server generate-json-schema`で生成した公式スキーマで、手動編集はしない。

## License

MIT. See [LICENSE](LICENSE).

アプリアイコンのグリフは [Hugeicons](https://hugeicons.com) の "Re" アイコン([@hugeicons/core-free-icons](https://www.npmjs.com/package/@hugeicons/core-free-icons)、MIT License)を使用しています。
