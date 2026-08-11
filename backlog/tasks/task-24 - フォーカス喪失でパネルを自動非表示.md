---
id: TASK-24
title: フォーカス喪失でパネルを自動非表示
status: In Progress
assignee: []
created_date: '2026-08-11 14:43'
updated_date: '2026-08-11 14:43'
labels:
  - ui
dependencies: []
priority: medium
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
別アプリ・別ウィンドウにフォーカスが移ったら(didResignKeyNotification)パネルを閉じる。Spotlight等と同じ振る舞い。閉じる際に進行中の生成をキャンセルしてトークン浪費を防ぐ。トーストは対象外。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 別アプリをクリック/⌘Tabでパネルが閉じる
- [ ] #2 非表示時に進行中の生成がキャンセルされる
- [ ] #3 全テストパス+.appビルド成功
<!-- AC:END -->
