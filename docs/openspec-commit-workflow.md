# /openspec-commit Workflow

`/openspec-commit` 是 `/opsx:apply` 之後、`wt-done` 之前的最後一個 Claude 操作，
負責將一個 feature 的開發收尾：archive → docs 更新 → git commit。

---

## 完整開發流程

```
Terminal                        Claude (in worktree)
─────────────────────────────────────────────────────────────────
wt-new <feature-name>
  ├── git checkout develop
  ├── git worktree add .worktrees/<name> -b feature/<name>
  └── cd .worktrees/<name> && claude ──────► /opsx:apply <name>
                                                    │
                                              實作 feature
                                            （改 src/、tests/…）
                                                    │
                                             /openspec-commit
                                            ┌───────┴────────┐
                                            │  ① archive     │
                                            │  ② docs 更新   │
                                            │  ③ git commit  │
                                            └───────┬────────┘
                                                    │
wt-done <feature-name>
  ├── git checkout develop
  ├── git merge feature/<name>
  ├── git worktree remove .worktrees/<name>
  └── git branch -d feature/<name>
```

---

## Skill 執行步驟

```
/openspec-commit 呼叫
        │
        ▼
① 找 active change
   ┌─────────────────────────────────────────┐
   │ openspec list --json                    │
   │  1 個  → 直接使用                       │
   │  多個  → AskUserQuestion 選擇           │
   │  0 個  → 警告，詢問是否只做 docs+commit │
   └─────────────────────────────────────────┘
        │
        ▼
② opsx:archive（完整流程）
   ┌─────────────────────────────────────────┐
   │ ● 檢查 artifact completion              │
   │ ● 檢查 tasks completion                 │
   │ ● sync 決策：                           │
   │     Sync now（建議）                    │
   │     Archive without syncing            │
   │ ● mv change → archive/YYYY-MM-DD-name/ │
   │ ← 等待完全結束才繼續 →                  │
   └─────────────────────────────────────────┘
        │
        ▼
③ 讀取 archived proposal + specs
   ┌─────────────────────────────────────────┐
   │ openspec/changes/archive/               │
   │   YYYY-MM-DD-<name>/                    │
   │     proposal.md   ← What Changes       │
   │     specs/**/*.md ← 能力範圍            │
   └─────────────────────────────────────────┘
        │
        ▼
④ 推斷並更新 docs/
   ┌─────────────────────────────────────────────────────────┐
   │ feature 影響              更新目標                       │
   │ ─────────────────────────────────────────────────────  │
   │ 資料來源（kgi/yuanta…）  docs/datasources/{source}.md  │
   │ init runner 異動          docs/datasources/init-runner.md│
   │ 架構分層異動              docs/architecture.md          │
   │ 新資料來源/重大功能        README.md（支援來源段落）      │
   │ 純 skill/工具             通常不需更新 README            │
   └─────────────────────────────────────────────────────────┘
   ● 顯示「即將更新的文件清單」讓使用者確認
   ● 只改相關 section，不重寫無關段落
        │
        ▼
⑤ git-commit-writer
   ┌─────────────────────────────────────────┐
   │ Conventional Commits 格式               │
   │                                         │
   │ 自動偵測 archive (git status):           │
   │   openspec/changes/archive/             │
   │   YYYY-MM-DD-<change-id>                │
   │                                         │
   │ type 推斷：                             │
   │   feat     新功能/新資料來源             │
   │   fix       修正錯誤行為                │
   │   docs      文件異動                    │
   │   refactor  重構（無行為改變）           │
   │   chore     工具/設定/維護              │
   │   test      新增/修正測試              │
   │                                         │
   │ Claude Code: Haiku subagent 執行        │
   │ 其他工具: 工具層 model 決定              │
   └─────────────────────────────────────────┘
        │
        ▼
⑥ 完成摘要
   ┌─────────────────────────────────────────┐
   │ Archive:  openspec/changes/archive/...  │
   │ Docs:     docs/<feature>.md（更新 X section） │
   │ Commit:   abc1234 feat: add feature…    │
   │                                         │
   │ 下一步：wt-done <feature-name>          │
   └─────────────────────────────────────────┘
```

---

## 設計決策

### 方案 A：`/openspec-commit` 包含 archive

選擇讓 `/openspec-commit` 作為唯一的收尾指令，內含完整 archive 流程。
使用者不需要分別執行 `/opsx:archive` 再 `/openspec-commit`。

`/opsx:archive` 本身保留，供只需要 archive 而不 commit 的場合使用。

### Sync 決策不阻斷流程

archive 過程中的 sync 決策（sync now / archive without syncing）無論使用者選哪個，
都算 archive 完成。`/openspec-commit` 在 archive **完全結束後**才繼續，不跳過 sync 流程。

### docs 更新只改相關 section

不重寫整份文件，只改 feature 直接影響的段落。
更新前顯示清單讓使用者確認，避免誤改。

### 兩份 Skill 檔案

```
skills/openspec-commit/SKILL.md      ← 專案原始檔（版本控制）
.claude/skills/openspec-commit/SKILL.md  ← 安裝位置（Claude Code 讀取）
```

更新 skill 時需同步兩個位置。

---

## 相關文件

- `scripts/worktree/wt-new.sh` — 建立 worktree
- `scripts/worktree/wt-done.sh` — 合併 worktree 回 develop
- `.claude/skills/openspec-commit/SKILL.md` — Skill 定義
- `.claude/skills/git-commit-writer/SKILL.md` — Commit 寫入 skill（可獨立呼叫）
- `openspec/changes/archive/` — 已封存的 change 目錄
