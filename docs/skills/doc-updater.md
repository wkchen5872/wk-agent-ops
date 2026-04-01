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

Template 來源位於 `template/common/`，透過 `install.sh` 同步到 `.claude/`。

---

## 兩種運作模式

doc-updater 會先偵測 `git status`，自動選擇模式：

### Mode A — 有未 commit 的變更

**觸發時機**：工作區有 staged 或 unstaged 的檔案

**行為**：
1. 掃描 `git diff HEAD`（全部未 commit 的變更）
2. 分析哪些文件需要更新
3. 直接更新文件（留在工作區）
4. **不建立獨立的 docs commit**——文件變更會與 feature 一起 commit

```
git diff HEAD → 分析 → 更新文件 → 留在工作區
```

### Mode B — 工作區乾淨

**觸發時機**：工作區無任何變更（所有變更都已 commit）

**行為**：
1. 詢問要掃描幾個 commit（1-10，預設 1）
2. 掃描最近 N 個 commit 的 diff
3. 分析哪些文件需要更新
4. 更新文件並**留在工作區**，由用戶 review 後手動 commit

```
詢問 N → git diff HEAD~N HEAD → 分析 → 更新文件 → 留在工作區
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
/doc-updater          # → 詢問 N，掃描最近 1 個 commit，更新文件留在工作區
# review 後自行 commit
git add docs/ README.md AGENTS.md
git commit -m "docs: update documentation"
```

### 情境 3：補充多個 commit 的文件（Mode B）

```bash
# 你做了好幾個 commit 都沒更新文件
/doc-updater          # → 詢問 N，輸入 3，掃描最近 3 個 commits
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

A: `openspec-commit` 的文件更新依賴 OpenSpec change 的 proposal.md 和 specs 提供上下文，語意更豐富。`doc-updater` 只讀取 git diff，適用於沒有 OpenSpec change 的簡單 commit。

**Q: README.md 是繁體中文，doc-updater 會不會寫成英文？**

A: 不會。skill 指令中明確規定更新 README.md 時必須使用繁體中文。

---

## 相關檔案

- `.claude/agents/doc-updater.md` — Agent 定義
- `.claude/skills/doc-updater/SKILL.md` — Skill 定義
- `template/common/.claude/agents/doc-updater.md` — Template 來源（agent）
- `template/common/skills/doc-updater/SKILL.md` — Template 來源（skill）
- `git-commit-writer.md` — 相關工具說明
- `../workflow/commit.md` — OpenSpec commit 工作流程
