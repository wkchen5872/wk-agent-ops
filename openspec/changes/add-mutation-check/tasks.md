# Tasks: add-mutation-check

## 1. 查證與測試腳手架

- [x] 1.1 以 ctx7 查證 mutmut（現行版）與 Stryker（現行版）的安裝指令、設定格式、diff-scoped / incremental 執行方式與報告解析，摘要記入 design.md 的 Decisions（更新 D7 為已查證結論）
  - 測試要求：無程式碼；驗收 = design.md 更新且指令附版本號來源
- [x] 1.2 新增 `tests/test_mutation_check.sh`（Red：先寫、確認失敗），比照 `tests/test_agents_dir.sh` 風格，斷言：(a) install.sh 後 `mutation-setup` 與 `mutation-check` 兩個 SKILL.md 在 `.claude/skills/` 與 `.agents/skills/` 皆存在且各自相同；(b) install.sh 後 `.claude/rules/tdd-enforcement.md` 與自動 mirror 的 `.agents/rules/tdd-enforcement.md` 內容一致；(c) 兩個 SKILL.md frontmatter 含 name / description / compatibility / metadata.version；(d) `template/common/docs/agent-protocol.md` 含 `/mutation-check`；(e) install 後目標專案的 `pyproject.toml` / `package.json` / `stryker.config.json` 未被建立或修改
  - 測試要求：測試先行且必須失敗（skill 尚不存在），貼出失敗輸出

## 2. Skill 主體

- [x] 2.1 撰寫 `template/common/skills/mutation-check/SKILL.md`（執行 skill）：frontmatter、語言偵測（D2）、setup gate（D1c）、diff base 計算（D3）、大 diff 警告門檻、scoped 執行指令（用 1.1 查證結果）、findings 表 + 決策選單（D5）、watermark 格式（`.mutation-state`，含 equivalent 標記）。移除原本內嵌的 install 邏輯
  - 測試要求：`tests/test_mutation_check.sh` 的 (a)(c)(e) 轉綠
- [x] 2.2 撰寫 `template/common/skills/mutation-setup/SKILL.md`（設定 skill）：frontmatter、語言偵測（D2）、冪等 install/upgrade（D4）、設定值收集（mutmut source 目錄 / Stryker init）、既有設定 keep/update、gitignore（`.stryker-tmp/`、incremental、`.mutation-state`）、結尾導向 `/mutation-check`
  - 測試要求：`tests/test_mutation_check.sh` 的 (a)(c) 對 mutation-setup 也轉綠

## 3. 規則與文件

- [x] 3.1 擴充 `template/common/.claude/rules/tdd-enforcement.md`（單一來源）：Red 需原始失敗輸出、revert-check、存活 mutant triage 規則（advisory、不設 gate）。不建立 `.github/` 檔——install.sh 自動 mirror 到 `.agents/rules/`
  - 測試要求：`tests/test_mutation_check.sh` 的 (b) 轉綠
- [x] 3.2 在 `template/common/docs/agent-protocol.md` §4（Implementation Loop）verify 步驟加一行 `/mutation-check` advisory 參照
  - 測試要求：`tests/test_mutation_check.sh` 的 (d) 轉綠

## 4. 安裝、驗證與收尾

- [x] 4.1 執行 `bash scripts/skills/install.sh` 安裝到本 repo，`git diff` 確認 template 與安裝目標（`.claude/`、`.agents/`、`.github/`、`docs/`）一致
  - 測試要求：`bash tests/test_mutation_check.sh` 與既有 `tests/*.sh` 全部 PASS
- [ ] 4.2 Dogfood：在一個真實 Python 或 TS 專案安裝後執行 `/mutation-check` 完整跑一輪（bootstrap → diff run → findings → 決策選單 → watermark），把發現的問題修回 template
  - 測試要求：手動驗收；記錄一份實際輸出摘要於 change 目錄（如 `dogfood-notes.md`）
- [ ] 4.3 更新 `AGENTS.md` Skills 章節與 `docs/`（可用 doc-updater）。docs 中 mutation-check 段落的「參考資料」需列入兩個靈感來源連結：test-architect agent（https://github.com/rohitg00/awesome-claude-code-toolkit/blob/main/agents/quality-assurance/test-architect.md）與 add-mutation-testing command（https://github.com/davepoon/buildwithclaude/blob/main/plugins/all-commands/commands/add-mutation-testing.md），並註明我們吸收/未採用的部分（見 design D8）。歸檔 change 並依 openspec-commits 規範提交
  - 測試要求：pre-commit gate 通過；`openspec` 驗證通過
