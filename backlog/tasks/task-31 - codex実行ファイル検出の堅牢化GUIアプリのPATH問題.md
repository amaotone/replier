---
id: TASK-31
title: codex実行ファイル検出の堅牢化(GUIアプリのPATH問題)
status: Done
assignee: []
created_date: '2026-08-11 16:32'
updated_date: '2026-08-11 17:07'
labels:
  - core
dependencies: []
priority: high
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
.app起動時はターミナルのPATHを継承しないため、mise/volta/nvm/npm-global配下のcodexを見つけられず「実行ファイルが見つかりません」で生成失敗する。実際にmise shim(~/.local/share/mise/shims/codex)が存在しても検出できていない。対策: 候補パスの拡充、ログインシェル経由のPATH解決、バージョンマネージャのwhich委譲、UserDefaultsによる手動パス指定+設定UI、エラーメッセージの改善。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 mise/volta/npm-global配下のcodexを.app起動でも検出できる
- [x] #2 ログインシェル(dscl由来)経由のPATH解決フォールバックがある
- [x] #3 設定画面から実行ファイルパスを手動指定でき、UserDefaultsに永続化される
- [x] #4 エラーメッセージが検索場所と設定方法を案内する
- [x] #5 検出ロジックの純粋部分に単体テストがある
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
最小PATH(env -i)実証済み: mise shimを0.004秒で解決。候補にChatGPT.app同梱codex(/Applications/ChatGPT.app/Contents/Resources/codex)とstandalone管理インストールも追加。151テスト
<!-- SECTION:NOTES:END -->
