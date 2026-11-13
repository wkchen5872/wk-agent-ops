# Design

## Context

改動理由見 [proposal](proposal.md)。現行 github-pr §Shared steps／create 要求已發布的 head，缺少分支時只回報 prerequisite；shared contract、README、AGENTS、architecture 與測試均宣告四操作不 commit／push。Author 原本只有 `SESSION-ID`，允許在同一欄以 `(xirp)` 標記管理 ID。

本次 session 已實際觀察到 runtime 提供 Codex 原生 ID（`CODEX_THREAD_ID`／`CODEX_SESSION_ID`）與 Xirp 管理 ID（此機器為 `CHIRP_SESSION_ID`）。兩者可同時存在；先前未檢查而填 null 是流程缺口，不能推論所有工具都缺少 ID。這些 key 是已觀察到的本機來源，不代表 Claude Code／Antigravity 必然採相同名稱。

git-commit-writer 的現有契約會 `git add -A` 暫存整個工作區；因此它不能無條件用於混有其他工作的一次 PR 建立。本次不修改該技能的 standalone 契約。

## Goals / Non-Goals

**Goals:**

- 使用者要求 create 時，一次完成所有必要發布工作；可自行取得的資料與可執行的步驟不再轉成人類確認。
- 發文前主動找兩個 ID，各自保留來源與 namespace，讓 change-review 可以核對正確通知目標。
- 精簡既有流程與呼叫邊界，不新增一套發布 engine。

**Non-Goals:**

- 不恢復 publish 操作，不讓 reply／close 自動發布本機程式；不自動實作、merge、archive 或關閉額外工作。
- 不重構 git-commit-writer、github-issue、Work Item policy 或第三方 session 工具；不新增全域 registry、client wrapper、credential parser 或 metadata daemon。
- 此 ff 不執行 template 改動、installer、commit、push、PR 發文或既有歷史 Author 遷移。

## Decisions

### 1. create 包含必要 Git 準備，其他操作保持原界線

選擇擴充 create 而非新增 publish 或要求第二個授權口令。create 的使用者意圖已包含把相關工作建立成 PR。解析完整 repo／head／base、整理素材與候選正文後，先查是否有唯一匹配的 open PR；有就回傳 URL，不擅自解讀成 update 或發布新的 dirty 內容。

缺少明示 base 時，依現有 PR／session 已確認的分支關係、可證明的前置 Change 分支與 repo 預設分支解析合理 base，說明實際採用值；不能用 head 自己的 tracking ref 當成 base。可解析的 routine 決定自行核對，不重問。只有真的無法定位正確工作或存在無法消解的衝突，才回報具體缺口，不能向錯誤目標發文。

對新 PR：必要檢查 → 必要 commit → 必要正常 push → remote ref／compare 核對 → 最終正文 → Draft create → 回讀。只有缺少的階段才做：已有 commit 不再 commit、已發布相同 SHA 不再 push。缺遠端 head 不算缺權限；本機 sandbox 要求的 Git／網路權限走既有工具機制，不重複向使用者索取工作意圖授權。

update 保持描述更新；reply／close 保持原本副作用。create 能發布 Git 不影響 change-review 的無 Git 寫入界線。舊 publish 仍只說明已移除，不能成為另一條模糊入口。

### 2. Git 原生操作只提交明確的本次工作

先讀全部 dirty／staged paths、選定 Change／Work Item／session 與實際差異，區分本次內容與無關工作。所有工作區變更確實屬本次時，才可沿用 git-commit-writer；混合工作時用原生 Git 的明確範圍提交方式，保留原有無關 index 內容，避免 `git add -A`／普通整個 index commit 把其他人的變更混入。連同 staged／unstaged 混合情境設計可重播檢查，不另寫通用 Git wrapper。

提交遵循既有 hooks、必要測試、Conventional Commits 與 root-session attribution。不能因建立 PR 而提前實作缺少的功能、改要求或湊空 commit。hook／測試失敗先依適用授權處理真實問題，無法完成就報告失敗；不能透過 `--no-verify` 繼續。

push 前核對實際 push URL 與精確 ref，正常發布、不 force，不改 remote／認證設定。若為了讓差異只涵蓋本次工作而採用已確認但未發布的前置 base，可一併發布該既有 ref，回讀兩端；不得為此合併或製造新的前置工作。分支沒有真實差異時回報無可建立內容，不湊 placeholder。

### 3. 先做能做的工作，按實際錯誤回報，不反覆問同一件事

已配置工具有能力且沒有已知拒絕就執行。GitHub 公開可讀不等於可寫，`gh` 的登入不等於 Git push 的登入，但權限資訊不完整本身不應停住；依實際操作結果判定。認證／權限拒絕報告哪一步被拒與已完成階段，不換認證、不換工具盲送、不讓使用者用再次回答「可以」補足工具權限。

保留必要的真實失敗處理：tests／hooks 失敗、非 fast-forward、repo 衝突、無法解析工作範圍、讀取或寫入失敗，不能宣稱完成；這是具體障礙回報，不是把正常 commit／push 再拆成授權問答。

若 commit 成功、push 失敗，保留 commit 並報告；push 成功、PR 失敗，回報已發布 ref。重試先查 commit、remote ref 與 PR；未知結果先 reconciliation，不能反覆 commit 或 create。PR 正文以最後實際發布的 compare 為準，避免在 push 前就把未發布內容稱成 delivered。

### 4. Author 使用兩個固定欄位，先主動查詢

新的 PR 正文與 reply 採下列 Author；unknown model 的處理仍沿用原契約，不創造版本名稱。

```markdown
## Author

Co-Authored-By: <current posting tool>
AI-Assisted-By: <known current root-session model>
SESSION-ID: <native session ID or null>
XIRP-SESSION-ID: <Xirp management session ID or null>
```

取得順序：當前工具 runtime 明確提供的原生 Session metadata → 已配置的本機 session 工具可提供的當前 session metadata／映射。Xirp 使用當前 runtime 明確提供的管理 ID（例如此機器的 `CHIRP_SESSION_ID`），或可核對的本機管理資料；不假設一定有 `XIRP_SESSION_ID` 這個 env key。若來源衝突，核對當前工具、專案與原生／管理 ID 關係，不能確定的那欄才 null。

只讀必要的 ID 欄位／metadata，不 dump 全部 env，不搜讀整份對話或 credential。模型名稱只從當前 root session 已知資訊取得，這次允許讀 env 的用途限於 Session ID，不能誤擴充成從 env 推測模型。原生／Xirp ID 可以相同或不同，依來源語意判斷，不因字串格式相似就認定互換。

所有可用來源已查但其中一個 unavailable、尚未註冊 Xirp 或使用者明示不公開，該欄 null、說明原因，照常發文，不要求註冊 session 或讓使用者手抄。接手其他 Agent 內容時仍填本次貼文者，不從原始 Work Item 或既有 PR Author 取得當前身份。

### 5. 消費端讀新欄位，保留舊紀錄與通知核對

shared contract 是 Author 欄位唯一來源，同步 examples、Review／Changes 範本與 change-review 說明。讀到 `XIRP-SESSION-ID` 可直接作本機管理工具的候選 target，但必須核對 session 所屬專案、工具及 native ID 映射；這不直接證明 session 在本機、已讀或開始修正。

歷史只有 `SESSION-ID: <native>` 或 `<id> (xirp)` 照樣可讀，保留已知 namespace；不要求重寫舊 PR／reply，不把新 schema 當成拒讀理由。新回覆一律雙欄；更新 PR Author 時只改授權的當前貼文欄位，其他人工內容與舊回覆不變。

`simplify-change-review` 仍是未實作的獨立 change。本次只做 runtime consumer 的最小相容更新與案例，不修改它的規劃任務；後續實作該 change 時應依新的 shared Author 契約整合，不能復活單欄互填規則。

## Risks / Trade-offs

- [一鍵發布誤含其他 dirty／staged 工作] → 明確區分內容與 index；混合狀態的行為測試必須證明無關內容保留，不將整個工作區 helper 當萬用委派。
- [刪除授權詢問被誤當可略過 checks 或 force] → 新授權只涵蓋必要的正常發布，保留 hooks、真實失敗回報及推送目標核對。
- [PR 成功前已有部分 Git 副作用] → 分別回報 commit／push／PR／readback，重試重用已完成階段。
- [工具間 ID 來源不同、未經 Xirp 啟動] → 按 runtime 能力取值；先查再 null，不新增 adapter 或必備 Xirp 依賴。
- [舊測試與上游規格仍禁止任何 Git 發布] → 逐項替換只對 create 改變的斷言；保留 reply／close 等無 Git 邊界；封存前調和同名 capability。

## Migration Plan

1. 以舊 skill 保存未 commit／未 push 與雙 ID 存在但漏填的舊行為，新增可有效失敗的 tests／完整來源 fixtures。
2. 在 template 更新 create 與 Author discovery；同步 shared contract、caller 文件、examples、必要流程圖及 consumer 說明，保留未受影響操作。
3. installer 同步 managed 副本，驗證重跑及保留第三方內容；回退用前版 template 經 installer 還原，不手改安裝副本。
4. 封存另依當時 canonical github-pr 調和原有 requirement block，保留更新正文、Review、close reason 等未被取代的語意；不在本次 ff 改上游歷史規劃。

## Test Strategy

`tests/test_github_handoff.sh` 既有「無 staging／commit／push／writer delegation」「Git publication separate」與 GP-24 等案例需按 create 新範圍重寫；不能只刪斷言讓測試 Green。reply／update／close 的禁止 Git 副作用仍有獨立驗證。使用臨時 Git repo／本機 bare remote 驗證 scoped commit、push SHA、重試與無關 index 保留，避免靠文字 grep 證明 Git 正確性。

技能本身是自然語言流程，完整 Agent 重播記錄實際決策、調用與輸出：未 commit、已 commit 未 push、全已發布、唯一既有 PR、前置 base 未發布、沒有差異、403／認證拒絕、timeout、hook 失敗。對同一輸入比較舊／新版，不把模擬 PR 寫入說成真實成功。

Session fixtures 包含兩者都有、只有原生、只有 Xirp、都沒有、runtime 衝突、另一位 Agent 的來源紀錄與 legacy Author。要求先查詢再 null，檢查公開輸出只包含必要 metadata；完整 Review／Changes 可追溯且新發文是本次執行者，消費端不能通知錯人。

真實遠端與通知僅在具體 repo／ref／PR／session 目標授權內驗證，另建隔離 fixture；本次 ff 不測既有 PR #12、不通知原實作 session。保存實際結果與未測項，通過 local bare-remote 測試不代表 GitHub API 或實機通知已驗收。
