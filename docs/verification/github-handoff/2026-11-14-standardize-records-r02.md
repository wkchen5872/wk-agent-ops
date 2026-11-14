---
type: Reference
title: GitHub 交接驗證紀錄 2026-11-14-standardize-records-r02
description: 針對 codex-sol-r01/F-01（代發報告的修正通知對象）的修正驗證，包括 Red／Green、installer 同步與三個 CR 案例的盲測重播；沒有真實通知或 GitHub 寫入。
tags: [verification, github-handoff, change-review]
generated: { by: "claude-code/Claude Opus 5.5", at: "2026-11-14T12:00:00+08:00" }
sources:
  - id: cases
    resource: template/common/skills/change-review/references/acceptance-cases.md（工作區未提交版本，base 2d2c1ae）
    title: change-review 可重播案例 CR-61、CR-68、CR-69
---

# GitHub 交接驗證紀錄 2026-11-14-standardize-records-r02

## 範圍

- Finding：`codex-sol-r01/F-01`（Codex Review r01，P2）。代發的實作報告，其 Author 的主要欄位是發布者；`change-review` 的 Step 6 卻直接用這些欄位找實作者，可能把修正通知送給發布者。
- 受驗內容：base `2d2c1ae` 加上未提交的工作區，延續 r01 的快照，再加上本輪修改。這不是已發布的 revision。
- 本紀錄只提供修正證據，Finding 是否 Resolved 由 Reviewer 複審判定。
- 正式追蹤：Change tasks 第 5.1 項。

## 修改

- `template/common/skills/change-review/SKILL.md` Step 6：
  - 6.1 遇到 `方式: Agent 協助代發` 或 `原報告作者` 時，主要欄位視為發布者。實作者從 `原報告作者` 及其已核對的來源取得。
  - 無法核對原實作者時一律不送出，回傳可轉交訊息，即使發布者的 Session 能在本機核對通過，也不改送給發布者。
  - 只有使用者明確指定其他收件人時才改變對象，且同樣要經過核對。
  - 6.4 的「無法核對」情境加入代發這一種。
- `template/common/docs/github-handoff.md` §6 Author 的代發說明：需要通知原作者時，對象取自原作者與其來源，不是代發者。
- 新增案例：CR-68「代發實作 A 可定位」、CR-69「代發實作 A 不可定位」。
- `tests/test_change_review.sh` 新增 F-01 區塊。

## Red

修改 Skill 之前先執行 `bash tests/test_change_review.sh`：exit 1，有 4 項 FAIL，原因都是目標行為尚未存在：

- `Step 6 reads the original author of a relayed report`
- `Step 6 never defaults to the publisher`
- `change-review has a case for '代發實作 A 可定位'`
- `change-review has a case for '代發實作 A 不可定位'`

## Green

- `bash scripts/skills/install.sh`：exit 0。
- `tests/` 12 個套件逐一以 `rc=$?` 取得 exit code，全部為 0，FAIL 數都是 0。
- `openspec validate standardize-github-collaboration-records --strict`：通過。

## 盲測重播

做法：

- 交給一個新的 subagent（Claude Code，Claude Opus 5.5）。它只讀已安裝的 change-review SKILL、契約第 6 節與 §6.5，以及從案例檔抽出的共同 fixture 和各案例的 Fixture、模擬回覆。
- 指示它不得開啟案例檔、Work Item 或搜尋案例編號，並說明這是模擬，不實際送出任何訊息。

| case | 結果 | 實際決策 |
| --- | --- | --- |
| CR-61（非代發，對照組） | pass | 核對 `mgr-123` 後通知實作者；Author 使用 Reviewer 自己的 ID |
| CR-68 代發實作 A 可定位 | pass | 主要欄位視為發布者 B；讀取 r5 並核對 `mgr-123` 後只通知 A；不把 B 當作候選 |
| CR-69 代發實作 A 不可定位 | pass | 不送出任何訊息；回傳 §6.5 格式的可轉交訊息，說明 @mei 無法定位、B 只是發布者 |

重播者回報的模糊點：fixture 沒有提供 reviewed head 與 Finding ID 的具體值，這屬於案例資料不足，不影響通知對象的判定。

## 已知限制

- 沒有實際送出 xirp 訊息，也沒有對 GitHub 做真實寫入。
- 重播者與實作者是同一個模型家族。
- Review 報告中第 7 節 withheld 措辭的非阻擋建議，本輪沒有處理，留待使用者決定。
