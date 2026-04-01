## Context

目前 `wt-new.sh` 的語意模糊：它同時負責「建立新 worktree」和「自動偵測已存在的 worktree 並恢復 coding」。此外，兩支腳本（wt-new、wt-resume）均不支援 Gemini CLI，也無法讓使用者顯式指定 AI session ID 或 name。

隨著多 AI CLI 工具並行使用，需要：
1. 清楚的語意分工（coding 工作 vs 對話恢復）
2. 統一的 `--session` 參數介面
3. Gemini CLI 的完整支援

## Goals / Non-Goals

**Goals:**
- 重新命名 `wt-new.sh` → `wt-work.sh`，語意為「開始/繼續 coding 工作」
- 新增 `--session <id|name>` 選填參數（兩支腳本）
- 新增 `--agent gemini` 支援（兩支腳本）
- `wt-work.sh` resume path 強制帶入 `/opsx:apply` prompt（與 new path 行為一致）
- `wt-resume.sh` 無 --session 時顯示清單（不自動帶 session name）
- 更新 Zsh completion、install.sh、workflow guide

**Non-Goals:**
- 不新增對 Codex 的 `--resume` 支援（Codex 無 session 恢復機制）
- 不驗證 --session 格式（Claude name vs UUID vs Copilot UUID vs Gemini index）
- 不實作 session 清單查詢功能（依賴各 CLI 工具原生 --resume 清單）

## Decisions

### D1: wt-new → wt-work 命名

**決策**：重新命名，不保留舊名稱 alias。

**理由**：
- 保留 alias 會讓語意繼續模糊
- `wt-work` 清楚表示「我要進行/繼續這個 feature 的 coding 工作」
- `install.sh` 重新安裝即可更新；舊版本印警告提示移除

**替代方案**：保留 `wt-new`（不命名）→ 拒絕，語意混淆問題未解決。

### D2: --session 透傳策略

**決策**：user 輸入什麼就傳什麼，不做格式驗證。

各 CLI 格式差異：
| 工具 | 指令格式 |
|------|----------|
| Claude | `claude --resume <name-or-uuid>` |
| Copilot | `copilot --resume=<uuid>`（等號格式，只接受 UUID） |
| Gemini | `gemini --resume <number-or-uuid>` |

**理由**：各 CLI 工具本身會驗證並給出錯誤訊息。腳本層驗證格式會過度耦合 CLI 工具的版本變化。

**替代方案**：依工具驗證 UUID 格式 → 拒絕，維護成本高。

### D3: wt-work resume path 強制執行 /opsx:apply

**決策**：resume path（目錄已存在）也帶入 `/opsx:apply $NAME` 作為 prompt。

**理由**：
- `opsx:apply` 設計為冪等（已完成的 tasks 不會重複執行）
- coding 中斷後恢復，agent 需重新對齊 task 狀態再繼續
- 統一了 new/resume 兩個路徑的行為，減少心智負擔

**替代方案**：resume path 不帶 prompt → 拒絕，使用者要手動輸入 /opsx:apply。

### D4: wt-resume 無 --session 時顯示清單

**決策**：無 --session 時，Claude 用 `claude --resume`（顯示清單），不自動帶 session name。

**理由**：
- `wt-resume` 語意是「還原之前的對話狀態」，使用者需要選擇哪個 session
- 與 Copilot/Gemini 的行為一致（都是讓使用者/工具自己選擇）
- 舊行為 `claude --resume "RD: $NAME"` 移至 `wt-work` 的 resume path

### D5: Gemini 語法

**決策**：Gemini 新 session 使用 `gemini -p "/opsx:apply $NAME"`。

**待驗證**：`-p` flag 是否為正確的 prompt 參數（在實作時確認）。

Gemini resume：
- 無 --session: `gemini --resume`（auto latest chat）
- 有 --session: `gemini --resume <session>`（index 或 UUID）

## Risks / Trade-offs

- **[Risk] wt-new 移除造成破壞性變更** → Mitigation：install.sh 印明確警告，guide.md 更新說明遷移路徑
- **[Risk] Gemini 新 session 語法未驗證** → Mitigation：tasks 中列為需驗證項目，實作前確認
- **[Risk] Copilot resume + -i 相容性未確認** → Mitigation：tasks 中列為需測試項目（`copilot --resume=<id> --allow-all -i "prompt"` 是否合法）
- **[Risk] claude --resume <name> "/opsx:apply" 帶 prompt 的行為** → Mitigation：Claude Code 支援 `--resume <session> <prompt>` 語法需在實作時驗證

## Migration Plan

1. 實作 `wt-work.sh`（新增檔案）
2. 修改 `wt-resume.sh`（新增 --session、gemini）
3. 更新 `_wt` completion（新增 wt-work、--session、gemini）
4. 更新 `install.sh`（安裝 wt-work，印舊版警告）
5. 執行 `install.sh` 更新本地環境
6. 更新 `docs/workflow/guide.md`
7. 手動驗證各工具行為（Claude/Copilot/Gemini）

Rollback：若有問題，可恢復 `wt-new.sh` 並重新安裝。Worktree 目錄結構不受影響。

## Open Questions

1. Gemini `-p` flag 是否正確？`gemini --help` 確認
2. Copilot `--resume=<id> --allow-all -i "prompt"` 是否相容？
3. Claude `--resume <session> "<prompt>" --enable-auto-mode` 語法是否正確？
