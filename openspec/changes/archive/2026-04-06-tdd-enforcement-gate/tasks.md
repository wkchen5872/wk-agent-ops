## 1. TDD 強制規則檔

- [x] 1.1 建立 `template/common/.claude/rules/tdd-enforcement.md`，內容包含：先寫失敗測試（Red）→ 實作（Green）→ 重構、全部測試通過才能進下一個 task
  - 測試要求：驗證檔案存在，且包含 Red/Green/Refactor 關鍵字
- [x] 1.2 建立 `template/common/.github/instructions/tdd-enforcement.md`，內容與 1.1 相同
  - 測試要求：驗證兩個檔案內容一致（diff 為空）

## 2. Node pre-commit hook 實作

- [x] 2.1 將 `template/node/hooks/pre-commit` 從 placeholder 改為實際執行 `npm test` 的 gate hook
  - 邏輯：偵測有 `.js/.ts/.jsx/.tsx` staged changes → 執行 `npm test` → 失敗則 exit 1
  - 偵測 `package.json` 不存在時跳過（exit 0）
  - 測試要求：用 bash 單元測試（bats 或 shell script）驗證：有 JS 變更時執行 npm test、無 JS 變更時跳過、無 package.json 時跳過

## 3. 驗證 install.sh 已支援 git hooks 安裝

- [x] 3.1 確認 `scripts/skills/install.sh` 已正確安裝 hooks 到 `.git/hooks/` 並 `chmod +x`（讀取現有程式碼確認，若已支援則記錄，不需修改）
  - 測試要求：在暫時目錄建立 git repo，執行 install.sh python，驗證 `.git/hooks/pre-commit` 存在且可執行

## 4. 驗收

- [x] 4.1 執行 `bash scripts/skills/install.sh`（common only）至測試 git repo，確認 `tdd-enforcement.md` 出現在 `.claude/rules/` 和 `.github/instructions/`
- [x] 4.2 執行 `bash scripts/skills/install.sh node` 至測試 git repo，確認 `.git/hooks/pre-commit` 執行 `npm test`（非 placeholder）
- [x] 4.3 執行 `bash scripts/skills/install.sh python` 至測試 git repo，確認 `.git/hooks/pre-commit` 執行 `pytest`
