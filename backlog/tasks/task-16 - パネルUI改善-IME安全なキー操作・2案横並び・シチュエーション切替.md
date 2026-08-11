---
id: TASK-16
title: 'パネルUI改善: IME安全なキー操作・2案横並び・シチュエーション切替'
status: In Progress
assignee: []
created_date: '2026-08-11 09:00'
updated_date: '2026-08-11 09:00'
labels:
  - ui
dependencies: []
priority: high
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
ユーザーフィードバック6点: 1)表示時に入力欄へ確実にフォーカス 2)日本語IMEの変換確定Enter/変換中↑↓を送信・選択操作と衝突させない(onSubmitベース+フォーカス分離) 3)候補を短め/長めの2案横並い・全文表示に変更(sentinel契約もshort/longへ) 4)おまかせ(auto意図)廃止、空Enterは何もしない 5)シチュエーション(メール/チャット)切替を追加しプロンプトに反映(sourceAppからデフォルト決定) 6)トーン・シチュエーション変更で自動再生成しない(次回生成から反映)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 パネル表示のたびに入力欄にフォーカスがある
- [ ] #2 IME変換確定のEnterで生成が走らない(onSubmit方式)、変換中の↑↓が奪われない
- [ ] #3 短め/長めの2案が横並びで全文表示される
- [ ] #4 auto意図が削除され空Enterは無操作
- [ ] #5 メール/チャット切替がプロンプトに反映される
- [ ] #6 トーン/シチュエーション変更では生成が走らない
<!-- AC:END -->
