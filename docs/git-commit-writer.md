# git-commit-writer

獨立的 Conventional Commits 格式化與執行工具。既可作為 Claude Code sub-agent 自動使用，也可作為通用 skill 跨工具呼叫。

---

## 快速開始

### Claude Code 中

在任何 git worktree 中，直接呼叫 sub-agent：

```
Use the git-commit-writer agent.
archive_path: openspec/changes/archive/YYYY-MM-DD-<name>/
change_id: <change-name>
```

（或搭配 `openspec-commit` skill 自動 invoke）

### 其他工具 (Copilot CLI, Antigravity)

呼叫 skill：

```
/git-commit-writer
archive_path: <archive_path>
change_id: <change_id>
```

---

## 架構

### Sub-Agent 與 Skill 的區別

```
┌─────────────────────────────────────────────────────────────┐
│                     git-commit-writer                       │
├──────────────────────────┬──────────────────────────────────┤
│    .claude/agents/       │   .claude/skills/                │
│   git-commit-writer.md   │   git-commit-writer/SKILL.md     │
├──────────────────────────┼──────────────────────────────────┤
│ 用途: Claude Code 專用   │ 用途: 跨工具（CC/Copilot/Ag）   │
│ model: haiku             │ model: 工具決定                  │
│ frontmatter 鎖死模型     │ 純 markdown 指令集               │
│ 自動權限檢查             │ 需手動傳入 context               │
└──────────────────────────┴──────────────────────────────────┘
```

### 兩者的運作邏輯

**Sub-Agent（.claude/agents/git-commit-writer.md）**

1. **觸發方式**：自然語言或 `@` mention
2. **模型選定**：frontmatter `model: haiku` 固定使用 Haiku 4.5
3. **Context 來源**：
   - 可從使用者輸入讀取 `archive_path` 和 `change_id`
   - 或自動偵測 `openspec list --json`
4. **執行流程**：
   - Step 1：蒐集 `git diff --cached` 和 openspec 上下文
   - Step 2：讀取 proposal.md（如果有）
   - Step 3：推斷 commit type
   - Step 4：組合 commit message
   - Step 5：執行 `git add -A && git commit`

**Skill（.claude/skills/git-commit-writer/SKILL.md）**

1. **觸發方式**：用戶在任何工具上呼叫 `/git-commit-writer`
2. **模型選定**：工具層決定（Copilot CLI 用 GPT-5 mini，Antigravity 用 Gemini Flash）
3. **Context 來源**：使用者或上一步（如 `openspec-commit`）傳入
4. **執行流程**：同上

---

## 使用情境

### 情境 1：openspec-commit 自動呼叫

```
開發者: /openspec-commit
       │
       ├─ Step 1-4: archive + docs
       │
       └─ Step 5: Use the git-commit-writer agent
            │
            └─ Haiku 讀 archive_path/proposal.md
            └─ 執行 git commit (自動，無確認)
            └─ 返回 commit hash
       │
       └─ Step 6: 完成摘要
```

**效果**：無需確認，費用省 ~90%（Haiku vs Sonnet）

### 情境 2：獨立執行

```
開發者: 在 git worktree 做好變更，未呼叫 openspec-commit
       │
       └─ /git-commit-writer
            │
            └─ Haiku 自動偵測：無 active openspec change
            └─ 只靠 git diff 推斷 type + subject
            └─ 執行 commit（無 scope）

結果: feat: add new feature
      (不包含 <change-id> scope)
```

### 情境 3：跨工具使用

```
Copilot CLI 使用者: gh copilot /git-commit-writer
                                    │
                                    └─ GPT-5 mini 執行 skill
                                    └─ 同樣的邏輯，模型不同

Antigravity 使用者: 在 Antigravity 中呼叫 /git-commit-writer
                      │
                      └─ Gemini Flash 執行 skill
```

---

## Conventional Commits 格式

### 有 openspec change

```
feat(<change-id>): add new capability

Detailed description of what was done.
Why this change is necessary.

1-2 lines describing motivation and approach.
```

例子：
```
feat(git-commit-writer): extract commit formatting to standalone skill

Separate git commit logic from openspec-commit to enable execution
on cheaper models (Haiku/GPT-5 mini/Gemini Flash) in Claude Code,
Copilot CLI, and Antigravity.
```

### 無 openspec change

```
feat: add new feature

Detailed description.
```

例子：
```
chore: update dependencies

Bump @types/node to latest stable version.
Fixes potential security vulnerabilities.
```

### Type 推斷規則

| 變更性質 | type |
|---------|------|
| 新功能、新資料來源 | `feat` |
| 修正錯誤行為 | `fix` |
| 重構（無行為改變） | `refactor` |
| 文件異動 | `docs` |
| 工具、設定、維護 | `chore` |
| 測試新增或修正 | `test` |

---

## 費用節省對比

```
情境：openspec 開發週期完整 (archive → docs → commit)

Sonnet 4.6:  1 次 token 消耗（全部做完）
Haiku 4.5:   ~1/20 token 費用

使用 git-commit-writer:
  openspec-commit (Sonnet): archive + docs 步驟
  git-commit-writer (Haiku):          ↓ commit 步驟
  ─────────────────────────────────────────────────
  總費用: ≈ Sonnet tokens + 少量 Haiku tokens
        = 約 10-20% Sonnet 全做的費用

GitHub Copilot CLI:
  整個 openspec-commit → GPT-5 mini
  = 原生更便宜，plus git-commit-writer skill 可獨立使用

Antigravity:
  整個 openspec-commit → Gemini Flash
  = 費用最低
```

---

## 常見問題

### Q: 為什麼需要 sub-agent 和 skill 兩種？

**A:** 不同場景需要不同工具：
- **Sub-agent** 在 Claude Code 中提供最佳體驗（自動模型選定，與 openspec-commit 無縫整合）
- **Skill** 讓 Copilot CLI 和 Antigravity 使用者也能享有相同功能

### Q: Haiku 的 commit message 品質夠嗎？

**A:** Conventional Commits 是結構化格式，Haiku 完全能勝任。如果品質不滿意，使用者可用 `git commit --amend` 修正。

### Q: 如果 commit 失敗（pre-commit hook）怎麼辦？

**A:** git-commit-writer 會自動修正並重試。如果仍失敗，使用者須手動介入。

### Q: 可以互動式編輯 commit message 嗎？

**A:** 不行。設計上直接執行，無確認流程。這是為了支援背景執行和自動化場景。如需編輯，用 `git commit --amend`。

### Q: 在 openspec-commit 中不想用 Haiku，改用 Sonnet 可以嗎？

**A:** 可以。修改 `.claude/agents/git-commit-writer.md` 的 `model` 欄位為 `sonnet`，但就失去省錢的優勢了。

---

## 相關文件

- `docs/commit-feature-workflow.md` — 完整 `/openspec-commit` workflow
- `.claude/agents/git-commit-writer.md` — Sub-agent 定義
- `.claude/skills/git-commit-writer/SKILL.md` — Skill 定義
- `.claude/rules/openspec-commits.md` — Conventional Commits 規範
