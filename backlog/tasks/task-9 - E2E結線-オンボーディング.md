---
id: TASK-9
title: E2E結線 + オンボーディング
status: To Do
assignee: []
created_date: '2026-08-11 06:51'
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
- [ ] #2 未ログイン時に導入ガイドが表示される
- [ ] #3 データ設定確認ステップが表示・記録される
<!-- AC:END -->
