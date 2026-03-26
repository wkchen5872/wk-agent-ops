## 1. 重組 template/ 目錄結構

- [x] 1.1 建立 `template/common/` 目錄，將現有 `template/skills/`、`template/.claude/`、`template/.agent/`、`template/.github/` 移至 `template/common/` 下
- [x] 1.2 建立 `template/python/.claude/rules/`（空目錄，加 `.gitkeep`）
- [x] 1.3 建立 `template/python/hooks/pre-commit`（佔位腳本，內容說明待後續 change 實作）
- [x] 1.4 建立 `template/node/.claude/rules/`（空目錄，加 `.gitkeep`）
- [x] 1.5 建立 `template/node/hooks/pre-commit`（佔位腳本，內容說明待後續 change 實作）

## 2. 改寫 install.sh

- [x] 2.1 解析位置參數為 profile 清單（預設空 = common only）
- [x] 2.2 安裝 `common/skills/` → `.claude/skills/` 和 `.agent/skills/`
- [x] 2.3 安裝 `common/` 其餘內容（.claude/、.agent/、.github/，排除 skills/）到目標根目錄
- [x] 2.4 對每個指定 profile，安裝 `.claude/rules/` 到目標 `.claude/rules/`
- [x] 2.5 對每個指定 profile，安裝 `hooks/` 到目標 `.git/hooks/`，並 chmod +x
- [x] 2.6 加入未知 profile 的錯誤檢查（列出可用 profile，exit 1）
- [x] 2.7 安裝結束顯示已安裝 profile 與目標路徑

## 3. 新增說明文件

- [x] 3.1 新增 `docs/template-profiles.md`，說明 profile 結構、install 用法、新增 profile 的步驟

## 4. 驗證

- [x] 4.1 `bash install.sh` 確認只複製 common 內容
- [x] 4.2 `bash install.sh python` 確認 common + python rules + python hook 安裝正確
- [x] 4.3 `bash install.sh ruby` 確認輸出錯誤並 exit 1
- [x] 4.4 python hook 在目標 `.git/hooks/pre-commit` 有執行權限
