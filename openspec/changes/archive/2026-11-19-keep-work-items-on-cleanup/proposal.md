# Proposal

## Why

`handoff-cleanup` 只歸檔交件單與交件單 `report` 欄位指到的審查報告，然後移除 loop worktree。worktree 裡其他的
`work-items/WI-*` 檔案隨之刪除，包括審查報告引用的驗收證據。`add-pi-notify-hook` 收尾後，pass 所依據的 task 5.2
真實演練紀錄就這樣消失，已封存的 `tasks.md` 與第 6 輪審查報告都指向不存在的檔案。

## What Changes

- 移除 main worktree 以外的 loop worktree 之前，`handoff-cleanup --yes` 把其中每個 `work-items/WI-*` 目錄完整複製到
  `<main worktree>/.agent-handoff/archive/<change-id>/<worktree 名稱>/work-items/`；複製失敗時不刪任何東西。
- 不加 `--yes` 的預覽列出將被歸檔的 Work Item 目錄。
- 保留下來的 main worktree 內的 Work Item 原地不動。
- 交件單與審查報告的既有歸檔方式不變。

驗收條件：

- loop worktree 有 `work-items/WI-<id>/`（含子目錄檔案）時，cleanup 後該目錄完整出現在 archive 的對應位置，worktree 照常移除。
- 預覽列出該 Work Item 目錄，且不改動任何東西。
- 實作者在 main worktree（`--worktree here`）時，main worktree 的 Work Item 仍在原處。
- 封存區仍不被 Git 追蹤。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `agent-crew-launcher`: cleanup 在移除 loop worktree 前歸檔其中的 Work Item，預覽列出將歸檔的 Work Item。

## Impact

- 程式：`scripts/handoff/handoff-cleanup`。
- 測試：`tests/test_agent_handoff.sh` 的 cleanup 段落。
- 文件：`scripts/handoff/README.md`（`handoff-cleanup`）、`docs/skills/agent-handoff.md`（收尾與清理）、
  `docs/diagrams/agent-handoff-cleanup.svg`（步驟 ①）。
- 使用者環境：合併後需重跑 `bash scripts/handoff/install.sh` 更新 `~/.local/bin/handoff-cleanup`。
- 來源：Pi 交接實測 Work Item `WI-20261119-pi-handoff-field-test` 的 O-20（本機紀錄，不隨 repo 散布）。
