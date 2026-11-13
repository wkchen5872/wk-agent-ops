# github-pr 範例

範本與規則見 `docs/github-handoff.md` 第 6.2 節；完整的來源到內容案例見
`acceptance-cases.md` 的 GP-30–GP-32 與 GP-40–GP-41。這裡只示範 Handoff 與 Author 的
幾種寫法。編號與名稱都是虛構的。

## 剛建立時沒有任何關聯

只有已發布的分支與對話，Handoff 只有 `branch`，不寫空欄位：

```markdown
## Handoff

- branch: fix/refund-search
```

## 之後補上關聯與依賴

確認了直接處理的 Issue、對應的 Change，以及要等另一張 PR 合併：

```markdown
## Handoff

- branch: fix/refund-search
- openspec-change: refund-search-latency
- issue: https://github.com/acme/widgets/issues/44
- depends-on: https://github.com/acme/widgets/pull/12（合併後才能合併本 PR：需要它引入的 `index_one` 介面）
```

`issue` 是 close 時會一起關閉的工作；`depends-on` 只是依賴，必須寫出解除條件，不會被
關閉。只供參考的連結用 `references`。

## head 在 fork

```markdown
## Handoff

- branch: dev1:feature/add-export
```

## Author 的幾種情況

已知 runtime Session ID：

```markdown
## Author

Co-Authored-By: Claude Code
AI-Assisted-By: Claude Opus 5.5
SESSION-ID: sess-7781
```

使用者指定用管理器的 ID，且模型未知（省略 `AI-Assisted-By`，回報時說明）：

```markdown
## Author

Co-Authored-By: Codex
SESSION-ID: 3f9c-21 (xirp)
```

沒有可公開的 Session ID：

```markdown
## Author

Co-Authored-By: Claude Code
AI-Assisted-By: Claude Opus 5.5
SESSION-ID: null
```
