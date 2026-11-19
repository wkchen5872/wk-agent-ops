# Tasks

## 1. Cleanup 歸檔 Work Item

- [x] 1.1 在 `tests/test_agent_handoff.sh` 的 cleanup 段落先寫失敗測試：new-mode fixture 的實作者 worktree 放 `work-items/WI-20261119-x/agents/drill.md`（以 info/exclude 忽略），預覽輸出列出該目錄且不改動任何東西；`--yes` 後 archive 的 `<實作者 worktree 名稱>/work-items/WI-20261119-x/agents/drill.md` 存在、worktree 已移除；`--worktree here` fixture 的 Work Item 在 cleanup 後仍在 main worktree。驗證：`bash tests/test_agent_handoff.sh cleanup` 以這些案例失敗（Red），原因是 Work Item 未歸檔、預覽未列出。
- [x] 1.2 修改 `scripts/handoff/handoff-cleanup`：步驟 ① 對 main worktree 以外的 loop worktree 複製 `work-items/WI-*` 到 archive，失敗即停止且不刪任何東西；預覽列出將歸檔的 Work Item 目錄；更新檔頭說明。驗證：`bash tests/test_agent_handoff.sh cleanup` 全部通過（Green），既有 cleanup 斷言不變。
- [x] 1.3 更新文件：`scripts/handoff/README.md` 的 `handoff-cleanup` 步驟 1、`docs/skills/agent-handoff.md` 的「歷史證據歸檔」、`docs/diagrams/agent-handoff-cleanup.svg` 步驟 ① 與 `<desc>`。驗證：依 `docs/okf-conventions.md` 檢查；以 `rg 'work-items' scripts/handoff/README.md docs/skills/agent-handoff.md docs/diagrams/agent-handoff-cleanup.svg` 確認三處都提到 Work Item 歸檔；SVG 以 `xmllint --noout` 通過，並轉成暫存 PNG 目視確認文字未溢出（PNG 不提交）。

## 2. 整合驗收

- [x] 2.1 執行 `bash tests/test_agent_handoff.sh`、`bash tests/test_acceptance_bank.sh`、`bash tests/test_documentation_authoring.sh`、`openspec validate keep-work-items-on-cleanup --strict`。驗證：全部通過。

## Workflow follow-up

- 依專案流程完成審查後封存本 change，確認 `openspec/specs/agent-crew-launcher/spec.md` 已加入新需求。
- 合併後執行 `bash scripts/handoff/install.sh` 更新已安裝的 `handoff-cleanup`。
