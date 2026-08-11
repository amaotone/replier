---
id: TASK-29
title: 'リリース改善: DMG配布 + インストールガイド見直し'
status: Done
assignee: []
created_date: '2026-08-11 15:15'
updated_date: '2026-08-11 15:19'
labels:
  - release
dependencies: []
priority: high
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
.appは素のままホスト不可(フォルダのため)なので、標準的なdmg配布を追加。Scripts/make-dmg.sh(hdiutil、Applicationsシンボリックリンク付き)を作成しrelease.ymlでzipと併せて添付。リリースノートとREADMEのインストール手順を「dmgダウンロード→ドラッグ→初回右クリック開く→AX権限→codex要件」の流れに全面見直し。ソースビルド手順は開発者向けセクションへ移動。v0.1.0リリースにもdmgを追加アップロード。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 make-dmg.shでApplicationsリンク付きdmgが生成されローカルでマウント検証済み
- [x] #2 release.ymlがdmgとzipの両方を添付する
- [x] #3 READMEのインストール手順が非開発者にも分かる構成になっている
- [x] #4 v0.1.0リリースにdmgが追加されている
<!-- AC:END -->
