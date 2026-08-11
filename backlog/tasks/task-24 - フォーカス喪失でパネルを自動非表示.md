---
id: TASK-24
title: フォーカス喪失でパネルを自動非表示
status: Done
assignee: []
created_date: '2026-08-11 14:43'
updated_date: '2026-08-11 14:49'
labels:
  - ui
dependencies: []
priority: medium
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
別アプリ・別ウィンドウにフォーカスが移ったら(didResignKeyNotification)パネルを閉じる。Spotlight等と同じ振る舞い。閉じる際に進行中の生成をキャンセルしてトークン浪費を防ぐ。トーストは対象外。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 別アプリをクリック/⌘Tabでパネルが閉じる
- [x] #2 非表示時に進行中の生成がキャンセルされる
- [x] #3 全テストパス+.appビルド成功
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. PanelController: add resignKeyObserver + currentModel; register NSWindow.didResignKeyNotification for the floating panel once in makePanel() (panel created lazily once).
2. hide() cancels currentModel's in-flight generation then orderOut(nil); verify no infinite loop (queue: .main defers the notification callback so orderOut's synchronous resign never reenters hide() synchronously, and the second hide() call is a harmless no-op since orderOut on an already-ordered-out/non-key window doesn't refire the notification).
3. PanelModel: add public cancelGeneration() reusing confirmSelection()'s cancellation semantics (cancel generationTask only, no phase/partials mutation).
4. Verify ToastPresenter's toast panel never becomes key (canBecomeKey == false) so it can't trigger the floating panel's resign-key path; verify onboarding window intentionally does (desirable auto-close).
5. Tests: PanelModelTests for cancelGeneration() (cancels stream, phase not .failed, harmless when idle).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented. PanelController.observeResignKey(of:) registers once in makePanel() using queue: .main (async dispatch), so hide()'s orderOut(nil) never reenters hide() synchronously; the re-entrant call it schedules is a no-op (panel already ordered out/non-key => no second notification, cancelGeneration() already idle). confirm() path (copy -> hide -> toast) unaffected: PanelModel.confirmSelection() already cancels generationTask before hide() runs; hide()'s cancelGeneration() call is a harmless duplicate. Verified ToastPresenter.ToastPanel.canBecomeKey is hardcoded false, so showing the copy toast cannot steal key status from the floating panel / cannot trigger its resign-key handler. OnboardingWindowController's window is a regular NSWindow with makeKeyAndOrderFront, so opening onboarding while the panel is open legitimately resigns the panel's key status and closes it (desired). swift test 135/135 green; swift build clean; Scripts/build-app.sh succeeded; dist/Replier.app launched, alive 5s, no new crash logs, killed via pkill on dist path. GUI focus-loss behavior itself needs user verification (no automated window-server test).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Panel now observes NSWindow.didResignKeyNotification (registered once when the panel is created) and calls hide() on focus loss, giving Spotlight-like auto-hide. hide() also calls the new PanelModel.cancelGeneration() (same semantics as confirmSelection()'s cancellation, doesn't flip phase to .failed) so losing focus mid-generation stops the in-flight request. Reasoned through and confirmed no resign->hide->resign infinite loop (async notification dispatch + orderOut idempotency), and that the copy toast (never key) can't interfere with the confirm flow while opening onboarding intentionally closes the panel. Verified via swift test (135/135 green) and a real build-app.sh + launch smoke test.
<!-- SECTION:FINAL_SUMMARY:END -->
