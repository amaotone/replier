---
id: TASK-20
title: 'パネルUI改善2: 自動サイズ・3行入力・文脈非表示・プリセット刷新'
status: Done
assignee: []
created_date: '2026-08-11 13:31'
updated_date: '2026-08-11 13:48'
labels:
  - ui
dependencies: []
priority: high
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
スクショフィードバック4点: 1)候補カードが下端で見切れる→パネル高さをコンテンツに自動追従(上限あり) 2)要旨入力欄を3行程度の複数行に(Enter=生成、Option+Enter=改行、IME安全維持) 3)受信メッセージのプレビュー表示を廃止(キャプチャとLLM送信は継続) 4)プリセットチップを「わかりました」「ごめんなさい」「確認します」「後で連絡します」に変更(タップで要旨欄に入力+即生成)。抽象intent(accept/decline等)は廃止し要旨文字列に一本化。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 候補カードが見切れずに全文表示される(パネル自動サイズ)
- [ ] #2 入力欄が3行程度でEnter=生成、Option+Enter=改行
- [x] #3 受信メッセージが画面に表示されない(生成には使われる)
- [x] #4 新プリセット4つがタップで要旨に入り即生成される
- [x] #5 全テストパス
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
パネル自動サイズ(上限=画面70%、上端アンカー維持)、3行入力(TextField axis vertical + onSubmit)、ReplyIntent削除しgist文字列に一本化。AC1(見切れ解消)とAC2(Enter/Option+Enter/IME挙動)は実機確認待ち — TextField(axis:.vertical)のReturn=submit挙動はネイティブAppKitでは文書上確実だが対話検証は未実施
<!-- SECTION:NOTES:END -->
