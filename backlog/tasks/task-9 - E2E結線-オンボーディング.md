---
id: TASK-9
title: E2E結線 + オンボーディング
status: In Progress
assignee: []
created_date: '2026-08-11 06:51'
updated_date: '2026-08-11 07:39'
labels:
  - ui
dependencies:
  - TASK-4
  - TASK-5
  - TASK-6
  - TASK-7
  - TASK-8
priority: medium
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
全モジュール結線: ホットキー→Capture→PromptBuilder→CodexAppServerClient→パネル表示→Paster。オンボーディング: AX権限誘導、~/.codexログイン検出(account/read)、個人プラン時のデータ設定確認チェックリスト(design.md §6)。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Slack/TextEditで選択→⌥⌘R→3案→Enterペーストが通しで動く
- [x] #2 未ログイン時に導入ガイドが表示される
- [x] #3 データ設定確認ステップが表示・記録される
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
E2E結線・オンボーディング・モデル設定(gpt-5.6-luna/xhigh)実装済み、91テストグリーン。起動確認済み(--mockで21秒安定稼働)。AC1の実機E2E(選択→⌥⌘R→ペースト)はユーザーの手動確認待ち。既知: 旧CLI 0.141.0はgpt-5.6-lunaのメタデータ未認識(warning、要CLI更新)
<!-- SECTION:NOTES:END -->
