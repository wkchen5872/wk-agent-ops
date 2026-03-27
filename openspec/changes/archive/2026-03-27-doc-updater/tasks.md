## 1. Agent & Skill 檔案建立

- [x] 1.1 建立 `template/common/.claude/agents/doc-updater.md`（YAML frontmatter + 執行步驟）
- [x] 1.2 建立 `template/common/skills/doc-updater/SKILL.md`（完整 skill 指令含 skip 邏輯與 decision table）
- [x] 1.3 複製 agent 到 `.claude/agents/doc-updater.md`（內容與 template 相同）
- [x] 1.4 複製 skill 到 `.claude/skills/doc-updater/SKILL.md`（內容與 template 相同）

## 2. 說明文件

- [x] 2.1 建立 `docs/doc-updater.md`（架構說明、使用方式、skip 邏輯、常見問答）
- [x] 2.2 更新 `AGENTS.md`，在 Common Agents 區段加入 doc-updater 說明項目

## 3. 驗證

- [x] 3.1 確認 4 個 agent/skill 檔案都存在且內容正確
- [x] 3.2 用 `/doc-updater` 對一個非 trivial commit 執行，確認能正確分析並更新文件
- [x] 3.3 用 `/doc-updater` 對一個 `docs:` commit 執行，確認正確跳過
- [x] 3.4 用 `@"doc-updater (agent)"` 呼叫 agent，確認能正常運作
