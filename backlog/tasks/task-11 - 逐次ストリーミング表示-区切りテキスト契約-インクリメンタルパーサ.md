---
id: TASK-11
title: '逐次ストリーミング表示: 区切りテキスト契約 + インクリメンタルパーサ'
status: Done
assignee: []
created_date: '2026-08-11 08:07'
updated_date: '2026-08-11 08:22'
labels:
  - core
dependencies: []
priority: high
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
出力契約をJSONから<<<short>>>等の区切り行テキストに変更し、1案目が完成した時点から順次表示・確定可能にする。IncrementalCandidateParserを新設(部分完成状態を扱う)。完成済み候補は他案の生成中でもEnterで確定でき、確定時に残りの生成をキャンセルする。3案未満でも1案以上あれば利用可能。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 1案目が完成した時点でUI上で選択・確定できる
- [x] #2 パーサが部分入力・ノイズ・3案未満に頑健(単体テスト)
- [x] #3 確定時に進行中の生成がキャンセルされる
<!-- AC:END -->
