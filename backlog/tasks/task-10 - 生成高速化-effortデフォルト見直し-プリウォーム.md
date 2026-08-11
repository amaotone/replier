---
id: TASK-10
title: '生成高速化: effortデフォルト見直し + プリウォーム'
status: Done
assignee: []
created_date: '2026-08-11 08:07'
updated_date: '2026-08-11 08:10'
labels:
  - core
dependencies: []
priority: high
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
1) reasoning effortのデフォルトをxhigh→lowに変更(xhighは出力開始前の推論で体感を大きく損なうため。設定で変更可のまま) 2) アプリ起動時にapp-serverを事前起動(現在は初回生成時のlazy起動でコールドスタートを踏む)。ReplyDraftingにデフォルト実装付きprewarm()を追加しAppContainerから起動時に呼ぶ。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 デフォルトeffortがlowになりテストが更新されている
- [x] #2 起動直後の初回生成でapp-server起動待ちが発生しない(プリウォーム済み)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
effortデフォルトlow化+起動時プリウォーム。prewarm→draftでinitializeハンドシェイクが1回だけであることをテストで担保
<!-- SECTION:NOTES:END -->
