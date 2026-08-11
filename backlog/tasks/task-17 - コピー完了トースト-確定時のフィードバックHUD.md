---
id: TASK-17
title: 'コピー完了トースト: 確定時のフィードバックHUD'
status: In Progress
assignee: []
created_date: '2026-08-11 09:19'
updated_date: '2026-08-11 09:19'
labels:
  - ui
dependencies: []
priority: medium
ordinal: 17000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
候補確定(クリップボードコピー)時に「コピーしました」のトーストHUDを表示。非アクティブ化・マウス透過のborderless NSPanelにSwiftUIカプセル(チェックマーク+テキスト、素材背景でライト/ダーク自動対応)。フェードイン150ms→保持900ms→フェードアウト300ms。表示位置はパネルがあった場所の中央(ユーザーの視線上)。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 確定時にトーストが表示され自動で消える
- [ ] #2 トーストがフォーカスを奪わずクリックも透過する
- [ ] #3 既存テスト全パス
<!-- AC:END -->
