---
type: Architecture
title: OpenSpec、Git 與 Session 邊界
description: PM/RD 工作流的 lifecycle 分離、change-id 協調與 Worktree state invariants。
tags: [workflow, openspec, git, worktree, sessions]
timestamp: 2026-08-01T00:00:00+08:00
---

# OpenSpec、Git 與 Session 邊界

OpenSpec、Git 與 AI Provider 解決的是三個不同問題。把它們綁成單一路徑，會讓
「建立 change」意外切 branch，或讓「啟動 Session」不必要地建立 Worktree。

## 三個獨立 Lifecycle

```text
OpenSpec lifecycle
explore → new + continue 或 ff → review → apply → verify → archive

Git lifecycle
branch → optional worktree → commit → merge → cleanup

Provider session lifecycle
start → plan/explore → resume → stop
```

`change-id` 是 workflow 的共同關聯鍵；若 Provider 使用 detached HEAD 或不透明
路徑，Git hand-off 還必須攜帶精確 Worktree path。

| Lifecycle | Owner | 不負責的事 |
|---|---|---|
| OpenSpec | OpenSpec action / portable skill | 不決定 checkout 隔離方式 |
| Git | project workflow scripts 或明確的 cleanup owner | 不決定需求是否已釐清 |
| Session | Claude、Codex、Antigravity、Copilot adapter | 不偷偷建立 change 或 Git branch |

## 兩種 PM 入口，一個 change-id 轉換

需求清楚時，可以用 `pm-start` 直接進入 Plan Mode；需求不清楚時，可以從一般
Session 先讀取專案、討論，再選擇 Plan Mode 或 `$openspec-explore`。兩條路最後
都停在同一個 Scope Ready 關卡。

```text
direct-plan ───────────────┐
                          ├─ Scope Ready ─ derive change-id ─ branch guard ─ new/ff
discovery-first ──────────┘
```

`pm-start` 與 `$openspec-explore` 都是可選入口。Scope Ready 不要求使用者事先
命名；它只要求需求已明確到足以讓 OpenSpec skill 接受既有名稱或推導唯一的
kebab-case change ID。這個最終 ID 再成為 OpenSpec change、Git branch 與後續
Worktree 的共同關聯鍵。

## Change ID 與 Branch 的協調

### Agent-mediated Branch Guard

OpenSpec skill 在執行 `openspec new change` 前已接受或推導出最終 change ID。共用
operating protocol 要求 Agent 在這個時間點自動執行 `opsx-branch`，而不是要求
人類預先知道並輸入名稱。這是所有 AGENTS.md-aware Provider 的 branch-first
正確性來源，不依賴 Provider 是否支援 hook。

```text
new / ff
接受或推導 change-id
    → Agent 執行 opsx-branch <change-id>
    → 成功才執行 openspec new change <change-id>

continue
解析既有 change-id
    → Agent 執行 opsx-branch <change-id>
    → 成功才讀取 status 並建立下一份 artifact
```

`opsx-branch` 的 exit status 是 branch guard contract。exit `0` 表示已位於
`feature/<change-id>`；non-zero 表示不得繼續目前的 OpenSpec action。若 branch
已由另一個 registered Worktree 持有，它會回報該 path；Agent 必須停止，不能自動
接手或建立第二個 writer。

### PostToolUse Safety Net

PostToolUse hook 保留給人工直接執行 `openspec new change`、舊版 entrypoint，或
Agent 未先執行 branch guard 的情境：

```text
openspec new change <change-id>
    → PostToolUse 擷取 change-id
    → 呼叫同一個 opsx-branch 核心
    → 後續 status / instructions / artifacts
```

hook 在 scaffold 建立後、下一個 tool call 前切換 branch；未 commit 的 scaffold
會隨 checkout 留在 feature branch，不會進入 main 的 Git 歷史。hook 只負責
event payload normalization，Git mutation 全部交給 `opsx-branch`。

### 現行支援邊界

目前 `scripts/workflow/openspec-branch-creator/hook.sh` 只辨認 shell command 中的
`openspec new change <change-id>`：

| OpenSpec action | 現行 hook 行為 |
|---|---|
| `$openspec-new-change`／`/opsx:new` | 會觸發；action 建立 scaffold、顯示第一個 artifact instructions，尚不建立 artifact |
| `$openspec-ff-change`／`/opsx:ff` | 會觸發；同一 action 隨後繼續產生 apply-required artifacts |
| `$openspec-continue-change`／`/opsx:continue` | 不觸發；action 不會執行 `openspec new change` |
| 人工執行 `openspec new change` | 會觸發 |

Provider 路徑如下：

| Provider | 現行狀態 |
|---|---|
| Claude Code | installer 註冊 `PostToolUse / Bash`；Agent-mediated guard 仍是正式路徑 |
| Codex | installer 註冊相同 hook；Claude 遷移而來的相同 entry 會去重，使用者仍須在 `/hooks` 確認 trusted／enabled |
| Antigravity | 不註冊廣泛 shell hook，只使用 managed protocol 的 Agent-mediated guard |
| GitHub Copilot CLI | installer 寫入 `postToolUse` 設定，hook 正規化 camelCase payload |

Claude Code 與 Copilot 的 success event 只處理成功 tool call；Codex 的
`PostToolUse` 也可能收到非零 shell 結果，因此 hook 會先檢查 response status。
非匹配、明確失敗或未知 payload 都保持 silent fail-soft。相容性 hook 始終 exit
`0`；只有 action 前的 Agent-mediated guard 會在 branch preparation non-zero 時停止
change/artifact workflow。

`opsx-branch <change-id>` 保留給名稱已知的顯式路徑，以及 hook 缺席、停用、解析或
checkout 失敗時的 recovery。它不是每次都要由人類先輸入的必要步驟。

Branch、OpenSpec change 與 wk-agent-ops Worktree 採相同名稱，降低 hand-off
時的推測：

```text
change-id:  user-login
branch:     feature/user-login
worktree:   .worktrees/user-login   # 只在 project provisions 時存在
```

## Worktree 是並行工具，不是流程階段

Worktree 解決的是同時 checkout 多個 branch 的問題。若只有一個 Session 依序
規劃與實作，feature branch 已足夠，不需要建立 Worktree。

| PM 入口 | Branch-only 實作 | 平行 RD 實作 |
|---|---|---|
| `pm-start` direct-plan | 支援 | 支援 |
| discovery-first | 支援 | 支援 |

因此「如何開始釐清需求」與「是否平行實作」是兩個獨立選項，不需要四套工作流。

### Branch-only

```text
primary checkout
main → feature/change-id → ff → apply → verify → commit → merge
```

適合單一 Session 或不需要同時處理其他 branch 的工作。

### Project-managed Worktree

```text
primary checkout                       .worktrees/change-id
feature/change-id planning commit      feature/change-id
          │                                  │
          └─ wt-work switches primary ───────┘
             away and attaches branch        apply / verify / commit
```

適合 PM 留在主 checkout 繼續規劃，RD Agent 在另一個實體目錄實作。完成後由
`wt-done` 合併並清理。因為 path 與 branch 由 project 控制，這是 `wt-work` 的
預設模式。

### Provider-native Worktree

Provider 可以建立自己的隔離 checkout。其他 Provider 可以在建立者停止後 attach
同一個 path，但不能再次建立 Worktree；第一版不移交 cleanup ownership，原
Provider 仍負責清理。

## Worktree State Invariants

```text
provisioner / cleanup_owner ∈ {none, project, provider}
active_writer               ∈ {none, claude, codex, antigravity, copilot}
```

- Branch-only 的 provisioner 與 cleanup owner 都是 `none`。
- `project` 表示 `wt-work` 建立，預設由 `wt-done` 清理。
- `provider` 表示 Provider-native Worktree，預設由建立它的 Provider 清理。
- `wt-work` attach 外部 Worktree 時只成為 launcher，不會自動成為 cleanup owner。

同一個 Worktree 同一時間只能有一個 active writer。這項限制避免檔案與 Git
index 競爭；cleanup 也只能由已知 owner 執行，避免原 Provider 與 `wt-done`
重複移除同一 Worktree。

## 跨 Provider Failover

切換 Provider 不需要切換 Git checkout：

```text
Provider A @ worktree/path
    ↓ stop A and subagents
Provider B @ same worktree/path
```

這不會產生新的 Worktree 衝突，因為只有 active writer 改變。相反地，若 B 使用
原生 Worktree 功能建立第二個 checkout，named branch 可能被 Git 拒絕；detached
或不同 branch 則會讓工作狀態分岔。

Provider session history 不屬於可攜 hand-off。B 必須從 Git status/diff、OpenSpec
artifacts、測試結果與未完成 tasks 重建 context。

同機 failover 不要求 clean Worktree。接手前必須停止原 active writer 並檢視
status／diff；是否建立 checkpoint commit 由使用者依當下工作狀態決定。

同一路徑接手只適用於同一台機器或共享檔案系統。跨機器時，應先建立可追蹤的
commit 並推送 named branch，再由另一台機器建立新的 Worktree；未 commit 的檔案
狀態不會隨 Provider session 移動。

## PM → RD Hand-off

Hand-off 的必要資料只有：

- 精確的 `change-id`。
- 已 review 並 commit 的 OpenSpec artifacts。
- 包含該 artifacts 的精確 `planning_commit`。
- `feature/<change-id>` 的可解析位置（本地或 remote）。
- 若已建立 Worktree，可提供精確 path；省略時 workflow 只能採用唯一且可驗證的
  Git registry 候選。
- 明確的 cleanup owner，以及目前是否仍有 active writer。

Session ID 是 Provider adapter 的資料，不應成為 Git 或 OpenSpec lifecycle 的
必要欄位。

## 相關文件

- [PM/RD 多 Agent 協作工作流](/docs/workflow/guide.md)
- [wt-work Worktree and Branch Resolution Flow](/docs/workflow/wt-work-flow.md)
- [Provider-native Worktree Reference](/docs/workflow/provider-worktrees.md)
- [OpenSpec Commit Workflow](/docs/workflow/commit.md)

# Citations

[1] [OpenAI Codex Hooks](https://developers.openai.com/codex/hooks)
[2] [GitHub Copilot Hooks Reference](https://docs.github.com/en/copilot/reference/hooks-reference)
