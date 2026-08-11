---
id: TASK-6
title: 'Paster: クリップボード退避→⌘V合成→復元'
status: Done
assignee: []
created_date: '2026-08-11 06:51'
updated_date: '2026-08-11 08:04'
labels:
  - shell
dependencies: []
priority: medium
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
NSPasteboard退避→候補テキストをセット→CGEventで⌘V送出→元の内容を復元。ホストアプリが非アクティブ化しない前提(nonactivating panel)での動作。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ペースト後にクリップボードの元内容が復元される
- [x] #2 TextEdit相手に手動E2E確認済み
<!-- AC:END -->



## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
実装完了。AC1/2の実機確認はtask-9のE2Eで実施
<!-- SECTION:NOTES:END -->
