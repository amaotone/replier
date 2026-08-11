---
id: TASK-13
title: '指示入力ファースト: 返信欄表示→Enterで3案生成'
status: Done
assignee: []
created_date: '2026-08-11 08:33'
updated_date: '2026-08-11 08:41'
labels:
  - ui
dependencies: []
priority: high
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
パネル表示時の自動生成を廃止し、指示入力欄(返信の要旨)にオートフォーカス。Enterで生成開始(空ならauto意図、入力ありならその要旨で生成)。意図チップはワンタップ生成のショートカットとして維持。effortデフォルトをminimalに変更し、設定にnoneを追加(実機で両方動作確認済み)。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 パネル表示時に指示入力欄にフォーカスがあり自動生成されない
- [x] #2 Enterで生成開始(空=auto、入力あり=要旨として反映)
- [x] #3 effortデフォルトがminimal、設定にnoneが選択肢にある
<!-- AC:END -->
