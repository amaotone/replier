---
id: TASK-26
title: '公開準備: GitHub Actions CI'
status: Done
assignee: []
created_date: '2026-08-11 14:54'
updated_date: '2026-08-11 15:00'
labels:
  - release
dependencies: []
priority: high
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
push/PRトリガーで swift test を実行するワークフロー。xcodegen+build-app.shでの.appビルド検証ジョブも含む(macOSランナー、Xcodeバージョン明示)。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ci.ymlが存在しYAMLとして妥当
- [x] #2 テストジョブとappビルドジョブが定義されている
<!-- AC:END -->
