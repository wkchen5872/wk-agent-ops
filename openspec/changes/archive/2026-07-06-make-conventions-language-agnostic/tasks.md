## 1. 改寫 conventions.md

- [x] 1.1 改寫 `template/common/docs/conventions.md` 四個 section 為語言中立（Naming 對照表、Prohibited 除錯輸出中立化、Error Handling 加 None、Documentation 分語言）。保留檔頂定位語與通用原則。
  - 測試要求：此為文件變更，無單元測試。改完以下列驗證取代。

## 2. 驗證

- [x] 2.1 矛盾消除檢查：`grep -niE 'camelCase|console\.log|kebab-case' template/common/docs/conventions.md` — 確認僅在「JS/TS 慣例」對照語境出現，無無條件規則。
- [x] 2.2 安裝煙霧測試：複製 `template/common/docs/conventions.md` 至暫存目錄，核對其命名規範與 `template/python/.claude/rules/pytest_testing_style_guide.md` 的 snake_case 不衝突。
- [x] 2.3 `openspec validate make-conventions-language-agnostic` 通過。
