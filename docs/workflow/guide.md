---
type: Playbook
title: PM/RD 多 Agent 協作工作流
description: 從需求探索、OpenSpec 規劃到循序或平行實作的協作流程。
tags: [workflow, openspec, git, worktree, agents]
timestamp: 2026-07-31T00:00:00+08:00
---

# PM/RD 多 Agent 協作工作流

本流程把需求探索、OpenSpec change、Git branch、Worktree 與 AI session 視為
不同責任。Worktree 是平行開發的隔離工具，不是 OpenSpec 或單一 Session
開發的必要條件。

> [!IMPORTANT]
> 本文件目前是架構 review 草案。目標流程與現行腳本的差距列在
> [尚待實作](#尚待實作)，review 通過前不要把該段能力視為已完成。

## 責任邊界

| Lifecycle | 管理內容 | 主要動作 |
|---|---|---|
| OpenSpec | change artifacts 與主規格 | explore → ff → apply → verify → commit/archive |
| Git | branch、worktree、merge 與清理 | branch → optional worktree → merge → cleanup |
| Provider session | 對話、Plan Mode、session resume | start → resume → prompt |

三者可以由同一個工具協調，但不能互相隱式代替。例如，進入 Plan Mode 不代表
已建立 OpenSpec change；執行 `$openspec-ff-change` 也不應自行決定是否建立
Worktree。

## Phase 1：PM 規劃

### 兩種入口

| 入口 | 適用情境 | 流程 |
|---|---|---|
| 直接規劃 | 已清楚知道要做什麼 | `pm-start` → Provider 原生 Plan Mode |
| 探索後規劃 | 問題或範圍尚未釐清 | 一般 Session → 讀取專案、來回討論 → Plan Mode 及／或 `$openspec-explore` |

`pm-start` 是可選的 session launcher，只負責在 repository root 啟動或恢復
PM session，並在 Provider 支援時進入原生 Plan Mode。它不應自動建立 change、
branch 或 worktree。

Plan Mode 與 `$openspec-explore` 也不是二選一：前者是 Provider 的執行／權限
模式，後者是「只探索、不實作」的跨 Provider 思考姿態。

### Scope Ready 關卡

兩種入口都必須先收斂到 **Scope Ready**：

- 問題、預期行為與不做的範圍已足以撰寫規格。
- 已確認唯一的 kebab-case change ID。
- 人類準備開始 review 持久化的 proposal、design、specs 與 tasks。

在 Scope Ready 之前，不需要為探索中的想法建立 branch 或 change。通過關卡後，
才執行同一個 branch-first 轉換：

```text
Scope Ready
    ↓
建立或切換 feature/<change-id>
    ↓
在該 branch 執行 $openspec-ff-change
    ↓
人類 review artifacts
    ↓
commit 規劃文件到 feature/<change-id>
```

Branch 必須在 `$openspec-ff-change` 的第一個持久化動作
`openspec new change <change-id>` 之前就存在。不得依賴 PostToolUse hook 在 change
建立後才切 branch，否則 hook 失敗時 artifacts 仍會留在原本的 checkout。

## Phase 2：RD 實作

規劃通過並 commit 後，再依是否需要平行工作選擇執行模式。

| 模式 | 適用情境 | Provisioner / cleanup owner | 啟動方式 |
|---|---|---|---|
| Branch-only | 同一個 Session 依序規劃與實作 | 無 | 留在 `feature/<change-id>` 執行 apply |
| Project-managed Worktree | `wt-work` 的預設；需要平行 RD 或跨 Provider failover | `wt-work` / `wt-done` | `wt-work <change-id> --agent <provider>` |
| Provider-native Worktree | 已由 Provider 建立隔離 checkout | 建立它的 Provider | `wt-work <change-id> --agent <provider> --path <path>`；省略 `--path` 時安全搜尋 |

> [!WARNING]
> 每個 Worktree 同一時間只能有一個 active writer。Provisioner／cleanup owner
> 可以和目前執行的 Provider 不同，但不得讓第二個 Provider 再建立同一工作的
> Worktree。

RD 在選定的 checkout 中執行：

```text
$openspec-apply-change <change-id>
    ↓
$openspec-verify-change <change-id>
    ↓
$openspec-commit <change-id>
```

Provider 可使用自己的 native alias，但同一個 action 只能選 native alias 或
portable skill 其中一個，不能重複執行。

### 跨 Provider failover

Provider 卡住時，先停止它與仍在執行的 subagents，再讓另一個 Provider 進入
**同一個 Worktree path**。接手者不得使用 `claude -w`、Codex Worktree 或
Antigravity New Worktree 再建立 checkout；它應直接從既有 cwd 啟動並重新讀取
OpenSpec artifacts、Git diff、測試結果與未完成 task。

同機接手允許 Worktree 保持 dirty；是否先建立 checkpoint commit 由使用者依工作
狀態決定。跨機器或 Provider-managed Worktree 可能被清理時，才必須先保存可攜
的 commit／patch。

目標語意是由 `wt-work <change-id> --agent <provider>` 啟動新的 Provider session，
不是 `wt-resume`：後者只用於同一 Provider 的既有 session，session history 不會
跨 Provider 轉移。現行 `wt-work` 遇到既有 `.worktrees/<change-id>` 仍會走 resume
路徑；在 adapter 修正前，應依 reference 直接從既有 path 啟動接手者。若改在另一
台機器接手，則先 commit／push named branch，再建立新的 Worktree。

原生預設位置、path discovery 與接手命令見
[Provider-native Worktree Reference](/docs/workflow/provider-worktrees.md)。

## Phase 3：合併與清理

- `wt-work` 建立的 `.worktrees/<change-id>` 使用 `wt-done <change-id>` 合併並
  清理。
- Branch-only 模式可在沒有其他 checkout 持有該 branch 時使用 `wt-done` 作為
  本地 merge helper，或手動完成 merge 與 branch cleanup。
- Attach 的 Provider-native Worktree 保留原 cleanup owner；第一版不移交給
  `wt-done`，也不從目錄名稱猜測並刪除。

`wt-done` 目前是 local-only：不包含 push、PR、遠端 branch 刪除或 code review
gate。

## 完整狀態圖

```mermaid
flowchart TD
    A[需求清楚] --> B[pm-start / Plan Mode]
    C[範圍不明] --> D[一般 Session：讀取與討論]
    D --> E[Plan Mode 及／或 openspec-explore]
    B --> F{Scope Ready?}
    E --> F
    F -- no --> D
    F -- yes --> G[建立或切換 feature/change-id]
    G --> H[openspec-ff-change]
    H --> I[人類 review + planning commit]
    I --> J{需要平行 RD?}
    J -- no --> K[Branch-only apply]
    J -- yes --> P{已有可用 Worktree?}
    P -- yes --> Q[解析 path 並 attach<br/>保留 cleanup owner]
    P -- no, portable --> L[wt-work 建立<br/>Project-managed Worktree]
    P -- no, native --> M[Provider 建立<br/>Provider-native Worktree]
    Q --> V[驗證包含 planning commit]
    L --> V
    M --> V
    V --> R[在 resolved path 啟動 Provider]
    R --> S{Provider 卡住?}
    S -- yes --> T[停止 active writer<br/>換 Provider 使用同一 path]
    T --> R
    S -- no --> N[verify + openspec-commit]
    K --> N
    N --> O[merge + cleanup owner 清理]
```

底層概念見 [OpenSpec、Git 與 Session 邊界](/docs/workflow/concepts.md)，
`wt-work` 的現行 branch resolution 見
[wt-work Worktree and Branch Resolution Flow](/docs/workflow/wt-work-flow.md)。

## 目標 Provider 矩陣

| Provider | PM / RD 目標 | OpenSpec 入口原則 |
|---|---|---|
| Claude Code | 支援 | native OPSX alias 或 portable skill，擇一 |
| Codex | 支援 | portable skill |
| Antigravity | 支援 | native workflow 或 portable skill，擇一 |
| GitHub Copilot CLI | 支援 | portable skill |
| Gemini CLI | 移除 | 已不列入目標矩陣 |

Worktree core 應保持 Provider-neutral；Provider adapter 只負責在指定 cwd 中啟動、
恢復 session 與傳入 prompt。

各 Provider surface 是否原生建立 Worktree、預設位置與 checkout 行為，集中記錄於
[Provider-native Worktree Reference](/docs/workflow/provider-worktrees.md)。

## 尚待實作

目前文件共識尚未全部反映在腳本中：

- `openspec-branch-creator` 仍是 change 建立後才執行的 PostToolUse hook，尚未改為
  Scope Ready 後的明確 branch-first 入口。
- `pm-start` 目前只有 Claude Code adapter；其實作雖只啟動 Plan Mode，主規格仍
  留有自動 `/opsx:new` 的舊描述。
- `wt-work` / `wt-resume` 仍列出 Gemini、尚無 Antigravity adapter，Codex 的
  prompt 與 resume 行為也尚未完整對齊 portable skill。
- `wt-work` 目前只辨識 `.worktrees/<change-id>`，尚不會從 Git registry attach
  任意 Provider Worktree，也沒有 detached HEAD 的精確 path 輸入；既有目錄仍
  固定走原 Provider 的 resume 語意，尚無 cross-provider new-session mode。
- 腳本尚未區分 cleanup owner 與 active writer；在完成前，使用者必須自行避免
  同時讓兩個 Provider 寫入，或讓錯誤 owner 清理 Worktree。
- Project-managed Worktree 目前只複製 `.env` 與 Claude local settings；尚未依
  `--agent` 複製所選 LLM Provider 的相關 local settings。

## 已確認的實作決策

本次重構採用以下邊界：

1. `wt-work` 預設建立 Project-managed Worktree；Provider-native 是 attach-only
   的外部入口。
2. `--path` 明確指定時優先使用；省略時只從 Git Worktree registry 自動選擇唯一
   可驗證候選。零個候選才建立 Project-managed Worktree，多個候選則停止並列出
   path，不保存額外 mapping registry。
3. 同機 failover 允許 verified dirty Worktree；停止原 active writer 後即可接手，
   checkpoint commit 是情境式選項，不是 gate。
4. Cleanup ownership 不因 attach 或 Provider 切換而移交；`wt-done` 只清理
   Project-managed Worktree。
5. Project-managed Worktree 保留 `.env`，並只複製所選 LLM Provider 已知且存在的
   local settings；不自動建立 Codex `.worktreeinclude`，也不隱式安裝 dependencies。

## 相關文件

- [OpenSpec、Git 與 Session 邊界](/docs/workflow/concepts.md)
- [wt-work Worktree and Branch Resolution Flow](/docs/workflow/wt-work-flow.md)
- [Provider-native Worktree Reference](/docs/workflow/provider-worktrees.md)
- [OpenSpec Commit Workflow](/docs/workflow/commit.md)
- [Workflow 腳本手冊](/scripts/workflow/README.md)
