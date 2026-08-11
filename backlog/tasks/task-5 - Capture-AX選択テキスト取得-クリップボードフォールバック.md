---
id: TASK-5
title: 'Capture: AX選択テキスト取得 + クリップボードフォールバック'
status: Done
assignee: []
created_date: '2026-08-11 06:51'
updated_date: '2026-08-11 08:04'
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
- [x] #1 選択テキストが取得できる(TextEdit等で手動確認)
- [x] #2 AX不可時にクリップボードへフォールバックする
- [x] #3 SourceApp分類ロジックに単体テストがある
<!-- AC:END -->



## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
実装完了(56テスト)。AC1/2の実機確認はtask-9のE2Eで実施
<!-- SECTION:NOTES:END -->
