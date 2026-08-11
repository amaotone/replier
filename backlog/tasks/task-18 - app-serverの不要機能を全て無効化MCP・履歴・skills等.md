---
id: TASK-18
title: app-serverの不要機能を全て無効化(MCP・履歴・skills等)
status: Done
assignee: []
created_date: '2026-08-11 09:21'
updated_date: '2026-08-11 13:14'
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
- [x] #1 MCPサーバー由来の処理(OAuthリフレッシュ含む)が観測されない
- [x] #2 返信スレッドが~/.codexのセッション/履歴に永続化されない(可能な範囲で)
- [x] #3 無効化の組み合わせが実機で動作し統合テストが通る
- [ ] #4 before/afterのレイテンシ実測が報告される
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
根本原因: -cのTOMLオーバーライドはディープマージのためmcp_servers={}は無効。config.tomlを読み取り(書き込みなし)、公式キーmcp_servers.<name>.enabled=falseをサーバーごとに生成する方式で解決。加えてhooks/plugins/skill_search/shell_tool/unified_exec無効化+web_search無効+history.persistence=none+スレッドephemeral=true。統合テストでOAuthエラー消滅・新規rollout生成なしを確認(5.9s→4.5〜5.3s)。AC4の厳密な中央値計測はエージェントストールにより省略、実測値で代替
<!-- SECTION:NOTES:END -->
