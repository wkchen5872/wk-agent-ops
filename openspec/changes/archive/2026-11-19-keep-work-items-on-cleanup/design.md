# Design

## Context

見 proposal.md「Why」。`scripts/handoff/handoff-cleanup` 的流程：找出所有 loop worktree 與 session → 檢查每個 worktree
乾淨 → 預覽（無 `--yes` 時到此為止）→ ① 歸檔每個 loop 目錄與 `*-review.yaml` 的 `report` 檔案 → ② 刪 session →
③ `git worktree remove` 各 loop worktree（main worktree 只刪 `.agent-handoff/<change-id>/`）。`work-items/WI-*/` 由專案
`.gitignore` 忽略，所以不影響乾淨檢查，也會被 `git worktree remove` 一併刪除。

## Goals / Non-Goals

**Goals:**

- 被移除的 worktree 裡的 Work Item 不再遺失。

**Non-Goals:**

- 不解析審查報告內文去找引用檔案。
- 不歸檔 Work Item 以外的忽略檔案（例如 `.pi/settings.json`、建置產物）。
- 不改變 main worktree 的 Work Item；不搬移、不刪除。

## Decisions

### 1. 歸檔整個 `work-items/WI-*` 目錄

- 在步驟 ① 內、刪除任何東西之前，對 main worktree 以外的每個 loop worktree，把 `work-items/WI-*` 目錄以 `cp -R` 複製到
  `<archive>/<worktree 名稱>/work-items/`；任一複製失敗就以既有的 `die "...; nothing was removed"` 結束。
- 審查報告若本來就在 Work Item 內，會被複製兩次到同一位置，結果相同，不另外去重。
- 替代方案：只歸檔審查報告內文引用的路徑。不採用——要解析自由文字，容易漏掉（本次遺失的證據就只出現在報告內文）；
  loop worktree 移除時其中的 Work Item 本來就會全部消失，整目錄歸檔才不會漏。

### 2. 預覽列出將歸檔的 Work Item

- 預覽在「records archived to」之後，逐一列出各 loop worktree 中將歸檔的 `work-items/WI-*` 目錄；沒有時不印這一段。
  讓使用者在 `--yes` 前知道 Work Item 會被保存在哪裡。

### 3. TDD 策略與測試邊界

- 在 `tests/test_agent_handoff.sh` 的 cleanup 段落、沿用既有 new-mode fixture（實作者 A、審查 B、收尾 F）：
  於 A 建立 `work-items/WI-20261119-x/agents/drill.md`（以 info/exclude 忽略，比照 fixture 對 `rv/` 的做法），先寫失敗測試——
  預覽輸出含該目錄、`--yes` 後 archive 下有 `.../$(basename A)/work-items/WI-20261119-x/agents/drill.md`；
  `--worktree here` 的 fixture 加一個 Work Item，cleanup 後仍在 main worktree。
- 既有斷言（session 刪除、worktree 移除、分支保留、archive 不進 Git、未完成拒絕、髒 worktree 拒絕）維持通過。
- 邊界：只用假 `xirp`，不碰真實 session；不測複製失敗路徑（沿用既有 `die` 分支，與報告複製失敗相同）。

## Risks / Trade-offs

- [Work Item 很大] → 只複製 `work-items/WI-*`，不複製其他忽略檔案；Work Item 依規範是小型文字紀錄。
- [archive 內同名衝突] → 路徑含 worktree 名稱，不同 worktree 互不覆蓋；同一 change 重跑 cleanup 前 loop 已不存在。

## Migration Plan

1. 合併後執行 `bash scripts/handoff/install.sh` 更新 `~/.local/bin/handoff-cleanup`。
2. 回退：重裝前一版；已歸檔的 Work Item 留在 archive，不影響任何流程。
