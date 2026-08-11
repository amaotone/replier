---
id: TASK-3
title: 'ReplierCore: JSON-RPC 2.0コネクション(stdioフレーミング)'
status: Done
assignee: []
created_date: '2026-08-11 06:50'
updated_date: '2026-08-11 07:07'
labels:
  - core
dependencies: []
priority: high
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
改行区切りJSONのTransport抽象+JSONRPCConnection actor。リクエスト/レスポンス相関、通知ストリーム、サーバー発リクエストのハンドラ、クローズ処理。InMemoryTransportでTDD。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 id相関(順不同レスポンス)が正しく動く
- [x] #2 通知がAsyncStreamで受け取れる
- [x] #3 サーバー発リクエストに応答できる
- [x] #4 エラーレスポンスが型付きエラーになる
<!-- AC:END -->
