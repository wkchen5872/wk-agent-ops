# Design

## Context

動機見 proposal.md。既有 install.sh 將四個 launcher、opsx-branch、runtime 與 `_wt` 複製到全域路徑。hook.sh 委派 opsx-branch；hook 的 install／uninstall source lib.sh。tests/test_workflow.sh 混合了應保留與應退役的測試。

Work Item `WI-20261116-agent-commander` 的 Session 管理現況支持退役方向；交件單、指揮官與自動 Review 迴圈仍為未批准提案，不作本次依賴。

## Goals / Non-Goals

**Goals:** 刪除重複的管理工具，維持 branch-first 與 hook 行為，並讓既有安裝可安全升級。

**Non-Goals:** 不接入 Xirp／Herdr API、不新增管理器或 wrapper、不清理實際工作資料、不改動 branch ownership 的停止規則。

## Decisions

### 1. 保留既有分支功能邊界

保留 opsx-branch.sh、lib.sh、openspec-branch-creator/{hook,install,uninstall}.sh 與精簡的 workflow/install.sh。資料流仍為 Agent → opsx-branch → Git，以及 PostToolUse → hook → opsx-branch。單獨保留 hook 會缺少執行依賴，因此不採用。

移除 wt-work.sh、wt-resume.sh、wt-done.sh、pm-start.sh、runtime.sh。不保留停用 wrapper，避免繼續維護另一個命令介面。

### 2. 以固定內容識別舊安裝副本

實作時將本 Change 建立前 HEAD 中四個指令、runtime、`_wt` 以及可取得的歷史 wt-new 正式部署版本記錄為固定 SHA-256 allowlist，放在 installer 退役邏輯旁。以 repo 歷史確認 install.sh 曾部署的內容；未知舊版本保留並回報，不依賴使用者環境中的 Git 歷史或網路。

只檢查 `~/.local/bin/{wt-work,wt-resume,wt-done,pm-start,wk-workflow-runtime,wt-new}` 及 `~/.local/share/zsh/site-functions/_wt`。先辨識 symlink（含 dangling），一律保留；regular file 內容匹配才移除，失敗須回報，不吞錯誤。拒絕僅按檔名或 shebang 刪除，避免誤刪自訂工具。既有無條件 wt-new 刪除也納入保護。

升級不變更 branch、worktree、Session、設定、憑證與通用 shell PATH／fpath；既有 entropy-counter 退役邏輯維持本次前行為。

### 3. 專用 completion

刪除來源 `_wt`，改用 `_opsx-branch`，只從本地 feature branches 建議 ID，支援使用者輸入全新 ID。既有 shell 可能快取 `_wt`，文件要求重新開 shell 或重建 completion cache，不修改其他 shell 設定。

### 4. 文件、Skill 與規格一致退役

刪除 docs/workflow/wt-work-flow.md 及 docs/diagrams/wt-work-resolution.svg。更新 README.md、scripts/workflow/README.md、docs/{architecture,README}.md、docs/workflow/{guide,concepts,provider-worktrees,commit}.md、docs/diagrams/{README.md,development-lifecycle.svg}。其餘引用以定向搜尋確認，保留 local-development 的 branch-first 流程。

更新 template/common/skills/openspec-commit/SKILL.md 的舊指令引用，再執行 skills installer 同步安裝副本。保留通用交接、single writer、review identity 與 cleanup owner 規則。歷史 archive、Work Item 不改寫。

四個完整退役 capability 用 REMOVED requirements 表達，completion capability 保留原 ID 並替換契約，避免另建近似 capability。封存時確認無 requirements 的 capability 不再宣稱提供舊工具；以正式同步／封存流程處理，不在 Apply 預先修改主 specs。

## TDD Strategy and Test Boundaries

先在 fake HOME／一次性 repo 新增升級退役、修改副本與 symlink 保護、fresh install、重跑安裝的行為測試，記錄因舊安裝行為造成的 Expected Red，再精簡 installer。固定 reference fixture／digest 必須來自退役前已確認內容，不能由待測 installer 生成。

保留 branch command 的新建、切換、被別的 worktree 佔用、非法 ID，以及 hook 成功、失敗與冪等回歸測試；不修改 hook 行為。移除只驗證已批准退役功能的 resolver／Provider／設定複製／merge 測試，保留其他安全測試。

以 zsh 實際載入專用 completion 驗證註冊與候選（可攔截 `_arguments` 觀察），覆蓋空候選及非 repo；測試舊檔清理與新檔安裝同時成立。文件檢查限定現行指令與連結，允許退役說明及歷史紀錄出現舊名稱。執行 affected suite、repo 要求的完整檢查與 OpenSpec verify；SVG 有變更則視覺檢查。

## Risks / Trade-offs

- 未知舊版本殘留 → 保留並列出需人工處理路徑，不假稱完全退役。
- 舊 shell completion 快取殘留 → 提供重新載入步驟並驗證新 shell。
- 管理工具不一定具備 wt-done 的同等 merge 行為 → 文件明確交由使用者選用 Git／管理工具，保持獨立授權與 cleanup owner。
- 文件刪除造成斷鏈 → 全 repo 搜尋現行引用並驗證連結；歷史紀錄不作現行導航依據。

## Migration Plan

1. 先完成退役保護測試與內容 allowlist，再移除舊工具來源並精簡 installer。
2. 同步專用 completion、文件、圖稿與 Skill 安裝副本。
3. 用 fake HOME 驗證新裝、升級與重跑；本次實作不自動操作真實 HOME。
4. 使用者部署時重跑 workflow installer，依輸出處理保留的自訂副本並重新開 shell。
5. 回復可從退役前版本取回來源並重新安裝；不需還原工作資料，因為退役未遷移或刪除它們。
