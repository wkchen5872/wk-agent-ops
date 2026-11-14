---
type: Reference
title: GitHub 交接驗證紀錄 2026-11-14-standardize-records-r01
description: standardize-github-collaboration-records 的 Apply 驗證：Red／Green、受影響套件、installer、OpenSpec 驗證與 17 個新案例的離線重播；未做真實 GitHub 寫入。
tags: [verification, github-handoff]
generated: { by: "claude-code/Claude Opus 5.5", at: "2026-11-14T11:00:11+08:00" }
sources:
  - id: cases
    resource: template/common/skills/{github-issue,github-pr,change-review}/references/acceptance-cases.md 與 template/common/docs/github-handoff.md 附錄 A（工作區未提交版本，base 2d2c1ae）
    title: 各入口與共同的可重播案例
---

# GitHub 交接驗證紀錄 2026-11-14-standardize-records-r01

## 範圍與版本

- Change：`standardize-github-collaboration-records`，分支 `feature/standardize-github-collaboration-records`。
- 受驗內容：base commit `2d2c1ae` 加上**尚未提交**的工作區修改（template、安裝目標、tests、README、AGENTS.md、`docs/architecture.md`）。本紀錄不代表任何已發布的 remote revision。
- 執行者：Claude Code · Claude Opus 5.5，原生 Session `76a402cb-24eb-4002-b17a-88d15a596163`，Xirp `eb4f5f48-3592-47fd-90e9-21249f334648`。

| 驗證類別 | 狀態 |
| --- | --- |
| 格式與存在性（靜態測試） | 已執行，通過 |
| 語意（案例重播） | 已執行 17 例離線重播，其中 15 例為盲測 |
| installer（本 repo 與臨時 Git repo 新裝／重裝） | 已執行，通過 |
| Git 本地 remote | 本 Change 未改 Git 發布行為；以既有 `tests/test_github_pr_publication.sh` 回歸，通過 |
| 真實 GitHub 寫入 | **未執行**；沒有授權的測試 repository，不宣稱 gh／MCP 實際寫入成功 |

## Red

改寫實作前先擴充測試（task 1.1），以舊契約執行：

| 指令 | exit | 結果 |
| --- | --- | --- |
| `bash tests/test_github_handoff.sh` | 1 | 94 項 FAIL，原因皆為目標行為不存在，例如 `§6 shared frame defines '## Next actions'`、`github-issue defines close`、`PR close never closes an Issue`、`Issue close posts Closure before closing ()`、`every §6.1 Issue Author has both Session IDs (0/0)` |
| `bash tests/test_change_review.sh` | 1 | 12 項 FAIL，例如 `a remote pass is no longer held back for a request`、`change-review has a case for 'PR pass 發布'` |

另有一項既有失敗與本 Change 無關：`repository github-pr synchronized`。原因是 `template/common/skills/github-pr/.DS_Store`（被 Git 忽略）不在安裝目標中。重跑 installer 後，該檔被複製到安裝目標，檢查隨之通過；此檔未納入 Git。

為了反映新行為，改寫了以下舊斷言：

- update 留言與審查、修正回覆的標題順序（加入 Next actions，審查回覆另加 Verification）。
- PR close 改為不關閉 Issue；close reason 的檢查從 github-pr 移到 github-issue close。
- 其中一項 `§7` 的 deny 原本永遠成立，已改為能真正偵測舊文字。

## Green

最終實作完成並執行 `bash scripts/skills/install.sh`（exit 0）後，再跑 `tests/` 下全部套件，結果如下：

| 套件 | exit | ok |
| --- | --- | --- |
| test_agents_dir | 0 | 35 |
| test_bulk_read_routing | 0 | 41 |
| test_change_review | 0 | 130 |
| test_documentation_authoring | 0 | 全部 PASS |
| test_github_handoff | 0 | 420 |
| test_github_pr_publication | 0 | 23 |
| test_mutation_skills | 0 | 89 |
| test_openspec_commit | 0 | 155 |
| test_portable_agents_md | 0 | 18 |
| test_tdd_enforcement | 0 | 28 |
| test_work_items | 0 | 79 |
| test_workflow | 0 | 67 |

重播後依結果修了三處措辭，修完再次 install。

更正：上表與中途的一次重跑，exit 欄位是用 `printf … $(basename …)` 迴圈取得的，`$?` 實際是 `basename` 的值，不能當證據；上表的 ok 數與 FAIL 計數則來自各自的 log，可以採信。後來正確取得 exit code 時，發現補措辭時在契約範例寫入具名工具，`contract and rule name no secondary tool` 因此 FAIL。改為 `<工具>`／`<模型>` 後再次 install，以 `rc=$?` 逐一取得 exit code，最終 12 個套件 exit 都是 0、FAIL 數都是 0，`openspec validate standardize-github-collaboration-records --strict` 也通過。

`test_github_handoff.sh` 與 `test_change_review.sh` 在臨時 Git repo 中驗證以下 installer 行為：

- 新裝與重裝都會送出 managed 契約、交接圖，以及三個 Skill 與其 references。
- 重裝會覆寫本地改動，第三次安裝結果不變（冪等）。
- 無關的 script、圖與 Work Item 保持不變，credential 設定不會出現在輸出中。
- `AGENTS.md → agent-protocol → 契約` 的入口鏈可以走通。

本 repo 的 `.codex/` 沒有被 installer 改動。

## 圖稿

`docs/diagrams/github-handoff.svg` 與 `change-review/references/review-loop.svg` 都通過 `xmllint --noout`，也都用 `rsvg-convert` 輸出 PNG。人工檢視修改區塊後，文字沒有超出框線，也沒有重疊。未做瀏覽器渲染。

## OpenSpec verify

依 `openspec-verify-change` 檢查三個面向：

- Completeness：最終 12/12 tasks。
- Correctness：26 項 ADDED／MODIFIED requirement 都在契約或 Skills 找到對應內容；scenario 由靜態檢查與案例覆蓋。
- Coherence：遵循 design 決策 1–7。

**SUGGESTION**：審查回覆依已確認的範例不再單列 `phase`。設計審查以「設計審查」註明，未註明即為 implementation（契約 §6.2）。請 Reviewer 確認這個寫法符合 change-review 規格中「record phase」的要求。

## 案例重播

做法如下：

- 從案例檔只抽出共同 fixture，以及各案例的 Fixture 與模擬回覆。
- 交給新的 Claude Code（Claude Opus 5.5）subagent，讓它讀已安裝的契約與三個 Skill 後回答。
- 指示它不得開啟 acceptance-cases／examples。
- 結果由主 Session 對照各案例的預期呼叫、禁止與判定。

| case | 結果 | 備註 |
| --- | --- | --- |
| GI-38 不同 WI 同一工作 | pass | 沿用 #40，不判衝突 |
| GI-39 相同本地 ID | pass | 停下詢問，不寫入 |
| GI-40 Issue 回覆 | pass | Handoff → Changes → Next actions → Author |
| GI-43 close 完成 | pass | 先發布並回讀 Closure，再關閉並讀回 COMPLETED |
| GI-45 驗收未完成 | pass | 不關閉，建議以 update 說明等待中的驗收 |
| GI-47 理由不符 | pass | 回報 reason 不符，不 reopen |
| GI-49 摘要成功但 close 失敗 | pass | 分開回報；重跑沿用 c14，只補 close |
| GP-47 準備合併 | pass | 只發 reply，不 close／merge，#42 不動 |
| GP-48 代發 | pass | 原作者與發布者分開；發現格式缺口（已補） |
| GP-50 close 直接 Issue 與依賴 | pass | 只關 PR，#7、#8 不動 |
| GP-57 重跑 | pass | 沿用 c2 |
| GP-59 已 merged | pass | 不 close，記錄 m9 |
| CR-63 PR pass 發布 | pass | 發布並回讀，不發通知 |
| CR-66 PR unknown 的 pass | pass | 只在本機回報 |
| CR-67 pass 後 head 移動 | pass | 仍綁定 c4d5e6f 並標 stale；發現措辭缺口（已補） |
| C-29 雙 Session 未知 metadata | pass（非盲） | 契約附錄 A 含答案 |
| C-33 摘要過時 | pass（非盲） | 同上 |

重播後已修正的缺口：

- 代發時，原作者的工具與模型在 Author 中的寫法（契約 §6 Author）。
- PR 的 Closure，其 Handoff 要列 `branch`（§6.7）。
- stale 只是附註，結論仍是三種 verdict 之一，報告照常發布（change-review Step 4）。

未修正、留給 Review 判斷的缺口：

- 只拿到修正 commit、沒有前一份報告時，如何找回既有的 Finding ID。
- 使用者以 not planned 取消卻沒給理由時，應先詢問，還是發一則精簡的 Closure。
- 部分 fixture 沒寫 reviewer 的工具與模型，也沒寫 head branch 名稱。
- 共同案例寫在契約附錄 A，無法以「先讀契約」的方式做盲測。

## 已知限制

- 沒有真實 GitHub 寫入與 MCP 實測。
- 重播的執行者與實作者是同一個模型家族，獨立性有限。
- 本紀錄對應未提交的工作區內容；commit、push、PR 與 archive 都尚未執行。
