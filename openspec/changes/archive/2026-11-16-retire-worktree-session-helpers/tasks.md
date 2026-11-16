# Tasks

## 1. 安裝退役與來源精簡

- [x] 1.1 在 tests/test_workflow.sh 加入 fake HOME 的 fresh／upgrade／repeat install 與修改副本、未知副本、symlink（含 dangling）、無舊檔案例，使用退役前內容作 fixture。測試要求：先記錄 Expected Red 的測試名稱、退出碼與行為原因；斷言工作資料及無關檔案保持原樣。
- [x] 1.2 從退役前正式來源建立固定 SHA-256 allowlist，精簡 workflow/install.sh 並刪除 wt-work.sh、wt-resume.sh、wt-done.sh、pm-start.sh、runtime.sh；將 wt-new 納入相同保護，保留 opsx-branch、lib 與 branch hook。測試要求：1.1 全通過；驗證保留項目的錯誤／回報與未知副本不被刪除，installer 不依賴網路、歷史 checkout 或 Session 管理器。
- [x] 1.3 移除僅屬退役工具的測試，保留 branch／hook 的正常、失敗、非法 ID、分支佔用與冪等回歸；更新 scripts/workflow/README.md 的安裝及退役說明。測試要求：affected suite 通過，文件命令與保留入口一致，無刪測試掩蓋保留功能失敗。

## 2. 專用補全

- [x] 2.1 先新增 zsh 專用補全註冊與候選行為測試，再將來源 `_wt` 替換為 `_opsx-branch`，installer 部署新檔，文件補重新開 shell／刷新 completion 說明。測試要求：記錄 Red／Green；驗證僅註冊 opsx-branch、本地 feature ID 去重、新 ID 可用、非 repo 無錯誤，以及舊 `_wt` 按退役保護處理。

## 3. 現行文件與 Skill 同步

- [x] 3.1 刪除 docs/workflow/wt-work-flow.md 與 docs/diagrams/wt-work-resolution.svg，更新 README、docs/README、architecture、workflow/{guide,concepts,provider-worktrees,commit} 及 diagrams/{README.md,development-lifecycle.svg} 的舊操作與連結；保留通用交接與 ownership 規則。測試要求：更新文件契約測試並通過，現行連結無斷鏈，修改 SVG 完成視覺檢查；archive／Work Item 沒有改寫。
- [x] 3.2 修改 template/common/skills/openspec-commit/SKILL.md 的退役工具引用，再執行 scripts/skills/install.sh 同步 managed 副本。測試要求：template 與 .claude／.agents 安裝副本一致，Skill 不要求退役指令，檢查 installer diff 不夾帶無關配置。

## 4. 整合驗證

- [x] 4.1 執行完整 tests/test_workflow.sh、repo 必要檢查與 OpenSpec verify，核對六份 delta 與實作範圍一致。測試要求：記錄命令、退出碼、通過範圍及限制；fresh／upgrade／repeat、branch guard／hook、completion 與文件連結皆通過；真實 HOME 未被測試操作。

## Workflow follow-up

- 人類審閱並授權目前設計後，使用 openspec-apply-change 實作。
- 依後續授權封存及同步 specs；確認完整退役 capability 不再宣稱提供舊功能，並更新過時 Purpose。再依授權提交或交付。
- 真實 HOME 的安裝與自訂副本人工清理另依部署要求處理；不包含 branch／worktree／Session 清理。
