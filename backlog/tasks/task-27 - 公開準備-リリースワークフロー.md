---
id: TASK-27
title: '公開準備: リリースワークフロー'
status: In Progress
assignee: []
created_date: '2026-08-11 14:54'
updated_date: '2026-08-11 14:54'
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
- [ ] #1 release.ymlがタグトリガーでzip付きReleaseを作成する定義になっている
- [ ] #2 Scripts/release.shでバージョンbump+タグ付けができる
<!-- AC:END -->
