---
id: TASK-2
title: 'ReppCore: PromptBuilder / CandidateParser'
status: To Do
assignee: []
created_date: '2026-08-11 06:50'
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
- [ ] #1 意図・トーン・文体サンプルがプロンプトに反映される
- [ ] #2 3案のJSON出力契約が定義されている
- [ ] #3 フェンス付き/前置きテキスト付き出力もパースできる
- [ ] #4 全テストがswift testで通る
<!-- AC:END -->
