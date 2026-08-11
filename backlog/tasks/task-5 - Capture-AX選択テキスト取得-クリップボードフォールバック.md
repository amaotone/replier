---
id: TASK-5
title: 'Capture: AX選択テキスト取得 + クリップボードフォールバック'
status: To Do
assignee: []
created_date: '2026-08-11 06:51'
labels:
  - shell
dependencies: []
priority: medium
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
AXUIElementで前面アプリのkAXSelectedTextを取得。取れない場合はNSPasteboardの内容を使用。前面アプリのbundle idからSourceApp(slack/mail/browser/other)を分類。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 選択テキストが取得できる(TextEdit等で手動確認)
- [ ] #2 AX不可時にクリップボードへフォールバックする
- [ ] #3 SourceApp分類ロジックに単体テストがある
<!-- AC:END -->
