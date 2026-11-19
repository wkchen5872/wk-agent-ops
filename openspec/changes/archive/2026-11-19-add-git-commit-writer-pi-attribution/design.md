# Design

## Context

動機見 proposal.md；行為以 specs 為準。

- 規則只寫在指令文件中：`git-commit-writer/SKILL.md`（可攜 skill）與 `openspec-commit/SKILL.md`（協調層）。兩者都有一句
  「不得從環境變數推定模型」。Claude、Codex 的 `git-commit-writer-agent` 也有同樣的禁止，但它們只從呼叫端接收
  `assisting_model`，且不會在 Pi 中執行。
- Pi 中沒有 provider-native 的 commit agent；`openspec-commit` 對 Claude Code、Codex 以外的工具改用可攜 skill，Pi 走這條路。
- Pi 文件（`docs/environment-variables.md`）：shell 工具在每個指令開始時注入 `PI_PROVIDER`、`PI_MODEL`、`PI_REASONING_LEVEL`、
  `PI_SESSION_ID`，`/model` 換模型後下一個指令即反映；`PI_CODING_AGENT=true` 會被子程序繼承。pstack 的 Pi subagent
  另帶 `PI_SUBAGENT_PARENT_SESSION`，其 `PI_MODEL` 是 subagent 自己的模型。
- 驗證方式：`tests/test_openspec_commit.sh` 以文字錨點檢查指令文件；`tests/acceptance/git-commit-writer.md` 是離線的決策案例。

## Goals / Non-Goals

**Goals:**

- Pi root session 的 commit 自動帶上可確認的模型，不問使用者。
- 例外範圍窄到只有 Pi root session，其他工具的禁止保持原樣。

**Non-Goals:**

- 不改 `git-commit-writer-agent`（Claude `.md`、Codex `.toml`）。
- 不處理 `github-pr`、`github-issue` 的 Author 區塊。
- 不新增 Pi 專用的 commit agent。

## Decisions

### 1. 例外以「Pi root session」為界

- 判斷：`PI_CODING_AGENT=true` 且沒有 `PI_SUBAGENT_PARENT_SESSION`。
- `PI_CODING_AGENT` 會被 Pi 開出的任何子程序繼承（例如在 Pi 的 shell 中啟動其他 CLI），所以文件同時寫明：這個例外只在
  writer 本身由 Pi session 執行時適用；Claude Code、Codex、Antigravity 中出現 `PI_MODEL` 也不使用。
- 替代方案：只看 `PI_MODEL` 是否有值。不採用——任何從 Pi 啟動的程序都會繼承它，會在別的工具中被誤用。

### 2. 只記模型 ID，不加 provider

- `AI-Assisted-By` 記錄的是協作模型，不是計費來源；其他工具記的也是模型名稱。`openai` 與 `openai-codex` 下的同一個 ID
  是同一個模型，加上 provider 只會讓同一模型出現兩種寫法。
- 原樣記錄 `PI_MODEL`（例如 `claude-opus-5-5`），不轉成顯示名稱，避免維護對照表。

### 3. subagent 不自報

- 在 Pi subagent 中，`PI_MODEL` 是 subagent 的模型，不是 root session 的；沿用既有原則「commit-only agent 的身分不得取代
  root-session attribution」，只用呼叫端傳入的值，沒有就省略並回報。

### 4. 工具名稱 `Pi`，不附 email

- 現行規則已讓未對應的工具只寫名稱；明確列出 `Pi` 是為了固定寫法（不寫成 `pi`、`Pi Coding Agent`）。Pi 沒有經查證的
  noreply 位址，不新增 email。

### 5. TDD 策略與測試邊界

- 先在 `tests/test_openspec_commit.sh` 加失敗的文字錨點：兩份 SKILL.md 都含 Pi root session 的判斷條件、`PI_MODEL`、
  subagent 不適用、`Co-Authored-By: Pi`；兩份 agent 定義不含 `PI_MODEL`（確認例外沒有擴散）；既有錨點（含禁止環境變數推定）維持通過。
- 在 `tests/acceptance/git-commit-writer.md` 新增 Pi 案例（root session、換模型、使用者提供名稱、subagent 無傳入、Claude Code
  中有 `PI_MODEL`），`tests/test_acceptance_bank.sh` 檢查結構。
- 指令文件沒有可執行程式碼；實際行為以真實演練確認：在 Pi root session 跑一次 standalone commit 與一次 `openspec-commit`，
  讀 `git log -1 --format=%(trailers)` 確認 trailer。演練用暫存 repo，不在本 repo 留下 commit。

## Risks / Trade-offs

- [Agent 把例外套用到 Pi 以外的情境] → 規則寫明判斷條件與「其他工具不用」，並以驗收案例涵蓋 Claude Code 中有 `PI_MODEL` 的情況。
- [Pi 日後改變變數名稱] → 讀不到時視為未知模型，省略並回報，不會寫錯；屆時更新規則即可。
- [subagent 判斷依賴 pstack 的 `PI_SUBAGENT_PARENT_SESSION`] → 其他 subagent extension 若不設這個變數，會被當成 root session；
  影響僅限 attribution 文字，且目前沒有使用其他 subagent extension。

## Migration Plan

1. 修改 `template/common/skills/` 的兩份 SKILL.md，執行 `bash scripts/skills/install.sh` 同步到 `.claude/skills/` 與 `.agents/skills/`。
2. 下游專案重跑 installer 後生效；不影響既有 commit。
3. 回退：還原兩份 SKILL.md 並重跑 installer；Pi 中回到省略 `AI-Assisted-By` 的行為。
