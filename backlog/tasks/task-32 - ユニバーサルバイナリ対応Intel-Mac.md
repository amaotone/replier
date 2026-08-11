---
id: TASK-32
title: ユニバーサルバイナリ対応(Intel Mac)
status: To Do
assignee: []
created_date: '2026-08-11 18:24'
labels:
  - release
dependencies: []
priority: medium
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
現在arm64のみのビルドのため、Intel Macでは起動できない。project.ymlのARCHSをarm64 x86_64に変更し、lipoで両アーキ確認。配布物のサイズ増とビルド時間増を許容できるか評価する。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 lipo -archsでarm64とx86_64の両方が確認できる
- [ ] #2 ビルドとテストが通る
<!-- AC:END -->
