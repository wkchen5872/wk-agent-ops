---
type: Reference
title: change-review 本地交接驗證紀錄 2026-11-14-local-handoff-r01
description: improve-change-review-local-handoff（Issue #13）的 Apply 驗證：Red／Green、installer、12 套檢查、strict validate、OpenSpec verify 與 16 案盲測重播；沒有 GitHub 寫入或 Session 通知。
tags: [verification, change-review]
generated: { by: "claude-code/Claude Opus 5.5", at: "2026-11-14T16:20:00+08:00" }
sources:
  - id: cases
    resource: template/common/skills/change-review/references/acceptance-cases.md（工作區未提交版本，base e903c81）
    title: change-review 可重播案例
---

# change-review 本地交接驗證紀錄 2026-11-14-local-handoff-r01

## 範圍與版本

- Change：`improve-change-review-local-handoff`，分支 `feature/improve-change-review-local-handoff`。
- 版本：
  - 本地 HEAD `e903c81`，已合併 main `107ebfd`（Issue #17 的修正），尚未 push。
  - PR #15 是 Draft，已發布的 head 仍是 `93eef94`。
  - 受驗內容是 `e903c81` 加上未提交的修改。
- 授權：使用者先前明確授權實作本 Change，這次又經協調者轉達要求繼續。依新版契約 §9，這已足以開始 Apply，不需要 PR 批准事件，也不需要確認帳號或記錄者資格。規劃 artifacts 與 `93eef94` 相同，工作區開始時是乾淨的。
- Skill 調用：
  - `openspec-apply-change`，已安裝 SKILL.md 的 sha256 開頭為 `ed76b497`。
  - `openspec-verify-change`。
  - 開始時已安裝的 change-review SKILL.md，sha256 為 `58d02250…77442`，與協調者提供的值相同。
- 與 Issue #17 的重疊：本 Change 沒有修改批准語意。Step 3 的批准段落、CR-70 與新版 fixture 都保留，新案例從 CR-71 起編號，checklist 只新增一列。
- 執行者：Claude Code · Claude Opus 5.5，原生 Session `76a402cb-24eb-4002-b17a-88d15a596163`，Xirp `eb4f5f48-3592-47fd-90e9-21249f334648`。

| 層級 | 狀態 |
| --- | --- |
| 靜態檢查（`tests/test_change_review.sh` 的 ICR-1～5 段） | 已執行，通過 |
| 語意（盲測重播） | 16 案已執行 |
| installer（本 repo；臨時 repo 安裝與刷新） | 已執行，通過 |
| GitHub 真實寫入、Session 真實通知 | **未執行** |

## Red

先擴充 `tests/test_change_review.sh`，在原 Skill 上執行：exit 1，38 項 assertion 失敗，原本的 134 項照常通過。失敗原因都是目標行為尚未存在，例如：

- `the round is announced before the checks`
- `local evidence covers 'staged, unstaged, and untracked'`
- `an explicit local handoff path exists`
- `deferred publication path exists`
- `diagram shows the saved local report`
- 案例 `CR 本地交接：明確要求`

有兩項原本會在舊 Skill 上誤通過（「fingerprint」與「never inherits」都曾在別處出現），已改成更精確的字串後再記錄 Red。

## 實作

- **SKILL v3.1**：
  - Step 2：沒有 PR 時先固定本機快照，列出 baseline、包含的 staged／unstaged／untracked 路徑、排除範圍、逐檔指紋與算法；以工作區內容計算，結束前重算。
  - 新增「Announce before checking」：開始檢查前宣告 PR 狀態與報告去向，只是狀態說明，不是批准關卡。
  - Step 4：Author 改為引用契約 §6，保留「別名不寫成 ID」與「不沿用實作者 ID」兩項防護。
  - Step 5：本地報告依 `work-items/AGENTS.md` §9 保存；新增「Later publication of a local report」。
  - Step 6：新增「Local handoff (no PR)」。
  - 更新 description 與 Replay cases 段落。
- **checklists**：新增「本地審查」一列。
- **acceptance cases**：CR-60 補上快照與保存；新增 CR-71～CR-88。
- **review-loop.svg**：無 PR 分支改為「回報並保存本地報告與快照；不通知，明確要求才交接給已核對的實作者」。已通過 `xmllint`，並以 `rsvg-convert` 渲染後檢視，文字沒有溢出或重疊。

## Green

- 最後一次 installer 的 exit 為 0，只更新兩份 change-review 安裝副本。
- 12 個套件逐一以 `rc=$?` 取得 exit code，全部為 0、FAIL 數為 0；test_change_review 為 174 ok。
- `openspec validate improve-change-review-local-handoff --strict` 通過；`git diff --check` 通過。

## 盲測重播

做法：新的 subagent 只讀已安裝的 change-review SKILL、`work-items/AGENTS.md` §9 與契約 §6／§6.2；輸入只有 fixture 與模擬回覆，不讀 case 檔、openspec 與 WI 目錄。

| 案例 | 實際判定 | 與預期 |
| --- | --- | --- |
| CR-61（回歸：PR 失敗可通知） | 發布、回讀、核對後通知 | 相符 |
| CR-63（回歸：PR pass） | 發布、回讀、不通知 | 相符 |
| CR-71 開始提示：沒有 PR | 宣告後直接檢查，保存本地報告 | 相符 |
| CR-72 開始提示：PR 查找不明 | 宣告 unknown，只做本機檢查 | 相符 |
| CR-73 dirty checkout 快照 | 列出三種包含路徑與排除範圍 | 相符 |
| CR-75 缺少 Work Item | 照常審查，不從其他 worktree 補回 | 相符 |
| CR-77 審查中內容變動 | 報告實際快照與變動，不宣稱通過 | 相符 |
| CR-78 本地交接：明確要求 | 核對後送出，沒有 PR URL | 相符 |
| CR-79 本地交接：未要求 | 不通知 | 相符 |
| CR-80 本地交接：local-only | 不送出；修正前沒有主動詢問（見下方） | 修正後相符 |
| CR-81 本地交接：代發者 | 不送出、不通知代發者 | 相符 |
| CR-83 PR 發布失敗不改走本地交接 | 不送出 | 相符 |
| CR-84 後建 PR：內容相同 | 比對指紋後發布 | 相符 |
| CR-85 後建 PR：新增差異 | 指出差異，不發布 | 相符 |
| CR-86 後建 PR：原快照不可得 | 回報限制 | 相符 |
| CR-87 後建 PR：歷史報告明確代發 | 標明範圍後發布 | 相符 |

依重播結果在 SKILL 補上的措辭：

- local-only 與交接要求同時出現時，指出衝突並詢問，回覆前不送出（對齊 CR-80）。
- 指紋以工作區內容計算。
- 為保存報告而建立的紀錄，不是審查的前提。
- 可能讀到變動中內容的檢查不計入結果，需重跑或標為 `blocked`。
- 後補發布時 `reviewed-head` 的寫法，以及由其他 Session 代發時使用 `原報告作者`。

補完後重新 install 並重跑 12 套檢查，全部通過。

尚未處理的缺口（SUGGESTION）：

- PR 查找不明時是否可以再查一次。
- 第 9 節格式的本地報告轉成 6.2 回覆時沒有模板。
- 發布被拒之後，報告是否也要保存在本地。

## OpenSpec verify

- Completeness：完成本紀錄後為 7/7 tasks。
- Correctness：7 項 requirement（3 項 MODIFIED、4 項 ADDED）都已實作，19 個 scenario 都有對應案例。
- Coherence：遵循 design 決策 1–5；沒有新增 workflow，名稱仍是 change-review，格式仍由契約擁有。
- 結果：沒有 CRITICAL 或 WARNING，有 3 項 SUGGESTION（即上述缺口）。

## 未執行

- 真實的 PR 回覆、本地交接的 Session 訊息、後補發布都沒有實際執行。
- 重播者與實作者是同一個模型家族。
