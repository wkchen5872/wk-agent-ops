# Proposal

## Why

實作與 Review 之間的交接目前靠使用者手動傳話：等 Agent 停下、讀結果、通知下一個 Agent。
回溯紀錄顯示，30 個有獨立審查的 Change 有 26 個至少退回一次，Codex Session 的使用者訊息有 13–23% 是這類傳話，
而 Session 停下時 Xirp 只顯示 `idle`，成功與失敗無法分辨，腳本無從判斷下一步。

`retire-worktree-session-helpers` 已把 Session 與 worktree 管理交給使用者選用的工具，並明確把交件單、
指揮官與自動 Review 迴圈留給後續提案；本 Change 就是該提案，對應 Work Item `WI-20261116-agent-commander`
的決策 D-001～D-012。

## What Changes

- 新增**交件單**：每個 Agent 結束一輪工作時，以 `agent-handoff` Skill 附帶的 `handoff-write` 腳本，
  在 worktree 根目錄被 Git 忽略的 `.agent-handoff/<change-id>/` 寫一個固定格式的 YAML，每輪一個檔案。
- 新增 **Stop hook**：Claude Code 與 Codex 的 Agent 停下時自動執行，不用模型、不輪詢；讀最新交件單與
  `loop.yaml`，以 `xirp session message` 通知下一個 Agent，或透過既有 Telegram 通知找使用者；不寫 GitHub。
- 新增**啟動指令** `handoff-start` 與 `handoff-finish`：一個核心依角色範本（implement／review／finish）
  準備 worktree、開 Xirp Session（名稱、模型、effort、prompt）。角色範本每個 repo 一份，放在主 worktree 的
  `.agent-handoff/roles.yaml`，不進 Git。實作者預設另開 worktree；審查與收尾可選 `shared`（共用實作者的 worktree，預設）
  或 `new`（另開 worktree）；`new` 時交件單留在各自 worktree、序號跨 worktree 連續，hook 每輪把審查 worktree 移到新的交付 commit。
- 審查通過後的收尾由設定決定：預設 `finish.trigger: ask`（先通知使用者、經 `handoff-finish` 授權）、
  `finish.delivery: local`。
- `change-review` 在交接迴圈中審查交件單指定的 commit，並寫交件單；迴圈啟用時由 hook 通知實作者，
  不再自行推斷並通知實作者。PR 發布被拒、逾時或回讀不符時寫 `status: blocked`，只通知使用者。
  收尾時的最終版 Review 綁定交付的 commit，不寫交件單。未啟用迴圈時維持既有行為。
- `openspec-commit` 收尾完成或中斷時寫交件單；PR 交付須最終版 Review 通過才發 Closure。
- 新增**清理指令** `handoff-cleanup`：收尾完成（最新交件單為 `finish`／`done`）且各 worktree 乾淨時，先把交件單與審查報告搬到主
  worktree 的 `.agent-handoff/archive/<change-id>/`，再刪除迴圈的 Xirp Session 與主 worktree 以外的 worktree；不刪分支、不合併。
  預設只列出計畫，加 `--yes` 才執行。
- `handoff-finish` 只接受「最新紀錄是 pass、其 head 等於目前 HEAD、工作區乾淨、尚未收尾」的情況。
- 新增 `github-pr-agent` 與 `github-issue-agent`：Claude（Sonnet）與 Codex（`gpt-5.6-terra`，medium）兩個版本，
  由呼叫端在自己的回合內委派 PR／Issue 文案與寫入，Author 沿用呼叫端身分。
- installer：目標 repo 合併 `/.agent-handoff/` 忽略規則並雙向驗證；`roles.yaml` 只在不存在時放入範例。
- 每輪交件前本機 commit，迴圈中不改寫歷史；合併方式屬落地流程，不在本 Change。

## Capabilities

### New Capabilities

- `agent-handoff-records`: 交件單的位置、欄位、編號與 `handoff-write` 寫入規則，以及 `loop.yaml` 迴圈設定的內容。
- `agent-handoff-routing`: Agent 停下時的 Stop hook：讀交件單、依迴圈設定決定通知對象、去重、輪數上限、乾淨交接檢查與安裝。
- `agent-crew-launcher`: `handoff-start`、`handoff-finish`、`handoff-cleanup` 與角色範本：依範本準備 worktree 與 Xirp Session、送出 prompt、寫入迴圈設定。

### Modified Capabilities

- `change-review`: 交接迴圈中的受審版本、寫交件單，以及迴圈啟用時改由 hook 通知實作者。
- `openspec-commit`: 收尾完成或中斷時寫交件單。
- `github-pr`: 可由專用 Agent 代為執行，Author 沿用呼叫端身分。
- `github-issue`: 可由專用 Agent 代為執行，Author 沿用呼叫端身分。
- `codex-subagent-templates`: 新增兩個 Codex custom agent 及其模型設定。
- `install-profile-cli`: 合併並驗證 `/.agent-handoff/` 忽略規則；只在缺少時放入 `roles.yaml` 範例。

## Impact

- 新增：`template/common/skills/agent-handoff/`（含 `handoff-write`）、`scripts/handoff/`（Stop hook、
  `handoff-start`、`handoff-finish`、安裝程式）、`template/common/.claude/agents/github-{pr,issue}-agent.md`、
  `template/common/.codex/agents/github-{pr,issue}-agent.toml`、`tests/` 下對應測試。
- 修改：`template/common/skills/{change-review,openspec-commit,github-pr,github-issue}/`、`scripts/skills/install.sh`、
  README 與 `docs/` 的相關流程說明與圖稿；經 installer 同步安裝副本。
- 支援工具：Stop hook 支援 Claude Code 與 Codex（實測可取得 `CHIRP_SESSION_ID` 並呼叫 `xirp`）；
  Antigravity 與 GitHub Copilot CLI 不在本次範圍。Codex 新 hook 需使用者在 Codex 信任一次。
- 依賴：Xirp 為執行期選用工具，不是安裝依賴；沒有 Xirp 時 hook 安靜略過。Herdr 不在範圍內。
- 驗收條件：交件單格式由腳本保證並通過測試；hook 路由、去重、輪數上限與乾淨交接檢查以假的 `xirp`
  測試；installer 冪等；專用 Agent 在本 repo 以 `gh` 完成建立、回覆、關閉的連動測試並回讀；
  以便宜模型實際跑一個小 Change，至少一次退回與一次通過。
