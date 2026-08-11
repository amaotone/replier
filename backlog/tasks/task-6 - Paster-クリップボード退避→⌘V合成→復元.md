---
id: TASK-6
title: 'Paster: クリップボード退避→⌘V合成→復元'
status: To Do
assignee: []
created_date: '2026-08-11 06:51'
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
- [ ] #1 ペースト後にクリップボードの元内容が復元される
- [ ] #2 TextEdit相手に手動E2E確認済み
<!-- AC:END -->
