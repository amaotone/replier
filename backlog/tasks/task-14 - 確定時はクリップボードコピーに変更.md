---
id: TASK-14
title: 確定時はクリップボードコピーに変更
status: Done
assignee: []
created_date: '2026-08-11 08:33'
updated_date: '2026-08-11 08:41'
labels:
  - ui
dependencies: []
priority: high
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
候補確定時の自動ペースト(⌘V合成)を廃止し、クリップボードへコピーしてパネルを閉じる方式に変更。ペーストのタイミング依存が消え堅牢に。Paster.swiftは将来のオプション用に残すが呼び出しは削除。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 確定で候補テキストがクリップボードに入りパネルが閉じる
- [x] #2 自動ペーストが呼ばれない
<!-- AC:END -->
