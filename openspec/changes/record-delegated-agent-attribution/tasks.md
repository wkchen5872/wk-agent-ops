# Tasks

## 1. Commit 委派紀錄（git-commit-writer）

- [x] 1.1 先在 `tests/test_openspec_commit.sh` 加斷言，跑一次確認 Red（新斷言失敗，exit 非 0）。斷言內容：
  - Claude 與 Codex 的 `git-commit-writer-agent` 都要求在 `AI-Assisted-By` 後加 `Committed-By: <agent name> (<model>)`；
  - model 取自自己的 runtime 或定義檔，不得取自 `assisting_model`；
  - 不知道自己的 model 時只寫 agent 名稱並回報；
  - portable skill 只在 Pi subagent 加 `Committed-By`，root 自己執行時不加。
  測試要求：記錄 Red 的指令、失敗的斷言名稱與 exit code。
- [x] 1.2 修改 `template/common/.claude/agents/git-commit-writer-agent.md` 和 `template/common/.codex/agents/git-commit-writer-agent.toml`：
  - 加入 `Committed-By` 規則與 trailer 範例；
  - 「model 不得取自 commit-only agent」等句子，明確限定在 root 的 model。
  測試要求：1.1 的 Claude、Codex agent 斷言轉為 Green。
- [x] 1.3 修改 `template/common/skills/git-commit-writer/SKILL.md`：加入 Pi subagent 的 `Committed-By: git-commit-writer (<PI_MODEL>)` 規則，並寫明 root 自己執行時不加這一行。
  測試要求：1.1 的 skill 斷言轉為 Green；`tests/test_openspec_commit.sh` 全部通過。
- [x] 1.4 先加斷言（Red），再讓三份 commit writer（skill、Claude agent、Codex agent）接受選填輸入 `subject`：照原樣使用；空字串或超過 72 字元時回報，改用自動產生的標題。
  測試要求：新斷言先 Red 後 Green。

## 2. Issue／PR 委派紀錄

- [x] 2.1 先在 `tests/test_agents_dir.sh` 加斷言（Red）：
  - 四個 issue／pr agent 檔（Claude、Codex）要求 Author 最後加 `Posted-By: <agent name> (<model>)`；
  - model 不得取自 caller；
  - 不知道自己的 model 時只寫名稱並回報。
  測試要求：記錄 Red 證據。
- [x] 2.2 修改 `template/common/.claude/agents/github-{issue,pr}-agent.md` 和 `template/common/.codex/agents/github-{issue,pr}-agent.toml`，保留原本「照抄 caller 身分」的規則。
  測試要求：2.1 轉為 Green。
- [x] 2.3 在 `github-issue`、`github-pr` 兩份 Author 共同外框加入選填的 `Posted-By` 行與說明（只有委派貼文才有），兩份保持逐位元相同；同步更新兩個 skill 的委派段落。
  測試要求：`tests/test_github_handoff.sh` 的外框比對與新斷言通過。
- [x] 2.4 先加斷言（Red），再修改 `template/common/skills/change-review/SKILL.md` 找實作者的步驟：只讀原本四個欄位，明確略過 `Posted-By`，不把它當成實作者或交接對象。
  測試要求：新斷言先 Red 後 Green。
- [x] 2.5 確認 `openspec-commit`、`change-review` 的委派段落不再要求 PR agent「只能寫 caller 身分」，而是寫明 PR agent 會加上自己的 `Posted-By`。
  測試要求：`tests/test_openspec_commit.sh` 通過；`grep -n "Posted-By"` 可在兩份 skill 找到說明。

## 3. 交接迴圈實作者改用 skill 提交

- [x] 3.1 先加斷言（Red），檢查 `template/common/skills/agent-handoff/roles.example.yaml`：
  - `implement` 的 prompt 呼叫 `/git-commit-writer` 並傳入 `subject`（第一輪 `feat({change}): <摘要>`，修正輪 `fix({change}): address <review-id>`）；
  - 註解中的 Pi 範例（如果有 implement 範例）使用 `/skill:git-commit-writer`；
  - prompt 不再直接要求「本機 commit」。
  測試要求：記錄 Red 證據；斷言放在現有的 handoff 或 agents 測試中，位置依現有慣例。
- [x] 3.2 修改 `roles.example.yaml` 的實作者 prompt。
  測試要求：3.1 轉為 Green；`bash tests/test_agent_handoff.sh` 的相關區段仍通過。
- [x] 3.3 在 `scripts/handoff/README.md` 說明：已有 `.agent-handoff/roles.yaml` 的 repo，要怎麼把實作者 prompt 換成新範本；installer 不會覆寫這個檔案。
  驗證：README 有這段說明，`grep -n "git-commit-writer" scripts/handoff/README.md` 有結果。

## 4. 文件、驗收題庫與整體檢查

- [x] 4.1 更新 `AGENTS.md` 的 git-commit-writer-agent 段落，以及「Skill 與 Agent 邏輯一致性」一節：
  - 說明 `Committed-By`／`Posted-By`；
  - 原本「commit-only subagent 必須沿用 caller 的 root-session 模型」保留，並補上「另外加一行記錄自己」。
  驗證：人工比對 AGENTS.md 和 agent 定義一致。
- [x] 4.2 在 `tests/acceptance/git-commit-writer.md`、`github-issue.md`、`openspec-commit.md` 新增題目，涵蓋：
  - 委派 commit 有 `Committed-By`；
  - root 自己 commit 沒有這一行；
  - Pi subagent；
  - 委派貼文有 `Posted-By`；
  - review 不把 `Posted-By` 當成實作者。
  測試要求：`tests/test_acceptance_bank.sh` 通過。
- [x] 4.3 執行 `bash scripts/skills/install.sh`，確認安裝後的 `.claude/agents/`、`.codex/agents/`、`.claude/skills/`、`.agents/skills/` 與 template 一致。
  測試要求：`tests/test_agents_dir.sh` 的安裝比對通過。
- [x] 4.4 執行整套檢查：`tests/test_agents_dir.sh`、`tests/test_openspec_commit.sh`、`tests/test_github_handoff.sh`、`tests/test_acceptance_bank.sh`、`bash tests/test_agent_handoff.sh`；通過後執行 OpenSpec verify。
  測試要求：全部 exit 0，並記錄結果。

## Workflow follow-up

- 本 repo 的 `.agent-handoff/roles.yaml` 要手動換成新的實作者 prompt（不在版本控制內）。
- 重播 4.2 的驗收題，結果記在 Work Item 或 PR。
