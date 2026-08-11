---
id: TASK-23
title: '返信言語のコントロール: 自動/日本語/英語トグル'
status: Done
assignee: []
created_date: '2026-08-11 14:43'
updated_date: '2026-08-11 14:49'
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
- [x] #1 言語トグルがプロンプトに反映される(3モードのテスト)
- [x] #2 デフォルトはauto(従来挙動)
- [x] #3 全テストパス
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add ReplyLanguage enum (auto/japanese/english) to Models.swift; add language field to ReplyRequest.
2. PromptBuilder: replace hardcoded same-language line with languageInstruction(for:) covering all 3 modes; keep role/one-shot sections untouched.
3. PanelModel: add language property (default .auto), thread into ReplyRequest in generate(), no auto-regen wiring.
4. PanelView: add languagePicker (自動/日本語/英語 segmented); wrap pickersRow in ViewThatFits (single row -> 2x2 fallback) since 4 segmented pickers may overflow 760pt.
5. Update ReplyRequest call sites in PromptBuilderTests/CodexReplyDrafterTests; add PromptBuilderTests (3 modes) and PanelModelTests (default, no-regen, passthrough).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented. ViewThatFits(in: .horizontal) picks single HStack row of 4 pickers if it fits within the 760pt panel, else falls back to a 2x2 VStack of HStacks — deterministic since panel width is fixed. Bumped PanelView.chromeHeight 155->180 to keep candidatesMaxHeight's approximation safe for the 2-row fallback. swift build clean; swift test 135/135 green (127 baseline + 8 new: 3 PromptBuilderTests language modes, 3 PanelModelTests for language, 2 shared with task-24's cancelGeneration). Scripts/build-app.sh succeeded; dist/Replier.app launched, alive 5s, no new crash logs, killed via pkill on dist path.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added ReplyLanguage (auto/japanese/english) end-to-end: Models.swift enum + ReplyRequest field, PromptBuilder.languageInstruction(for:) (auto keeps the original 同一言語 wording verbatim), PanelModel.language (default .auto, no auto-regen), and a 言語 segmented picker in PanelView wrapped in ViewThatFits for graceful 2-row fallback at the fixed 760pt panel width. Verified via swift test (135/135 green) and a real Scripts/build-app.sh + launch smoke test.
<!-- SECTION:FINAL_SUMMARY:END -->
