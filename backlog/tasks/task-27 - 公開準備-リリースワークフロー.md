---
id: TASK-27
title: '公開準備: リリースワークフロー'
status: Done
assignee: []
created_date: '2026-08-11 14:54'
updated_date: '2026-08-11 15:00'
labels:
  - release
dependencies: []
priority: high
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
vX.Y.Zタグpushで .app をビルドし、ditto zipしてGitHub Releaseを自動作成するワークフロー。ローカル用のScripts/release.sh(バージョン更新+タグ作成)も用意。project.ymlのバージョンを単一情報源に。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 release.ymlがタグトリガーでzip付きReleaseを作成する定義になっている
- [x] #2 Scripts/release.shでバージョンbump+タグ付けができる
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
release.shにReplierCore.version/テストの同期bumpとswift test実行を追加(バージョンドリフト対策)。CIはmacos-latest+最新Xcode選択方式。実効性は初回push後のActions実行で確認
<!-- SECTION:NOTES:END -->
