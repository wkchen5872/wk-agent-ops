# entropy-check

週期性健康審查 skill，偵測 AI agent 專案累積的文件飄移、廢棄規格、dead references 與 template 脫同步問題。

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
| `template/common/` 存在 | `harness` | U1–U3, H1, O1–O3 |
| `openspec/changes/` 存在 | `openspec` | U1–U3, O1–O3 |
| 其他 | `standard` | U1–U3 |

環境變數優先順序：`GEMINI_PROJECT_DIR` → `CLAUDE_PROJECT_DIR` → `PWD`

---

## 審查項目

### 通用審查（U1–U3）

| 代碼 | 名稱 | Auto-fix |
|------|------|---------|
| U1 | AGENTS.md coverage — 比對 `.claude/skills/` 與 `.claude/agents/`，找出 AGENTS.md 缺少 `### <name>` 的條目 | ✓ |
| U2 | Docs completeness — 掃描 `docs/architecture.md`、`docs/conventions.md` 中的 placeholder 文字 | — |
| U3 | Dead references — 掃描 AGENTS.md 和 `docs/*.md` 中不存在的本地路徑引用 | — |

### Harness 專用審查（H1）

| 代碼 | 名稱 | Auto-fix |
|------|------|---------|
| H1 | Template sync — `diff -r template/common/.claude/ .claude/`，有差異時提示執行 `install.sh` | ✓ |

### OpenSpec 審查（O1–O3）

| 代碼 | 名稱 | Auto-fix |
|------|------|---------|
| O1 | Stale active changes — 超過 14 天未更新的 active change | — |
| O2 | OpenSpec spec sync — archived change 有 specs 但未同步到 `openspec/specs/` | — |
| O3 | Dead specs — `openspec/specs/<name>/` 無對應 skill 或 agent | — |

---

## 輸出格式

1. **摘要表** — 每項審查的 ✓ / ⚠️ N findings
2. **Findings 詳細** — 依審查代碼分組
3. **決策選單**（有 findings 時）：
   - `[1]` Auto-fix 可修復項目（U1、H1）
   - `[2]` 建立 OpenSpec change 處理結構性問題
   - `[3]` Skip — 僅更新 watermark

---

## Watermark

每次執行後（包含 skip）將 archive 計數寫入 `openspec/.entropy-state`（不納入版控）。

---

## 相關元件

- `scripts/workflow/entropy-counter/` — PostToolUse hook，archive 計數達閾值時主動顯示提示
- `openspec/.entropy-state` — Watermark 檔案（已加入 `.gitignore`）
