---
id: TASK-18
title: app-serverの不要機能を全て無効化(MCP・履歴・skills等)
status: In Progress
assignee: []
created_date: '2026-08-11 09:21'
updated_date: '2026-08-11 09:21'
labels:
  - core
dependencies: []
priority: high
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
テキスト生成専用途に不要なオーバーヘッドを排除する。mcp_servers={}指定後もlinear MCPのOAuthリフレッシュが観測されており不完全。codex 0.147.0の設定面(features/--disable、history永続化、hooks、skills、web_search等のツール定義)を調査し、確実に効く無効化オプションの組を特定して spawn引数に反映。履歴・セッション永続化の無効化はプライバシー面(返信内容が~/.codexに残らない)でも重要。before/afterで起動時間・初回デルタまでのレイテンシ・stderrノイズを実測して効果を報告。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 MCPサーバー由来の処理(OAuthリフレッシュ含む)が観測されない
- [ ] #2 返信スレッドが~/.codexのセッション/履歴に永続化されない(可能な範囲で)
- [ ] #3 無効化の組み合わせが実機で動作し統合テストが通る
- [ ] #4 before/afterのレイテンシ実測が報告される
<!-- AC:END -->
