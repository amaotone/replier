# replier

メール・Slackの返信をAIで素早く下書きするMacアプリ。設計の詳細は [docs/design.md](docs/design.md) を参照。

## 開発

`swift build` / `swift test` はSPMパッケージ（`ReplierCore` ライブラリ + テスト）を対象とする通常の開発ワークフロー。

```sh
swift test
```

## ビルドと起動

配布用の `.app` は [XcodeGen](https://github.com/yonaskolb/XcodeGen) が生成する `Replier.xcodeproj` を `xcodebuild` でビルドして作る。`project.yml` が唯一のソースで、`Replier.xcodeproj` はビルドのたびに再生成される（gitignore対象）。

```sh
Scripts/build-app.sh
```

成功すると `dist/Replier.app` が生成される。Finderなどで `/Applications` にコピーして使う。

初回起動時はメニューバー常駐・グローバルホットキー・選択テキスト取得のためにアクセシビリティ権限が必要。「システム設定 > プライバシーとセキュリティ > アクセシビリティ」で `Replier.app` を許可する。ad-hoc署名はバンドルID（`dev.amaotone.replier`）に紐づくため、`Scripts/build-app.sh` で再ビルドしても許可が維持される。
