---
id: TASK-28
title: '公開準備: アプリアイコン'
status: Done
assignee: []
created_date: '2026-08-11 14:54'
updated_date: '2026-08-11 15:04'
labels:
  - release
dependencies: []
priority: medium
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
スクリプトで生成できるシンプルなアイコン(吹き出しモチーフ等)を.icns化しアプリに組み込む。project.ymlにアイコン設定を追加し、build-app.shの成果物に反映。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 dist/Replier.appにカスタムアイコンが表示される
- [x] #2 アイコン生成がスクリプトで再現可能
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
ReIconグリフは@hugeicons/core-free-icons 4.2.3から取得(MIT確認済み)。READMEにクレジット追加。16pxでは判読性が落ちる(2文字ワードマークの限界)が指定グリフの特性として許容
<!-- SECTION:NOTES:END -->
