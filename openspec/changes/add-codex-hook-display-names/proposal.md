# Proposal

## Why

Codex `/hooks` 以 handler 的 `statusMessage` 作為顯示名稱，未填時顯示 `Unnamed hook`。目前本專案的 Telegram、OpenSpec 分支及 Agent 交接註冊程式都未寫入此欄位，使用者難以辨認要信任或啟用的項目。[^codex-title]

## What Changes

- 為本專案註冊的六個 Codex handlers 提供固定、可辨認功能的預設顯示名稱，使用 `statusMessage`。
- 一般安裝或重複註冊時，為本工具管理的既有 handler 補齊缺少、null、空字串或純空白的名稱，保留非空白的自訂名稱。
- 一般註冊時保留現有 command、matcher、timeout、其他 handler 欄位、第三方 hooks 與其他設定，不新增重複註冊。
- 在操作文件列出名稱、設定層級、重新開啟 Codex session 及重新信任的步驟。說明 Telegram `fix-hooks` 沿用刪除後重建的修復行為，會恢復預設名稱。
- 以暫存 HOME 驗證新安裝、既有配置補名、重跑、名稱保留及跨工具隔離。

驗收條件是新舊 Codex 註冊都具有預設名稱或原有自訂名稱，第二次執行結果不變，且第三方項目及其他 Provider 配置保持相容。Codex 真實面板顯示與信任流程另需操作驗收。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `telegram-notify-hook`: 四個 Codex 通知與等待檢查 handlers 的預設名稱、既有名稱補齊及明確修復行為。
- `openspec-branch-creator-hook`: Codex 分支相容 hook 的顯示名稱與既有註冊補名。
- `agent-handoff-routing`: Codex Stop 交接 hook 的顯示名稱與既有註冊補名。

## Impact

- 註冊來源為 `scripts/notify/lib/registry.sh`、`scripts/workflow/lib.sh`、`scripts/workflow/openspec-branch-creator/install.sh` 及 `scripts/handoff/install.sh`。
- 測試沿用 `scripts/notify/telegram/test.sh`、`tests/test_workflow.sh` 及 `tests/test_agent_handoff.sh` 的暫存環境。
- 更新 `docs/hooks/codex-hooks.md`、`docs/notify/telegram.md`、`scripts/notify/README.md`、`scripts/workflow/README.md` 及 `scripts/handoff/README.md` 的相關操作段落。
- 支援範圍仍為 Claude Code、Codex、Antigravity 及既有 Copilot CLI 整合。新增的顯示名稱只寫入 Codex 配置，其餘 Provider 的註冊方式維持原狀。
- 使用者層級的 `~/.codex/hooks.json` 由各模組現有安裝或修復指令更新。`scripts/skills/install.sh` 不管理這些 hook 註冊，此變更不直接編輯已安裝副本。
- 無新增依賴。變更 hook 定義後，Codex 需要重新信任；安裝程式不代為修改 trust 或 enable 狀態。[^codex-trust]

[^codex-title]: [Codex hook 顯示邏輯](https://github.com/openai/codex/blob/main/codex-rs/tui/src/bottom_pane/hooks_browser_view.rs#L420-L425)，2026-11-16 已讀取官方 main 原始碼。
[^codex-trust]: [Codex hooks 官方說明](https://learn.chatgpt.com/docs/hooks#review-and-trust-hooks)，2026-11-16 查閱。定義變更後的 trust review 與實際面板驗收是不同檢查。
