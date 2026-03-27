---
name: doc-updater
description: >
  Update docs/, README.md, and AGENTS.md based on the last git commit.
  Reads the last commit message and diff, classifies the change type, makes
  minimal targeted edits to relevant documentation, then creates a separate
  docs: commit. Skips trivial commits automatically.
license: MIT
compatibility: Requires git.
metadata:
  author: wkchen
  version: "1.0"
---

# Doc Updater

在每一次 git commit 後，自動同步 `docs/`、`README.md`、`AGENTS.md` 等說明文件。

適用於所有類型的 commit，不依賴 OpenSpec 工作流程。針對瑣碎變更（test、style、typo 等）會自動跳過，只在有實質影響時才更新文件並建立獨立的 `docs:` commit。

**立即執行，不需確認。**

---

## Step 1 — Gather context (run in parallel)

```bash
git log -1 --format="%H%n%s%n%b"
git diff HEAD~1 HEAD --stat
git diff HEAD~1 HEAD
```

---

## Step 2 — Classify the commit (skip check)

檢查 commit subject 與 diff 內容。符合以下任一條件時，輸出 skip 訊息並**停止**：

| 條件 | 跳過原因 |
|------|---------|
| Subject 以 `docs:` 開頭 | 已是 docs commit，避免無限循環 |
| Type 為 `test:` | 僅測試變更 |
| Type 為 `style:` | 僅格式/排版調整 |
| Subject 含 "typo"、"wording"、"rename var"、"whitespace" | 瑣碎編輯 |
| Type 為 `fix:` **且** diff 總行數 < 10 | 微小修正，無文件影響 |
| Type 為 `chore:` 或 `refactor:` **且** 無新增檔案 | 純維護性變更 |

跳過時輸出：
```
⏭️  No doc update needed
Reason: <reason>
```

---

## Step 3 — Inventory existing docs

```bash
ls docs/
```

讀取每個現有 `docs/*.md` 的前 30 行，了解各文件涵蓋範圍。
`README.md` 與 `AGENTS.md` 永遠列為候選更新目標。

---

## Step 4 — Decide which docs to update

根據 diff 中偵測到的變更，套用以下決策表：

| 偵測到的變更 | 更新目標 |
|------------|---------|
| 新增 `.claude/agents/*.md` 或 `template/common/.claude/agents/*.md` | `AGENTS.md`（新增 agent 項目） |
| 新增 `.claude/skills/*/SKILL.md` 或 `template/common/skills/*/` | `AGENTS.md`（新增 skill 參照） |
| 新增 `template/<profile>/` 或修改 `install.sh` | `docs/template-profiles.md`、`README.md` |
| 修改 `scripts/worktree/` | `docs/multi-agent-workflow.md`、`README.md` |
| 新增 env var 或新外部相依套件 | `README.md`（相依套件區段） |
| `feat:` commit 且有廣泛功能影響 | `README.md` 及/或 `docs/<feature>.md` |
| 純內部重構、只改設定、無新使用者功能 | 跳過 |

在開始編輯前，顯示計畫更新清單：
```
📝 Planned doc updates:
  - AGENTS.md     — <原因>
  - README.md     — <原因>
```

---

## Step 5 — Read target docs

對 Step 4 中確定的每個檔案，先完整讀取再進行編輯。

---

## Step 6 — Make targeted edits

對每個目標文件：
- **只編輯相關 section**，不重寫無關段落
- **AGENTS.md**：完全遵循現有 `### <name>` 項目格式（位置/用途/特性/觸發方式）
- **README.md**：保持繁體中文；只新增表格列或清單項目，不改結構
- **docs/*.md**：比對現有語氣與格式；在邏輯位置新增 section
- 若需建立新的 `docs/<feature>.md`（有重大新使用者功能時），以 `docs/git-commit-writer.md` 為結構參考

**重要語言規則**：
- README.md 使用繁體中文 → 新增內容必須用繁體中文
- AGENTS.md 混合中英 → 維持現有語言風格
- docs/*.md → 比對該文件已有的語言

---

## Step 7 — Create docs commit

編輯完成後，確認有實際變更：
```bash
git diff --stat docs/ README.md AGENTS.md
```

若有變更，只 stage 已修改的檔案並 commit：
```bash
git add <只 stage 已修改的檔案>
git commit -m "docs: update documentation for <原始 commit subject>

Co-Authored-By: <your current model name> <noreply@anthropic.com>"
```

若無實際變更（已有文件），跳過 commit 並說明原因。

---

## Step 8 — Output

成功時：
```
📝 Docs updated:
  - <file>   — <what changed>

💾 Docs commit: <short-hash> docs: update documentation for <subject>
```

無需更新時：
```
✅ Docs already up to date — no commit needed
```
