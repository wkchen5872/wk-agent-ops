---
type: Reference
title: openspec-commit 交付擴充驗證紀錄 2026-11-14-extend-delivery-r01
description: extend-openspec-commit-delivery 的 Apply 驗證：Red／Green、本地 bare remote 實跑、installer、無 Work Item checkout 的連結核對與 20 次離線盲測重播；沒有真實交付寫入。
tags: [verification, openspec-commit, github-handoff]
generated: { by: "claude-code/Claude Opus 5.5", at: "2026-11-14T12:45:00+08:00" }
sources:
  - id: cases
    resource: template/common/skills/openspec-commit/references/acceptance-cases.md（工作區未提交版本，base a77c009）
    title: openspec-commit 可重播案例
---

# openspec-commit 交付擴充驗證紀錄 2026-11-14-extend-delivery-r01

## 範圍與版本

- Change `extend-openspec-commit-delivery`，分支 `feature/extend-openspec-commit-delivery`。
- 受驗內容是 PR #16 已發布的 head `a77c009f14f7c006e4b5c4750ce1e9c5c70d1877`，加上**未提交**的本地修改；這份本地快照並非已發布版本。
- 設計批准：[批准事件](https://github.com/wkchen5872/wk-agent-ops/pull/16#issuecomment-6871708703)，實際作者 `wkchen5872`，`artifact_revision` 與 HEAD 相同，規劃 artifacts 無差異。
- 執行者：Claude Code · Claude Opus 5.5，原生 Session `76a402cb-24eb-4002-b17a-88d15a596163`，Xirp `eb4f5f48-3592-47fd-90e9-21249f334648`。

| 層級 | 狀態 |
| --- | --- |
| 靜態檢查（`tests/test_openspec_commit.sh` 的 delivery、docs 段） | 已執行，通過 |
| 本地 Git remote（disposable bare remote 實跑） | 已執行，通過 |
| installer（本 repo；臨時 repo 新裝與重裝） | 已執行，通過 |
| 模擬 gh／MCP／Session（盲測重播） | 已執行 20 次，結果見下表 |
| 真實交付寫入（push、PR update、Closure、close） | **未執行**，依指示保留發布前人工檢核 |
| 真實 GitHub 留言 | 只有 Issue #14 的進度留言與 PR #16 的報告留言，兩則都已回讀 |

## Red

先擴充測試，再對舊的 v2.2 Skill 執行 `bash tests/test_openspec_commit.sh`：exit 1，有 112 項 assertion 失敗，原因都是目標行為尚未存在。例如：

- `delivery intent is resolved up front`
- `local commit does not imply remote writes`
- `stage outcome row for 'push'`
- `remote delivery follows local completion`
- `at least 20 replay cases (0)`
- `local development doc exists`

另外修正了兩個不算 Red 的測試問題：

- rehearsal 中的 pathspec glob 寫錯，改成 `:(glob)`。
- 一項 `unknown` 檢查原本永遠會通過，已收緊。

## Green

- 最後一次 installer 的 exit 為 0，只更新 `openspec-commit` 的安裝目標。
- 12 個套件逐一以 `rc=$?` 取得 exit code，全部為 0、FAIL 數為 0：test_agents_dir、test_bulk_read_routing、test_change_review、test_documentation_authoring、test_github_handoff、test_github_pr_publication、test_mutation_skills、test_openspec_commit、test_portable_agents_md、test_tdd_enforcement、test_work_items、test_workflow。
- `openspec validate extend-openspec-commit-delivery --strict`：通過。

### Bare remote 實跑

在 disposable bare remote 上依序驗證：

1. 已提交的 archive 不會出現在 `git status`。
2. `git log -1 --format=%H -- openspec/changes/archive/<dir>/` 能找回完成 commit。
3. push 目的地是已核對的 remote。
4. 接續時只補 push，commit 數不變；remote head 讀回等於完成 commit。
5. 封存後的 head 與先前受審的 head 不同。
6. 同一個 id 有兩個已提交的 archive 時，能偵測出歧義。
7. non-fast-forward 的 push 被拒，移動過的 remote head 保持不變。

## 圖稿與文件

四張 SVG 都通過 `xmllint`，並以 `rsvg-convert` 輸出 1600 px PNG，逐張看過修改的區塊：

- 第一次渲染時，01–03 的圖例落在框外。已移入框內後重新渲染確認。
- 04 是整張檢視。

在沒有 Work Item 的臨時 clone 上套用本 Change 的檔案（排除另一個 Change 的未追蹤副本）：

| 時間 | 結果 |
| --- | --- |
| 12:3x（外部修改前） | 44 個相對連結全部可解析 |
| 12:4x（外部修改後） | 50 個連結中有 2 個失效，見「阻礙」 |

另一個 Change 的目錄 `openspec/changes/improve-change-review-local-handoff/` 檔案時間停在 12:00，本輪沒有修改它。

## 盲測重播

做法：

- subagent 只讀已安裝的 SKILL 與必要的契約段落，並從案例檔只抽出 Fixture 與模擬回覆。
- 不讀案例檔與 Work Item。
- 由主 Session 對照案例的預期與判定。

| 輪次 | 案例 | 結果 |
| --- | --- | --- |
| 第一輪 | OC-01、02、03、04、05、07、08、09、12、13、15、16、17、19、20、21 | 16／16 與判定一致 |
| 修正後第二輪 | OC-05、13、17、20（新的 subagent） | 與修正後的判定一致 |

第一輪發現的缺口已在 SKILL 修正：

- 無關工作改為在 archive **之前**停止。
- 取消時標題改為「Change archived as cancelled」。
- 釐清授權範圍：交付授權涵蓋 push、update、Closure；最終 Review 需要另外要求。
- 7a 對已 merged／closed 的 PR 停止。
- 接續時 push 前確認 HEAD 等於找回的 commit。
- 發布 Closure 前重新讀取 PR head。
- PR 查找逾時只再讀一次。
- 區分 pending 與 blocked。
- Closure 逾時、比對後確定沒有時，只以同一工具重試一次。
- 指定 `change-review` 的入口。

第一輪也發現 OC-13 的 fixture 與隔離規則矛盾，fixture 已修正。

尚未處理的缺口：

- 取消的 Change 在 archive 時是否應略過 spec sync。
- 取消時 commit type 如何避免寫成 `feat`。
- 在 Step 1 就停止時，是否仍做唯讀的 PR 查找。

## 阻礙：本地快照被另一位寫入者修改

12:41:49，`docs/workflow/local-development.md` 被另一位寫入者修改；frontmatter 標示 `generated: codex/GPT-6`，時間寫 `22:00+08:00`。本 Session 原本被指定為唯一的產品寫入者。

這次修改加入了部分有用的說明，例如 `Refs #N` 與 Review 授權的釐清，但也造成以下問題：

1. 連結到另一個 Change 的未追蹤檔案 `openspec/changes/improve-change-review-local-handoff/proposal.md`。在乾淨的 checkout 中這個連結會失效，正式文件也因此依賴其他 Change 尚未發布的規劃。
2. 連結到不存在的 `docs/diagrams/README.md`。

依「不回退其他 Agent 變更」的指示，本 Session 沒有修改或還原這個檔案，task 5.2 也因此維持未勾選。需要由協調者確認這次修改的來源，並決定由誰修正這兩個連結。

## OpenSpec verify

- Completeness：8/9 tasks，只差 5.2，原因是上述阻礙。
- Correctness：2 項 MODIFIED、5 項 ADDED requirement 都能在 SKILL、案例、文件或 rehearsal 找到對應。
- Coherence：遵循 design 決策 1–6；正式文件與決策 6 的「不依賴未追蹤內容」目前因外部修改而不一致。
