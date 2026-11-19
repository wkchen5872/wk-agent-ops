# Tasks

## 1. git-commit-writer 的 Pi 例外

- [x] 1.1 先在 `tests/test_openspec_commit.sh` 加失敗的文字錨點：`template/common/skills/git-commit-writer/SKILL.md` 含 Pi root session 的判斷（`PI_CODING_AGENT=true` 且沒有 `PI_SUBAGENT_PARENT_SESSION`）、讀 `PI_MODEL` 並原樣記錄模型 ID、空值視為未知、subagent 不得使用自己的 `PI_MODEL`、`Co-Authored-By: Pi`；Claude 與 Codex 的 `git-commit-writer-agent` 不含 `PI_MODEL`。測試要求：執行 `bash tests/test_openspec_commit.sh`，新錨點失敗、既有錨點通過（Red 證據記入 Work Item）。
- [x] 1.2 修改 `template/common/skills/git-commit-writer/SKILL.md`：`tool_name` 範例加入 `Pi`；在 attribution 規則中加入 Pi root session 例外與 subagent 限制，保留「其他情況不得從環境變數推定」的原句；Step 6 的對照表註明 `Pi` → `Co-Authored-By: Pi`（無 email）。測試要求：`bash tests/test_openspec_commit.sh` 全數通過，包括既有的 `MUST NOT guess`、`omit \`AI-Assisted-By\` and report the omission` 等錨點。
- [x] 1.3 在 `tests/acceptance/git-commit-writer.md` 新增 Pi 案例：Pi root session standalone commit、`/model` 換模型後 commit、使用者提供名稱優先、Pi subagent 沒有傳入 `assisting_model`、Claude Code 環境中有 `PI_MODEL`。測試要求：`bash tests/test_acceptance_bank.sh` 通過；每案有 Fixture、模擬回覆、預期呼叫、禁止、判定。

## 2. openspec-commit 的 Pi attribution

- [x] 2.1 先在 `tests/test_openspec_commit.sh` 加失敗錨點：`template/common/skills/openspec-commit/SKILL.md` 的 attribution 段落把 `Pi` 列為 root-session 工具、Pi root session 以 `PI_MODEL` 為目前模型、例外不適用於其他工具與 Pi subagent。測試要求：新錨點失敗、既有錨點通過。
- [x] 2.2 修改 `template/common/skills/openspec-commit/SKILL.md` 的 commit 步驟：工具清單加入 `Pi`，加入與 1.2 一致的例外文字，保留其他情況的環境變數禁止。測試要求：`bash tests/test_openspec_commit.sh` 全數通過。
- [x] 2.3 在 `tests/acceptance/openspec-commit.md` 新增 Pi 案例：Pi root session 走可攜 `git-commit-writer` skill，傳入 `tool_name=Pi` 與 `PI_MODEL` 的值。測試要求：`bash tests/test_acceptance_bank.sh` 通過。

## 3. 安裝與文件

- [x] 3.1 執行 `bash scripts/skills/install.sh`，同步兩份 SKILL.md 到 `.claude/skills/` 與 `.agents/skills/`。測試要求：`diff` 範本與兩個安裝位置一致；`.claude/agents/`、`.codex/agents/` 的 `git-commit-writer-agent` 沒有變動（`git diff --stat` 確認）。
- [x] 3.2 更新 `docs/skills/git-commit-writer.md`（Pi 的 trailer 範例與例外說明）、`docs/workflow/commit.md`（attribution 段落加入 Pi）、`AGENTS.md` 的 git-commit-writer 說明。測試要求：依 `docs/okf-conventions.md` 檢查；文件中的 trailer 範例與 SKILL.md 一致（以 `rg 'Co-Authored-By: Pi'` 對照）。

## 4. 整合驗收

- [x] 4.1 執行 `bash tests/test_openspec_commit.sh`、`bash tests/test_acceptance_bank.sh`、`bash tests/test_agents_dir.sh`、`openspec validate add-git-commit-writer-pi-attribution --strict`。測試要求：全數通過，結果記入 Work Item。
- [x] 4.2 真實演練：在暫存 repo 中由 Pi root session 執行一次 standalone `git-commit-writer`，`/model` 換模型後再 commit 一次；讀 `git log --format=%(trailers)` 確認兩次分別為 `Co-Authored-By: Pi` 加上當下的 `PI_MODEL`。測試要求：Work Item 記錄兩次的 trailer 與當時的 `PI_MODEL`；演練 repo 用完即刪。

## Workflow follow-up

- 依專案流程完成審查後封存本 change，並確認 `openspec/specs/git-commit-writer/spec.md` 與 `openspec/specs/openspec-commit/spec.md` 已更新。
