---
id: TASK-12
title: 'ゼロクリック生成: 自動意図でパネル表示と同時に生成開始'
status: Done
assignee: []
created_date: '2026-08-11 08:07'
updated_date: '2026-08-11 08:22'
labels:
  - ui
dependencies: []
priority: high
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
ReplyIntentに.autoを追加(メッセージから最適な返信意図をモデルが推測)。パネル表示と同時に.autoで生成開始し、意図チップとトーンは「再生成」のトリガーに降格。目標: ⌥⌘R→Enterの2アクションで返信完了。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 パネル表示と同時に生成が始まる(チップ操作不要)
- [x] #2 チップ/自由指示/トーン変更で現在の生成をキャンセルして再生成する
- [x] #3 既存テスト+新規テストが全て通る
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
実装完了・101テスト。体感確認はユーザーのswift run待ち
<!-- SECTION:NOTES:END -->
