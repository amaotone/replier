---
id: TASK-4
title: 'ReplierCore: CodexAppServerClient(実プロトコル準拠)'
status: Done
assignee: []
created_date: '2026-08-11 06:51'
updated_date: '2026-08-11 07:20'
labels:
  - core
dependencies:
  - TASK-3
priority: high
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
codex app-server --listen stdio:// を常駐spawnするProcessTransportと、initialize→thread/start→turn/startの高レベルAPI。AgentMessageDeltaNotificationをAsyncStreamで中継、TurnCompletedで完了。メソッド名・型は docs/reference/app-server-schema/ の実スキーマに準拠。account/read相当でログイン状態検出も提供。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 InMemoryTransportでthread/start→turn/start→delta受信→完了のシーケンスがテストで通る
- [x] #2 実プロトコルのメソッド名・パラメータ名がスキーマと一致している
- [x] #3 実機のcodex app-serverに接続して1ターン生成できる(統合テスト、要ログイン環境)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
実機検証済み: initialize/initialized→thread/start(developerInstructionsにsystem prompt)→turn/start→item/agentMessage/delta→turn/completed。既知の環境問題: この環境の~/.codex/config.tomlのmodel=gpt-5.6-solはmise版CLI 0.141.0が未対応でturnが失敗する(CLI更新かconfig修正で解消)。クライアント実装自体は正しいフレームで実生成を確認済み
<!-- SECTION:NOTES:END -->
