# Design

## Context

見 proposal.md「Why」。現況：

- `handoff-start` 以 `apply_ov` 把 override 寫進 `roles.yaml` 的暫存副本（harness、model、effort、provider、billing），之後
  `ho_template_check`、「一個 worktree 最多一個 Pi 角色」、`ho_pi_ready` 檢查，再以 `ho_copy_template` 寫入 `loop.yaml` 的
  `<role>_template`（值帶引號）。`name`、`prompt` 不隨 override 改變。
- hook 在第一次交件時依 `review_template` 開啟審查者，在 `handoff-finish`（或 `trigger: auto`）時依 `finish_template` 開啟收尾；
  開啟後 `reviewer.session`／`finish.session` 寫入 session ID。開啟前 hook 會再跑一次 Pi 檢查。
- `kv_get` 去掉一層外圍引號；`kv_set` 原樣寫入。

## Goals / Non-Goals

**Goals:**

- 一個指令完成「換未開啟角色＋與啟動相同的檢查」。
- override 換工具時 prompt 的 skill 呼叫與 session 名稱自動跟著換，`handoff-start` 與 `handoff-role` 共用同一份邏輯。

**Non-Goals:**

- 不更換已開啟的角色、不更換實作者、不改 `worktree`、`profile`、`name`／`prompt` 的其他內容。
- 不改寫 prompt 中間出現的其他 skill 名稱，只處理開頭的呼叫。

## Decisions

### 1. 共用函式 `ho_apply_override <file> <section> <override>`

- 從 `handoff-start` 的 `apply_ov` 移入函式庫：解析 override、寫 harness／model／effort／provider／billing；若 harness 與原值不同，
  以 `ho_retool_text` 改寫 prompt 開頭（`^(/skill:|\$|/)<name>` → 新工具寫法）與名稱前綴（`^(claude|codex|pi) - ` → 新工具名稱）。
- 寫入時沿用目標檔案的格式：值以雙引號包住（與 `ho_copy_template` 相同），`roles.yaml` 暫存副本與 `loop.yaml` 都適用，
  因為 `kv_get` 會去掉外圍引號。
- 替代方案：在 prompt 範本加 `{skill:...}` placeholder 由渲染時決定寫法。不採用——要改所有既有 `roles.yaml` 與範例，
  影響使用者自訂範本；改寫開頭呼叫只動 override 的情境。

### 2. `handoff-role` 的流程

```
handoff-role <change> <review|finish> <override>
  → 找迴圈（ho_find_loop_dir）→ 角色 session 已記錄？→ 拒絕
  → 複製 loop.yaml 到暫存檔 → ho_apply_override（<role>_template）
  → ho_template_check → 一個 worktree 最多一個 Pi 角色 → Pi 角色時 ho_pi_ready
  → 全部通過才以暫存檔取代 loop.yaml，印出新的工具／模型／effort
```

- 「最多一個 Pi 角色」的判斷與 `handoff-start` 相同：實作者，以及 `worktree` 不是 `new` 的審查／收尾，算在實作者 worktree。
- 直接修改：不需要 `--yes`，與 `handoff-start` 的 override 一致；失敗時檔案不變。
- 替代方案：允許更換已開啟的角色並刪除舊 session。不採用——進行中的審查會遺失，且需要處理 worktree 設定檔；先只支援未開啟角色。

### 3. TDD 策略與測試邊界

- `tests/test_agent_handoff.sh` 新增 `role` 區段，沿用假 `xirp`、假 `pi` 與既有 fixture：
  - 未開啟審查者時換成 Pi：`loop.yaml` 值正確、prompt 以 `/skill:change-review` 開頭、名稱以 `pi - ` 開頭；接著交件，假 `xirp`
    的 create 請求使用新範本。
  - 審查者已開啟、Pi 檢查失敗、第二個 Pi 角色：非零結束、`loop.yaml` 位元組不變。
  - override 格式錯誤：非零結束並顯示格式。
  - `handoff-start --review pi:...`（範本為 Codex）：`loop.yaml` 的 prompt 與名稱已改寫；只換 model 時不變。
  - 安裝：`install.sh` 安裝 `handoff-role`，README 提及。
- 既有 start／route／finish／cleanup／Pi 測試維持通過。

## Risks / Trade-offs

- [自訂 prompt 開頭不是 skill 呼叫] → 不改寫，維持原樣；只有符合三種寫法的開頭會被換。
- [名稱前綴不是工具名稱] → 不改寫。
- [`awk -v` 會解讀反斜線跳脫] → `kv_set` 既有行為；範本 prompt 不使用反斜線。

## Migration Plan

1. 合併後執行 `bash scripts/handoff/install.sh` 安裝 `handoff-role` 並更新函式庫。
2. 回退：重裝前一版；已寫入的 `loop.yaml` 仍是合法範本。
