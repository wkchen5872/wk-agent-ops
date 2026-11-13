# Proposal

## Why

現行 github-pr 遇到尚未 commit／push 的工作會停下來要求另行授權，讓使用者已表達的「建立 PR」無法一次完成。Author 只有一個 SESSION-ID，且未要求先查 runtime，容易漏填可取得的 ID，或混淆原生 Session 與 Xirp 的通知目標。

## What Changes

- **BREAKING**：呼叫 create／要求建立 PR，即涵蓋本次工作必要的檢查、commit、正常 push、建立 Draft PR 與回讀；不因尚未 commit、尚未 push 或分支未在遠端存在就再次要求授權。
- 先整理來源與本次 PR 範圍，從 repo、branch、既有 PR 與 session 解析目標和合理 base；有唯一既有 open PR 時直接回傳，避免重複建立或為 create 擅自改寫既有正文。一般可自行完成的準備工作不轉成詢問。
- 必要 commit 只包含本次 PR 的變更，保留無關 dirty／staged 內容；push 核對完整目的 repository／ref，不 force、不 bypass hooks。認證／權限受阻時回報實際障礙，未完成的階段不宣稱成功；測試失敗、目標無法解析等真實執行障礙也如實回報，不以額外確認取代可完成的工作。
- 維持 create／update／reply／close 四個操作，不恢復 publish。update／reply／close 本身不觸發 Git 發布；精簡內容、原文保留、close 範圍與原因、版本及回讀語意沿用既有契約。
- **BREAKING**：PR 正文及新回覆的 Author 一律同時有 `SESSION-ID`（原生）與 `XIRP-SESSION-ID`（Xirp 管理 ID）。先查當前工具 runtime 與可用的本機 session metadata，能取得就填，不再未查詢便填 null；各自查不到時獨立填 null、回報原因並繼續，不猜測或互填。
- 同步 change-review 的 Author 說明、範例與 session 定位：明確 Xirp 欄位可作管理器定位線索，仍須驗證同一工具／專案／session；保留舊版只有原生 ID 或已標命名空間的管理 ID 的讀取相容性。模型歸屬仍使用當前 root-session 已知值，不由環境變數或來源作者猜測。

## Capabilities

### New Capabilities

- `github-pr`: 建立 PR 的必要 Git 發布、免重複授權與雙 Session Author 契約，以及其既有流程／消費端相容性。

### Modified Capabilities

目前 canonical specs 尚無 `github-pr`；同名能力在待封存的 `simplify-github-pr`，其「四操作均不發布 Git」「未發布分支不能建立」與單 Session 條款被本次局部取代。本次沿用能力路徑，不另造近似名稱，也不重寫既有 change。封存前須依實際主規格狀態調和完整 MODIFIED／必要 REMOVED deltas，保留未被本次改動的要求，避免相反規則並存。

## Impact

- template github-pr skill、acceptance cases／examples；shared github-handoff 契約、必要交接圖文；change-review 對 Author 的讀取與交接說明。
- README、AGENTS、architecture 與現行 caller 的 Git 發布邊界；`tests/test_github_handoff.sh`、受影響的 `tests/test_change_review.sh`；由 installer 同步所有 managed 副本。
- 支援 Claude Code、Codex、Antigravity；Session 的實際取得方式依 runtime 能力，不新增通用 session adapter、全域索引、credential parser 或背景服務。
- 不更動 github-issue 的獨立行為或 Work Item policy，不重構 git-commit-writer，不追溯修改歷史 PR／Review 作者；既有單 ID 文本仍可閱讀。
- 驗收需涵蓋未 commit／未 push 到 PR 的完整呼叫順序、精確提交範圍、重試與權限拒絕，以及雙 ID 的實際發現／發布／消費；不能只檢查欄位名稱存在。此次 ff 僅建立規劃，不執行 commit、push 或任何遠端寫入。
