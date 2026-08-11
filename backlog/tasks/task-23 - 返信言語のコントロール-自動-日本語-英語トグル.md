---
id: TASK-23
title: '返信言語のコントロール: 自動/日本語/英語トグル'
status: In Progress
assignee: []
created_date: '2026-08-11 14:43'
updated_date: '2026-08-11 14:43'
labels:
  - ui
dependencies: []
priority: medium
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
現状は「受信メッセージと同じ言語で返信」の自動のみ。ReplyLanguage enum(auto/japanese/english)を追加し、ピッカー行に「言語」セグメントを追加。auto=受信と同言語、japanese=必ず日本語、english=必ず英語。他のトグル同様、変更時の自動再生成なし。デフォルトauto。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 言語トグルがプロンプトに反映される(3モードのテスト)
- [ ] #2 デフォルトはauto(従来挙動)
- [ ] #3 全テストパス
<!-- AC:END -->
