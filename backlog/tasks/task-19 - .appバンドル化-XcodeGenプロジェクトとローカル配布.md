---
id: TASK-19
title: '.appバンドル化: XcodeGenプロジェクトとローカル配布'
status: Done
assignee: []
created_date: '2026-08-11 09:22'
updated_date: '2026-08-11 13:24'
labels:
  - shell
dependencies:
  - TASK-17
  - TASK-18
priority: high
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
swift run起動からReplier.appへ。XcodeGenのproject.ymlでアプリターゲットを定義(ローカルSPMパッケージ参照、KeyboardShortcuts依存)、Info.plist(LSUIElement=true、bundle id、バージョン)、ビルドスクリプト(xcodegen→xcodebuild Release→/Applicationsへ配置可能な.app)。署名はローカル用(ad-hoc or 開発者証明書があれば自動)。AX権限がbundle id+署名に安定して紐づくことも狙い。notarization/DMG/Homebrew Caskは次フェーズ。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ビルドスクリプト一発でReplier.appが生成される
- [ ] #2 .app起動でメニューバー常駐・ホットキー・パネル・生成が動作する(Dockアイコンなし)
- [ ] #3 AX権限が.appに付与でき再ビルド後も維持される
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Scripts/build-app.sh一発でdist/Replier.app生成(ad-hoc署名、bundle id dev.amaotone.replier固定)。起動スモーク確認済み。AC2/3(GUI動作とAX権限の再ビルド維持)はユーザー実機確認待ち。実装ノート: ルートパッケージ参照はスキーム名衝突で.appが生成されないため、ReplierCoreソース直接コンパイル+canImportガード方式を採用
<!-- SECTION:NOTES:END -->
