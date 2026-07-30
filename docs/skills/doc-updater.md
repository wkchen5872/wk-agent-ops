---
type: Playbook
title: Doc Updater
description: Update project documentation from current Git changes or recent commits.
tags: [skills, documentation, git]
timestamp: 2026-07-30T00:00:00+08:00
---

# doc-updater

分析當前的 git 變更或最近的 commit 內容，並自動同步更新 `docs/`、`README.md`、`AGENTS.md` 等說明文件。不依賴 OpenSpec 工作流程，適用於所有類型的變更。

---

## 快速開始

### Claude Code 中

```
@"doc-updater (agent)"
```

### Skill 呼叫

```
/doc-updater
```

---

## 架構

doc-updater 同時以 **sub-agent** 和 **skill** 兩種形式提供：

| 形式 | 路徑 | 使用方式 |
|------|------|---------|
| Sub-agent | `.claude/agents/doc-updater.md` | `@"doc-updater (agent)"` |
| Skill | `.claude/skills/doc-updater/SKILL.md` | `/doc-updater` |
| Portable skill | `.agents/skills/doc-updater/SKILL.md` | 由支援 project skill 的 host 呼叫 |

Template 來源位於 `template/common/`，透過 `install.sh` 同步到 `.claude/`
與 `.agents/`。

## OpenSpec archive context

`openspec-commit` 呼叫時會傳入：

```text
change_id=<archived change id>
archive_path=<exact archived change directory>
```

doc-updater 先驗證路徑，再讀取 `<archive_path>/proposal.md` 與
`<archive_path>/specs/**/*.md`。這些檔案描述意圖；`git status --short` 和
`git diff HEAD` 描述實際完成內容。兩者不同時，只記錄 Git diff 能證明的能力。

---

## 兩種運作模式

doc-updater 會先偵測 `git status`，自動選擇模式：

### Mode A — 有未 commit 的變更

**觸發時機**：工作區有 staged 或 unstaged 的檔案

**行為**：
1. 掃描 `git status --short` 與 `git diff HEAD`（全部未 commit 的變更）
2. 分析哪些文件需要更新
3. 直接更新文件（留在工作區）
4. **不建立獨立的 docs commit**——文件變更會與 feature 一起 commit

```
git diff HEAD → 分析 → 更新文件 → 留在工作區
```

### Mode B — 工作區乾淨

**觸發時機**：工作區無任何變更（所有變更都已 commit）

**行為**：
1. 使用 caller 提供的 N；可互動的 host 才詢問，否則預設 1（範圍 1-10）
2. 掃描最近 N 個 commit 的 diff
3. 分析哪些文件需要更新
4. 更新文件並**留在工作區**，由用戶 review 後手動 commit

```
resolve N → git diff HEAD~N HEAD → 分析 → 更新文件 → 留在工作區
```

---

## 使用情境

### 情境 1：commit 前補充文件（Mode A）

```bash
# 你做了一些修改，還沒 commit
git add .
/doc-updater          # → 掃描 staged 變更，更新文件到工作區
git commit -m "feat: add doc-updater"   # 文件更新一起進這個 commit
```

### 情境 2：commit 後補充文件（Mode B）

```bash
# 你已經 commit 了
git commit -m "feat: add doc-updater"
/doc-updater          # → resolve N（預設 1），更新文件留在工作區
# review 後自行 commit
git add docs/ README.md AGENTS.md
git commit -m "docs: update documentation"
```

### 情境 3：補充多個 commit 的文件（Mode B）

```bash
# 你做了好幾個 commit 都沒更新文件
/doc-updater          # → 可互動 host 輸入 3，掃描最近 3 個 commits
```

---

## 更新目標對照

| 偵測到的變更 | 更新哪些文件 |
|------------|------------|
| 新增 agent 或 skill | `AGENTS.md` |
| 新增 template profile 或修改 install.sh | `template-profiles.md`、`../../README.md` |
| 修改 workflow scripts | `../workflow/guide.md`、`../../README.md` |
| 新增相依套件或 env var | `README.md`（相依套件區段） |
| 重大新功能或使用者可見能力 | `README.md` 及/或 `docs/<feature>.md` |
| 純內部實作、無使用者影響 | 不更新 |

---

## Skip 邏輯（Mode B 限定）

| 條件 | 跳過原因 |
|------|---------|
| 所有 N 個 commits 都是 `docs:` | 已是文件 commit，避免無限循環 |
| 所有 N 個 commits 都是 `test:` 或 `style:` | 無使用者可見影響 |

Mode A 不套用 skip 邏輯（無 commit type 可判斷）。

---

## 常見問答

**Q: Mode A 和 Mode B 怎麼選？**

A: 不需要選，doc-updater 自動偵測。有未 commit 的檔案就是 Mode A，工作區乾淨就是 Mode B。

**Q: doc-updater 會自動 commit 嗎？**

A: 不會。兩種模式都只更新文件並留在工作區，由你 review 和調整後自行 commit。

**Q: Mode A 的文件更新會不會污染我的 feature commit？**

A: 刻意設計如此。文件和 feature 是同一次變更的一部分，合在一個 commit 語意更清晰。若你不想包含，可在 doc-updater 跑完後 `git restore docs/ README.md AGENTS.md`。

**Q: Mode B 支援最多幾個 commit？**

A: 最多 10 個。超過建議分批執行，或者直接手動補充文件。

**Q: doc-updater 和 openspec-commit 的文件更新有什麼不同？**

A: `openspec-commit` 不另外實作文件邏輯，而是把精確的 OpenSpec archive
context 傳給 doc-updater。獨立呼叫時，doc-updater 仍可只依 Git diff 運作。

**Q: README.md 是繁體中文，doc-updater 會不會寫成英文？**

A: 不會。skill 指令中明確規定更新 README.md 時必須使用繁體中文。

---

## 相關檔案

- `.claude/agents/doc-updater.md` — Agent 定義
- `.claude/skills/doc-updater/SKILL.md` — Skill 定義
- `.agents/skills/doc-updater/SKILL.md` — Portable skill 安裝位置
- `template/common/.claude/agents/doc-updater.md` — Template 來源（agent）
- `template/common/skills/doc-updater/SKILL.md` — Template 來源（skill）
- [Git Commit Writer](/docs/skills/git-commit-writer.md)
- [OpenSpec commit 工作流程](/docs/workflow/commit.md)
