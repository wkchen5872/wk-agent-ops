# entropy-check

週期性健康審查 skill（v2.0），偵測 AI agent 專案累積的文件飄移、dead references、未使用程式碼與重構候選。

---

## 快速開始

### Claude Code 中

```
/entropy-check
```

### Skill 呼叫（其他工具）

```
invoke entropy-check skill
```

---

## Context 自動偵測

執行時自動判斷專案類型，決定審查範圍：

| 條件 | Context | 審查項目 |
|------|---------|---------|
| `openspec/changes/` 存在 | `openspec` | D1–D3, C1, O1, R1 |
| 其他 | `standard` | D1–D3, C1, R1 |

> **注意：** v2.0 移除了 harness context（原 H1 template sync 審查），不再偵測 `template/common/`。

環境變數優先順序：`GEMINI_PROJECT_DIR` → `CLAUDE_PROJECT_DIR` → `PWD`

---

## 審查項目

### 通用審查（D1–D3, C1, R1）

| 代碼 | 名稱 | Auto-fix |
|------|------|---------|
| D1 | AGENTS.md coverage — 比對 `.claude/skills/` 與 `.claude/agents/`，找出 AGENTS.md 缺少 `### <name>` 的條目 | ✓ |
| D2 | Docs completeness — 掃描 `docs/architecture.md`、`docs/conventions.md` 中的 placeholder 文字與空 section | — |
| D3 | Dead references — 掃描 AGENTS.md 和 `docs/*.md` 中的 backtick 路徑、`[text](link)` 連結與 anchor | ✓（路徑）/ —（anchor）|
| C1 | Unused code — 偵測 Bash 未使用函式、Python 未使用 import、TS/JS 未使用 named import | — |
| R1 | Refactor candidates — 偵測大型檔案（>150 行 .sh / >300 行 .py/.ts/.js）與高 marker 密度（≥3 TODO/FIXME） | — |

### OpenSpec 審查（O1）

| 代碼 | 名稱 | Auto-fix |
|------|------|---------|
| O1 | Stale active changes — 超過 14 天未更新的 active change（不含 archive/） | — |

---

## 審查細節

### D3 — Dead references auto-fix 邏輯

- **Backtick 路徑** 與 **Markdown `[text](path)` 連結**（path 部分）：
  - 單一匹配 → 就地更新路徑
  - 零匹配 → 移除連結語法，保留 label 文字（`[text](broken)` → `text`）
  - 多個匹配 → 列出候選，不自動修改
- **Anchor（`#section-name`）**：僅報告，不自動修復

### C1 — Unused code 注意事項

所有 C1 findings 標記為 **「confirm before removing」**，屬於啟發式偵測，可能有誤報。**不提供 auto-fix**，需人工確認後處理。

**Bash 偵測邏輯：** 統計函式名稱在所有 `.sh` 檔案中的出現次數（含定義檔本身）。若總次數 ≤ 1（僅有定義行），則回報為未使用。同一檔案內定義並呼叫的函式不會被誤報。

**Python 偵測邏輯：** 對 multi-name import（如 `from foo import bar, baz`），提取第一個名稱時去除尾部逗號，避免 `grep -c "bar,"` 僅匹配 import 行本身造成誤報。

### R1 — Refactor candidates 推薦等級

依 `openspec/.entropy-state` 的 archive 計數決定推薦指令：

| Archive 計數 | 推薦 |
|-------------|------|
| 不存在 / < 5 | `/simplify`（project maturity: early）|
| 5–15 | `/simplify` 為主；可考慮 `/refactor` 處理結構問題 |
| > 15 | `/refactor`（project maturity: high）|

R1 掃描範圍排除 `openspec/` 目錄。

---

## 輸出格式

1. **摘要表** — 每項審查的 ✓ / ⚠️ N findings
2. **Findings 詳細** — 依審查代碼分組
3. **決策選單**（有 findings 時）：
   - `[1]` Auto-fix 可修復項目（D1、D3 路徑）
   - `[2]` 建立 OpenSpec change 處理結構性問題
   - `[3]` Skip — 僅更新 watermark

> **注意：** C1 findings 不納入 `[1]` auto-fix 範圍。

---

## Watermark

每次執行後（包含 skip）將 `openspec/changes/archive/` 下的目錄計數寫入 `openspec/.entropy-state`（不納入版控，已加入 `.gitignore`）。

---

## 移除的審查（v1.0 → v2.0）

| 代碼 | 原名稱 | 移除原因 |
|------|--------|---------|
| H1 | Template sync | harness 專用，在非 harness 專案造成誤判；改由使用者手動執行 `install.sh` |
| O2 | OpenSpec spec sync | 高誤報率；archived change 不一定需要 canonical spec |
| O3 | Dead specs | 誤判率高；spec 可獨立存在不對應 skill/agent |

---

## 相關元件

- `scripts/workflow/entropy-counter/` — PostToolUse hook，archive 計數達閾值時主動顯示提示
- `openspec/.entropy-state` — Watermark 檔案（已加入 `.gitignore`）
- `openspec/specs/entropy-check/spec.md` — 主 spec
- `openspec/specs/entropy-check-c1-unused-code/spec.md` — C1 audit spec
- `openspec/specs/entropy-check-d3-autofix/spec.md` — D3 auto-fix spec
- `openspec/specs/entropy-check-r1-watermark/spec.md` — R1 watermark spec
