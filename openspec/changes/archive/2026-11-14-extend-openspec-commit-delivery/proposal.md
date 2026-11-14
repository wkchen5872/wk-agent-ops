# Proposal

## Why

使用者已確認封存交付是本機開發第四階段。現有 `openspec-commit` 完成 archive → docs → commit 後便結束，尚未串接已存在 PR 的最終版本說明、Closure 或明確要求的 close；若遠端階段失敗，原本只從未提交 archive 接續的設計也不足以恢復。需補上這段交付流程，同時避免把成功交付誤當成放棄 PR。

## What Changes

- 保留名稱、既有 archive → stage → doc-updater → git-commit-writer 順序、provider routing 與 root-session attribution。
- 在開始時分辨本地完成、遠端交付及明確的 PR close 意圖；一般本地 commit 不自動擴張為 push、merge、close 或建立 PR。
- 已確認 PR 且授權發布時，處理必要的正常 push、確認 remote head、更新 PR 說明及最終版本的 Review 證據。
- 成功交付以 `github-pr reply` 發布及回讀 Closure，停在等待另外授權的 merge；取消／被取代且明確授權時，委派 `github-pr close`，只關閉指定 PR。
- 無 PR 可完成本地流程，不自動補建 PR；Issue 另依驗收及授權結案，不連帶關閉。
- 分別記錄 archive、docs、commit、push、PR update／Review、Closure、close 的結果；中斷後依實際狀態接續，包含 commit 已完成但遠端失敗的情境。
- 將使用者已確認的四張流程圖與說明遷入 repo 的 `docs/`，使正式文件不依賴 ignored Work Item；前兩階段保留人工發布檢核、不新增 workflow skill。

驗收條件：既有本地流程與歸屬規則不退化；無 PR 不阻擋本地 commit；未授權不 push／close；成功交付不 close；close 先確認 Closure 且不碰 Issue；遠端失敗可沿用已有 commit／摘要；正式四流程文件可在沒有 Work Item 的 checkout 理解。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `openspec-commit`：擴充完成流程的授權範圍、PR 交接、獨立 close、最終版本證據及可恢復交付。

## Impact

- 來源：`template/common/skills/openspec-commit/SKILL.md`，新增其 references 及必要的薄入口說明；共用格式沿用 managed `docs/github-handoff.md`，不另存模板。
- 測試：`tests/test_openspec_commit.sh`；PR／installer 回歸沿用 `test_github_handoff.sh`、`test_github_pr_publication.sh`，必要時補本地 remote fixture。
- 文件：本 repo 的 `docs/workflow/`、`docs/diagrams/`、README／AGENTS 受影響說明。四個個人流程不散布成所有目標 repo 必須採用的 managed 規範；通用 Skill 行為仍由 template 安裝。
- 不新增 merge 能力、Issue 結案捷徑、Projects、自動派工、監看循環或前兩階段 workflow；不重做 github-pr 的 close 邏輯。
- 與 `improve-change-review-local-handoff` 沒有實作先後硬依賴，既有 change-review 已可做最終版本 Review；跨 Change 修改同一文件時須保留對方內容。
- 本次僅建立規劃，待使用者檢查後才依 github-issue 建立 Issue。未執行實作、封存、commit、push 或 GitHub 寫入。
