---
id: TASK-15
title: 'プロンプト修正: 指示(伝えたい内容)の役割逆転バグ'
status: Done
assignee: []
created_date: '2026-08-11 08:48'
updated_date: '2026-08-11 08:55'
labels:
  - core
dependencies: []
priority: high
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
指示欄の内容(例:「もっと簡潔に話してよ」)を受信メッセージと誤認し、それへの謝罪返信を生成してしまう。受信メッセージ/伝えたい内容の役割をプロンプトで構造的に定義し、失敗例をネガティブ例として埋め込むone-shotで矯正する。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 失敗例(長文への「もっと簡潔に話してよ」)で謝罪ではなく相手への要望文が生成される(実機検証)
- [x] #2 役割定義とone-shot例の存在がプロンプトテストで担保される
- [x] #3 既存テスト全パス
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
役割定義+one-shot対比例+見出し構造化で修正。実機の失敗シナリオでユーザーが改善を確認済み(2026-08-11)。112テスト
<!-- SECTION:NOTES:END -->
