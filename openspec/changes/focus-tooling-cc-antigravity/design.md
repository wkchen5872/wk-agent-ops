## Context

`tooling_scope_cc_antigravity` memory：專案只用 Claude Code + Antigravity。Antigravity 規則載入（已查證）：

| 用途 | 路徑 | 形式 | 來源 |
|------|------|------|------|
| Workspace rules | `<ws>/.agent/rules/*.md` | 單數 `.agent`、**扁平**、markdown | antigravity.google/docs/rules-workflows；atamel.dev |
| Workflows | `<ws>/.agent/workflows/*.md` | 單數、扁平 | 同上 |
| 跨工具規則 | 專案根 `AGENTS.md` | Antigravity 與 Claude Code 共讀 | 同上 |
| Antigravity 專屬/全域 | `GEMINI.md` / `~/.gemini/GEMINI.md` | 最高優先 | 同上 |

Claude Code 讀 `.claude/rules/`、`.claude/skills/`、`CLAUDE.md`/`AGENTS.md`。

## Goals / Non-Goals

**Goals:**
- rules 同時送達 Claude Code（`.claude/rules/`）與 Antigravity（`.agent/rules/`，扁平）。
- 清掉所有 Copilot / Codex / Gemini CLI 假設。
- 修掉 `.agents`(複數)/`.agent`(單數) 不一致與 workflow 從未被 sync 的 bug。

**Non-Goals:**
- 不處理 `GEMINI.md` / 全域規則（Antigravity 專屬，使用者自行管理）。
- 不動 git-commit-writer 的「印出自己模型名＋版本」自我標記設計（刻意保留）。
- 不碰 supabase 規則時態（另案）。

## Decisions

1. **rules emit 採複製而非 symlink** — install.sh 把安裝到 `.claude/rules/` 的 `*.md` 再 `rsync` 一份到 `.agent/rules/`（扁平）。template `.claude/rules/` 本就無子目錄，直接平拷即可，符合 Antigravity 扁平需求。
2. **統一 `.agent`（單數）** — 這是 Antigravity 實際讀的路徑。template `common/.agents/` 改名為 `common/.agent/`；install.sh 行 88（skills）、91、93 一併改單數，並讓 `.agent/workflows/` 真正 sync。
3. **`.github` 整段移除** — 無 Copilot 即無 `.github/instructions/` 需求。移除 template 兩處目錄與 install.sh 行 91 的 `.github` mkdir、行 94、行 113。
4. **multi-tool-compatibility.md 保留檔名但縮成雙工具** — 仍叫此名（避免連帶改引用），內容改 Claude Code + Antigravity；env 偵測 `CLAUDE_PROJECT_DIR → PWD`（Antigravity 在 workspace 內執行，PWD 即足夠）。
5. **skills 維持 `.claude/skills` + `.agent/skills`** — 後者由 `.agents/skills`→`.agent/skills` 純路徑統一而來；Antigravity 若不讀亦無害（多一份不影響）。

## Risks / Trade-offs

- rules 在 `.claude/rules/` 與 `.agent/rules/` 各一份 → 內容重複。可接受：兩工具讀不同路徑，這是必要的鏡像，且由 install.sh 自動產生，非手動維護。
- `.agents`→`.agent` 改名：既有已安裝專案若已有 `.agents/`，重跑 install 會新增 `.agent/` 而不清舊的 `.agents/`。於 tasks 註明並在 install 輸出提示，或文件說明手動清理。
- Antigravity 是否讀 `.agent/skills/` 未完全確認 → 採「多送無害」策略，不依賴它。
