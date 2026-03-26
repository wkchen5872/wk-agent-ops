## Context

`wk-agent-ops` 是一個 agent operations 管理專案，提供可安裝到其他 repo 的 agent 擴充套件（skills、rules、commands、workflows）。

現行結構：
```
template/
├── skills/                         ← 複製到 .claude/skills/ 和 .agent/skills/
├── .claude/commands/opsx/
├── .claude/rules/
├── .agent/workflows/
└── .github/instructions/
```

`install.sh` 目前無條件 rsync 全部內容到目標專案，未來加入語言專屬內容後會產生污染問題。

## Goals / Non-Goals

**Goals:**
- `template/` 重組為 profile 結構（common / python / node）
- `install.sh` 支援 `bash install.sh [python] [node]` 介面
- 不指定 profile 時只裝 common
- 新增 `docs/template-profiles.md` 說明文件

**Non-Goals:**
- 不在此 change 中新增 Python / Node 的實際 rules 內容（那是後續 change）
- 不處理 commit-msg hook
- 不支援 profile 組合驗證或衝突偵測

## Decisions

### D1：profile 目錄直接放在 `template/` 下

```
template/
├── common/
│   ├── skills/
│   ├── .claude/
│   ├── .agent/
│   └── .github/
├── python/
│   ├── .claude/rules/
│   └── hooks/
│       └── pre-commit
└── node/
    ├── .claude/rules/
    └── hooks/
        └── pre-commit
```

**理由：** 結構直觀，與 install.sh 的 profile 參數一一對應，新增語言時只需加目錄。

### D2：install.sh 介面設計

```bash
bash install.sh              # common only
bash install.sh python       # common + python
bash install.sh node         # common + node
bash install.sh python node  # common + python + node
```

- profile 以位置參數傳入，支援多個
- common 永遠安裝，不需明確指定
- hooks 安裝到 `TARGET/.git/hooks/`，自動 chmod +x

### D3：skills/ 維持在 common/ 下

skills 屬於 agent workflow 工具，與程式語言無關，放 common。

### D4：hooks 放在各 profile 的 `hooks/` 子目錄

不放 `.git/hooks/`（因為是 template 來源），install.sh 負責複製並設定權限。目前只定義 `pre-commit`，`commit-msg` 留待後續。

### D5：同步更新此 repo 自身的 template 結構

`wk-agent-ops` 自己也使用 `template/` 下的 common 內容（`.claude/`、`.agent/`），重組後保持一致。

## Risks / Trade-offs

| 風險 | 應對 |
|------|------|
| 現有使用舊結構安裝的專案不受影響（install 是 rsync，不會自動移除舊檔） | 文件說明需手動清理舊路徑 |
| python / node profile 目錄目前是空的（rules 尚未撰寫） | 建立佔位 README，實際內容後續 change 補上 |
