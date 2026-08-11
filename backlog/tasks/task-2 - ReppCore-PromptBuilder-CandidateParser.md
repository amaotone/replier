---
id: TASK-2
title: 'ReplierCore: PromptBuilder / CandidateParser'
status: Done
assignee: []
created_date: '2026-08-11 06:50'
updated_date: '2026-08-11 06:58'
labels:
  - core
dependencies: []
priority: high
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
文脈+意図+トーン+文体プロファイルから3案(短め/標準/丁寧)を要求するプロンプトを組み立てる純ロジックと、モデル出力JSON(コードフェンス混入対応)を[ReplyCandidate]にパースする処理。TDDで実装。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 意図・トーン・文体サンプルがプロンプトに反映される
- [x] #2 3案のJSON出力契約が定義されている
- [x] #3 フェンス付き/前置きテキスト付き出力もパースできる
- [x] #4 全テストがswift testで通る
<!-- AC:END -->
