---
id: TASK-30
title: '署名・公証パイプライン: Developer ID + notarization'
status: In Progress
assignee: []
created_date: '2026-08-11 15:31'
updated_date: '2026-08-11 15:38'
labels:
  - release
dependencies: []
priority: high
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Developer ID Application署名+hardened runtime+notarytool公証+stapleをローカルrelease.shに統合。認証情報をGitHub Secretsに置かない方針でrelease.ymlは廃止(CIはテスト専用に)。build-app.shは署名IDを環境変数で切替(デフォルトad-hocで開発ビルド継続)。notarize.sh新設(submit --wait→staple→spctl検証→dmg再生成+staple)。README/リリースノートのGatekeeper節は公証後に簡素化。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 build-app.shがDeveloper ID署名+hardened runtimeでビルドできる(ad-hocフォールバック付き)
- [x] #2 notarize.shがsubmit→staple→spctl検証→dmg stapleまで行う
- [x] #3 release.shが署名→公証→アセット作成→GitHub Release作成を一気通貫で行う
- [x] #4 release.yml廃止、CIはテスト専用
- [ ] #5 実機での公証E2Eが成功しspctlがacceptedを返す(要証明書)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
パイプライン実装済み・失敗パス実機検証済み。hardened runtimeはad-hocでも問題なし(flags=0x10002)。AC1(Developer ID署名ビルド)とAC5(公証E2E)は証明書作成+notary profile登録待ち
<!-- SECTION:NOTES:END -->
