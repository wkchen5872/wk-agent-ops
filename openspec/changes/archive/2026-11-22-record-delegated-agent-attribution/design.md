# Design

## Context

動機見 proposal.md。目前的署名資料流：

```
 root session --(tool, assisting_model, session IDs)--> 寫紀錄的 subagent --> commit trailer / Author 區塊
                                                          （規則：只能照抄 caller，不能寫自己）
```

- 寫紀錄的 subagent 有三個：`git-commit-writer-agent`、`github-issue-agent`、`github-pr-agent`，各有 Claude 的 `.md` 和 Codex 的 `.toml`。
  模型設定：Claude 版只寫別名（`haiku`、`sonnet`）；Codex 版寫完整名稱（`gpt-5.6-luna`、`gpt-5.6-terra`）。
- portable skill（`git-commit-writer`、`github-issue`、`github-pr`）由 root 直接執行時，不會經過 subagent。
  Pi 例外：可攜 skill 可能在 Pi subagent 裡執行，可用 `PI_SUBAGENT_PARENT_SESSION` 辨識。
- `github-issue` 和 `github-pr` 各有一份 Author 共同外框，測試要求兩份逐位元相同。
- `change-review` 從 Author 找實作者，再把修正工作交回實作者 session（`SKILL.md` 約 342–368 行）。
- 交接迴圈的實作者 prompt 寫在 `roles.example.yaml`。installer 只在 `.agent-handoff/roles.yaml` 不存在時才複製這份範本。
- 這些規則都是寫給 agent 讀的文字。測試（`tests/test_openspec_commit.sh`、`tests/test_agents_dir.sh`）用 `require_text` 檢查關鍵句子；
  實際行為則靠 `tests/acceptance/` 的題庫重播驗證。

## Goals / Non-Goals

**Goals:**
- 新增的一行不影響原有內容：root 的 `Co-Authored-By`、`AI-Assisted-By`、Session 欄位都不變，只在最後多加一行。
- 規則只寫在 subagent 定義檔和 skill 的委派段落；root 自己執行的路徑不需要知道這件事。

**Non-Goals:**
- 不偵測 subagent 有沒有自己的 session ID，`Committed-By` 和 `Posted-By` 不放 session。
- 不改 `handoff-author` 腳本：它印的是 root 的 Author；`Posted-By` 由發文的 agent 自己加在最後。

## Decisions

1. **用另外一行記錄 subagent，不取代 `AI-Assisted-By`。**
   `AI-Assisted-By` 回答「內容是誰做的」；subagent 只寫訊息或貼文。取代的話，就查不到程式碼是誰寫的。
   另一個做法是把多個 model 都寫進 `AI-Assisted-By`，但這樣分不出角色，所以不採用。
2. **名稱用 `Committed-By`／`Posted-By`，格式為 `<agent 名稱> (<model>)`。**
   不在括號裡寫 harness：subagent 一定和 root 同一個 harness，root 那行的 `Co-Authored-By` 已經寫了。
   不用 git 內建的 committer 欄位：那是 Git 身分（人類帳號），agent 無權修改。
3. **subagent 自己的 model 從哪裡來。** 依序使用：
   - 執行時 context 裡的完整 model ID（Claude subagent 的系統提示有寫）；
   - provider-native 定義檔的 `model`（Codex）；
   - Pi subagent 的 `PI_MODEL`。
   Claude 不使用定義檔的別名（`haiku`）。拿不到時只寫 agent 名稱並回報，不擋 commit 或貼文。
   規格中「不得從 commit-only agent 推斷」的限制，明確限定在 root 的 model（`AI-Assisted-By`）。
4. **怎麼判斷「這次是委派」。** 看執行者本身，而不是 caller 傳來的參數：
   - provider-native agent 定義檔一律視為委派，所以永遠加這一行；
   - 可攜 skill 只在 Pi subagent 裡加；
   - 其他情況（root 自己執行）不加。
   這樣 caller 不需要多傳旗標，也不會因為漏傳而記錯。
5. **Author 共同外框裡加一行選填的 `Posted-By`。** 兩份外框同步修改，保持逐位元相同，說明「只有委派貼文才有這一行」。
   讀取規則：`change-review` 找實作者時只看原本的四個欄位，明確略過 `Posted-By`。
6. **實作者用 skill 提交，標題由 caller 傳入。** `git-commit-writer` 新增選填輸入 `subject`。
   實作者 prompt 傳入 `feat(<change>): <摘要>` 或 `fix(<change>): address <review-id>`，
   commit 標題就能保留審查編號，不會被 skill 自動產生的標題蓋掉。
   不採用「prompt 列出 trailer 格式、讓實作者自己 `git commit`」：這樣格式規則會有第二份來源，日後還是會不一致。
   - Claude 範本：`/git-commit-writer`；
   - Pi 範例：`/skill:git-commit-writer`；
   - Codex 範本（如果之後有）：`$git-commit-writer`。
   這和現有 prompt 呼叫 skill 的寫法一致。

## TDD 策略與測試邊界

- **Red**：先在 `tests/test_openspec_commit.sh`、`tests/test_agents_dir.sh` 加入 `require_text` 斷言，確認失敗後才改文字。斷言涵蓋：
  - 三個 agent（兩種 provider）的 `Committed-By`／`Posted-By` 格式與「model 不得取自 caller」；
  - `git-commit-writer` 的 `subject` 輸入與 72 字元上限；
  - 兩份 Author 外框都有選填的 `Posted-By`（沿用逐位元比對）；
  - `change-review` 略過 `Posted-By`；
  - `roles.example.yaml` 的實作者 prompt 呼叫 `git-commit-writer` 並傳入 `subject`，且不再出現「本機 commit」的直接指示。
- **既有斷言**：「不得取代 root 署名」等句子保留，因為行為沒有變。只有需要調整措辭的句子，才同步修改斷言。
- **行為驗收**：在 `tests/acceptance/git-commit-writer.md`、`github-issue.md`、`openspec-commit.md` 新增題目，涵蓋：
  - 委派 commit 有 `Committed-By`；
  - root 自己 commit 沒有這一行；
  - Pi subagent；
  - 委派貼文有 `Posted-By`。
  這些題目由人重播，結果記在 Work Item 或 PR。
- **測試邊界**：不測真實 subagent 回報的 model 名稱，因為那取決於 provider runtime；只驗證規則文字與範本。
- **整套檢查**：`bash scripts/skills/install.sh` 後，跑 `tests/test_agents_dir.sh`、`tests/test_openspec_commit.sh`、`tests/test_github_handoff.sh`、`tests/test_acceptance_bank.sh`。

## Risks / Trade-offs

- [Claude subagent 拿不到完整 model ID，只知道別名] → 規則允許省略括號並回報；驗收題重播時確認實際輸出。
- [舊的讀取端不認得 `Posted-By`] → 這一行放在 Author 最後，舊格式的欄位都沒有變，舊讀取端照樣能解析原本的四行。
- [已安裝的 `roles.yaml` 沒有更新，實作者仍直接 `git commit`] → 在 `scripts/handoff/README.md` 寫明更新方式；不讓 installer 覆寫使用者的範本。
- [`subject` 由 caller 決定，可能和 diff 不符] → 只在交接迴圈使用；skill 仍會檢查長度，內文照常依 diff 產生。

## Migration Plan

1. 修改 template 後重跑 `bash scripts/skills/install.sh`，更新本 repo 安裝的 agent 和 skill。
2. 本 repo 的 `.agent-handoff/roles.yaml` 要手動換成新的實作者 prompt；其他 repo 依 README 說明更新。
3. 舊 commit 和舊貼文不改寫。要回復時，revert 這個 change 的 commit 即可，不涉及資料遷移。
