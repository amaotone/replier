---
id: TASK-21
title: 'パネルUI改善3: フォーカス堅牢化・コンパクト表示・Shift+Enter改行・出力形式・Esc'
status: In Progress
assignee: []
created_date: '2026-08-11 14:07'
updated_date: '2026-08-11 14:07'
labels:
  - ui
dependencies: []
priority: high
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
フィードバック5点: 1)フォーカス失敗の再発→リトライ+AppKitフォールバックで堅牢化 2)生成前の余白過大→ルートのmaxHeightフレームが原因(コンテンツが上下センタリングされ空白発生)。composing時はコンテンツにフィットする高さに 3)改行をShift+Enterに変更(NSTextViewベースのエディタでhasMarkedText判定によりIME完全対応) 4)出力形式トグル追加: 平文/構造化(箇条書き多め)をプロンプトに反映(変更時の自動再生成なし) 5)Escをパネルレベル(FloatingPanel.cancelOperation)で処理しフォーカス位置に関わらず閉じる
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 パネル表示のたびに入力欄へ確実にフォーカス(リトライ機構)
- [ ] #2 生成前のパネルがコンテンツ高さにフィットし余白がない
- [ ] #3 Shift+Enterで改行、Enterで生成、IME変換確定Enterは無反応
- [ ] #4 平文/構造化の切替がプロンプトに反映される
- [ ] #5 フォーカス位置に関わらずEscで閉じる
- [ ] #6 全テストパス+.appビルド成功
<!-- AC:END -->
