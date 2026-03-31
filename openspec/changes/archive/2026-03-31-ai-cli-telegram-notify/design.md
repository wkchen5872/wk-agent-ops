## Context

Claude Code 與 Gemini CLI 均提供 hook 系統，允許在特定事件（任務完成、授權等待）時執行外部腳本。

**核心原則：Repo 只含腳本，機器狀態全部由 `install.sh` 負責**

開發過程中，所有程式碼都寫在 `scripts/` 目錄下，**不建立任何 `~/.config/`、`~/.claude/`、`~/.gemini/` 相關目錄或檔案**。使用者機器上的所有狀態（config 檔、已部署的 hook、settings.json 變更）均透過執行 `install.sh` 產生，沒有例外。

**設計需求：**
1. 不直接修改 `~/.claude/` 或 `~/.gemini/` 作為 repo artifacts；改由 `install.sh` 在使用者授權下執行
2. 不預先建立 `~/.config/ai-notify/config`；config 的建立是 `install.sh` 執行的結果
3. 提供互動式安裝腳本引導 Telegram Bot 設定
4. 提供 AI CLI 內建指令（`/notify-setup`）讓使用者在 CLI 中隨時更新設定
5. 架構需支援未來新增其他通訊軟體（如 Line Notify）時可最小化改動

---

## Goals / Non-Goals

**Goals:**
- `scripts/telegram-notify/install.sh`：互動式安裝精靈，引導建立 Bot、取得 Chat ID、部署 hook、註冊 AI CLI settings
- `scripts/notify/lib/`：共用基礎庫，供 Telegram、Line 等 provider 複用
- Config 集中存放於 `~/.config/ai-notify/config`（不污染 `~/.zshrc`）
- `.claude/commands/notify-setup.md`：`/notify-setup` 指令，在 Claude Code 內設定/更新/測試
- 靜默失敗（credentials 缺失或網路問題不影響 AI CLI）
- Rollback 只需移除 settings.json hook 區塊

**Non-Goals:**
- 不支援 GitHub Copilot CLI（無對應 hook 系統）
- 不提供雙向互動（只推送，不接受 Telegram 回傳指令）
- 不處理 hook 執行歷史或 retry 邏輯
- Line Notify 在本 change 內不實作（但架構預留）

---

## Directory Layout

```
scripts/
  notify/
    lib/
      config.sh        # 讀寫 ~/.config/ai-notify/config
      registry.sh      # 將 hook 加入 ~/.claude/settings.json / ~/.gemini/settings.json
    README.md          # Provider 擴充指南（如何新增 Line Notify）

  telegram-notify/
    install.sh         # 互動式安裝精靈（一次性設定）
    hook.sh            # Telegram 通知 hook（由 AI CLI 呼叫）
    update.sh          # 更新設定（token / notify level）
    uninstall.sh       # 移除 hook 與 config

  line-notify/         # 未來佔位
    .placeholder

.claude/
  commands/
    notify-setup.md    # /notify-setup 指令定義

docs/
  notify-hooks-architecture.md   # 整體架構、擴充指南
  telegram-notify-hook.md        # Telegram 快速安裝說明
```

**部署後 runtime layout（由 install.sh 建立）：**
```
~/.config/ai-notify/
  config               # shell-sourceable 設定檔
  hooks/
    telegram-notify.sh # 從 scripts/telegram-notify/hook.sh 複製過來
```

---

## Decisions

### D1：Repo 只含腳本；所有機器狀態由 `install.sh` 寫入

**決定**：
- Repo artifacts（`scripts/` 下的所有 `.sh` 文件）**只是腳本**，不代表任何機器狀態
- `~/.config/ai-notify/config`、`~/.config/ai-notify/hooks/`、`~/.claude/settings.json` 的 hook 條目——這些全部是 `install.sh` 執行後的**產出**，不是 repo 的一部分
- 開發階段：只寫 `scripts/` 目錄下的腳本
- 安裝階段：使用者執行 `bash scripts/telegram-notify/install.sh` 後，機器狀態才被建立

**Hook 部署路徑**：`scripts/telegram-notify/hook.sh` → install.sh 複製到 `~/.config/ai-notify/hooks/telegram-notify.sh`。AI CLI settings.json 指向此已部署路徑。

**理由**：
- 避免 repo checkout 本身產生副作用（不應 clone 後就改變機器設定）
- `~/.config/ai-notify/` 是 provider 無關的中立目錄，不綁定特定 AI CLI
- 所有機器狀態變更都有明確的使用者意圖（執行 install.sh）

**替代方案**：直接在 settings.json 指向 repo 路徑 → 路徑綁定到 repo 位置，換機器或換路徑就壞掉。

---

### D2：Config 存放於 `~/.config/ai-notify/config`（非 `~/.zshrc`）

**決定**：credentials 與設定寫入 `~/.config/ai-notify/config`（shell-sourceable key=value 格式），hook 腳本執行時 source 此檔案。

格式：
```bash
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN="7123456789:ABCdef..."
TELEGRAM_CHAT_ID="987654321"
NOTIFY_LEVEL=all           # all | notify_only
# LINE_ENABLED=false       # 未來擴充
```

**理由**：
- 不修改 `~/.zshrc`（低侵入性，符合需求）
- 集中管理所有 provider credentials（未來 Line 也寫這裡）
- update.sh 可直接修改此檔案，不需要 shell profile 知識
- 使用者可手動編輯，格式直覺

**替代方案**：env vars in ~/.zshrc → 已在需求中明確排除。

---

### D3：`scripts/notify/lib/registry.sh` 統一管理 AI CLI hook 註冊

**決定**：提取 AI CLI settings.json 操作（新增/移除 hook 區塊）為獨立函式庫 `scripts/notify/lib/registry.sh`，所有 provider 的 install script 呼叫相同函式。

函式介面：
```bash
register_hook()    # 新增 hook 到 AI CLI settings（idempotent）
unregister_hook()  # 移除 hook（安全移除，不影響其他 hooks）
```

**理由**：
- Telegram 的 install.sh 與未來 Line 的 install.sh 都需要修改 settings.json，共用邏輯避免重複
- idempotent 設計讓重複執行 install 不會產生重複的 hook 條目
- 集中管理，settings.json 結構變化只需修改一個地方

---

### D4：`/notify-setup` Claude Code 指令

**決定**：在 `.claude/commands/notify-setup.md` 定義 `/notify-setup` 指令，當使用者在 Claude Code 內輸入此指令時，Claude 執行對應的 shell script（install.sh 或 update.sh）。

指令支援的操作：
- （無參數）：互動式選單（setup / update / test / status / uninstall）
- `setup`：執行 `bash scripts/telegram-notify/install.sh`
- `update`：執行 `bash scripts/telegram-notify/update.sh`
- `test`：模擬觸發 hook 確認設定正確
- `status`：顯示目前 config 內容（mask token）

**理由**：
- 使用者在 AI CLI 工作流程中無需離開介面即可管理通知設定
- `.claude/commands/` 是 Claude Code 原生的 project-level 指令機制
- 未來 Line Notify 可新增 `/notify:line-setup` 等指令，命名空間清晰

---

### D5：共用腳本，以 `$1` 區分事件類型（保留）

**決定**：`hook.sh` 以 `$1`（`stop` / `notification`）傳入事件類型，再從 stdin JSON 的 `hook_event_name` 確認。Claude Code 用 `async: true`，Gemini CLI 靠 `--max-time 10` 保持非阻塞。

（與原 D1/D2 相同，保留）

---

### D6：`scripts/notify/README.md` 作為 Provider 擴充指南

**決定**：提供明確的「如何新增一個新通知 provider」說明，涵蓋：
1. 複製 `scripts/telegram-notify/` 目錄結構
2. 修改 `hook.sh`（provider-specific API 呼叫）
3. 修改 `install.sh`（provider-specific 引導步驟）
4. 在 `~/.config/ai-notify/config` 加入新的 `{PROVIDER}_ENABLED` 開關

**理由**：讓架構的「可複製性」顯式文件化，不只是隱性設計。

---

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| `jq` 未安裝 | hook.sh 以 `command -v jq` 檢查，fallback 到 `$1` 參數 |
| Stop hook 通知過於頻繁 | `NOTIFY_LEVEL=notify_only`，update.sh 與 `/notify-setup` 均可切換 |
| `~/.config/ai-notify/config` 明文 token | 檔案權限設為 600（install.sh 執行 `chmod 600`）；token 不寫入 repo |
| install.sh 重複執行產生重複 hook | registry.sh 的 `register_hook()` idempotent 設計 |
| Gemini CLI 事件名稱未來變更 | hook.sh case 匹配 `AfterAgent` 與 `Stop`，其他 fallback `$1` |
| settings.json 為空或格式異常 | registry.sh 使用 `jq` 合併而非字串貼上，格式安全 |

---

## Migration Plan

**實作階段（Task 1–6）**：只在 repo 的 `scripts/` 與 `.claude/` 目錄下撰寫腳本，不建立任何 `~/.config/` 相關路徑，不修改 `~/.claude/` 或 `~/.gemini/`。

**安裝與驗收階段（Task 7–8）**：
1. 執行 `bash scripts/telegram-notify/install.sh`（互動式引導）
   - 或在 Claude Code 內輸入 `/notify-setup`
2. install.sh 自動完成：token 設定、config 寫入、hook 部署、settings.json 更新
3. 手動驗證：傳送測試訊息給 Claude，確認收到 Telegram 通知

**Rollback**：執行 `bash scripts/telegram-notify/uninstall.sh`，或在 Claude Code 內 `/notify-setup` → uninstall。

---

## Open Questions

（無）
