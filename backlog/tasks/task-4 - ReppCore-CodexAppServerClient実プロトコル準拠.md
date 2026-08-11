---
id: TASK-4
title: 'ReppCore: CodexAppServerClient(実プロトコル準拠)'
status: To Do
assignee: []
created_date: '2026-08-11 06:51'
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
- [ ] #1 InMemoryTransportでthread/start→turn/start→delta受信→完了のシーケンスがテストで通る
- [ ] #2 実プロトコルのメソッド名・パラメータ名がスキーマと一致している
- [ ] #3 実機のcodex app-serverに接続して1ターン生成できる(統合テスト、要ログイン環境)
<!-- AC:END -->
