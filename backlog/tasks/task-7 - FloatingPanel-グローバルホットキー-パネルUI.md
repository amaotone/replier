---
id: TASK-7
title: FloatingPanel + グローバルホットキー + パネルUI
status: To Do
assignee: []
created_date: '2026-08-11 06:51'
labels:
  - ui
dependencies:
  - TASK-2
priority: medium
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
NSPanel(.nonactivatingPanel)サブクラス+NSHostingView。KeyboardShortcutsで⌥⌘R。パネル内SwiftUI: 文脈プレビュー・意図チップ(承諾/お断り/質問/後で連絡/自由指示)・トーン選択・3案ストリーミング表示・↑↓/Tab/Enter/Escのキーボードナビ。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ホットキーでパネルが表示され、ホストアプリがアクティブなまま
- [ ] #2 3案がストリーミング表示される(モックバックエンドで可)
- [ ] #3 ↑↓選択・Enter確定・Escキャンセルが動く
<!-- AC:END -->
