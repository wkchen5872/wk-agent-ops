# openspec-commit 範例

這裡示範 SKILL 的 Stage outcomes 回報與成功交付 Closure 的寫法。PR 留言的格式以 managed
`docs/github-handoff.md` 第 6 節與第 6.7 節為準，本檔不另定格式。可重播的判定見
`acceptance-cases.md`。

案例中的 repo、編號、SHA、URL 與 Session 全部虛構；共同情境為 Change `add-export`、
分支 `feature/add-export`、PR #12、Issue #7。

## 本地完成，有 PR 但未授權交付

來源：使用者說「把 add-export 收尾」。PR #12 存在，但這次沒有提到 push 或 PR。

```text
✅ Feature committed

📦 Archive: openspec/changes/archive/2026-11-14-add-export
   Specs:   synced
   Warnings: None

📝 Docs:
   README.md

💾 Commit: c7 feat(add-export): add CSV export

🌐 Remote: pending — PR #12 exists; push, PR update, final review and Closure
   need their own authorization
```

## 成功交付的 Stage outcomes

來源：使用者授權發布到 PR #12，要求最終版本有 Review，再發結案摘要等待 merge。

```text
## Stage outcomes

| Stage | Result |
|---|---|
| archive | openspec/changes/archive/2026-11-14-add-export, synced, no warnings |
| docs | README.md |
| commit | c7 feat(add-export): add CSV export |
| push | remote head read back c7 |
| PR update | read back; describes c7 |
| final review | pass at c7 — https://github.com/acme/widgets/pull/12#issuecomment-50 |
| Closure | https://github.com/acme/widgets/pull/12#issuecomment-51 (read back) |
| close | not requested — success ends at ready-to-merge |

Not performed: merge, deployment, Issue #7 acceptance.
```

Closure 回覆（經 `github-pr reply` 發布並回讀）：

```markdown
## Handoff

- pull-request: https://github.com/acme/widgets/pull/12
- branch: feature/add-export
- issue: https://github.com/acme/widgets/issues/7
- openspec-change: add-export

## Closure

### Outcome
已發布並審查的最終版本為 `c7`，ready for an authorized merge；尚未合併。

### Delivered
完成 CSV 匯出，archive 與規格同步，README 更新。

### Verification
`c7` 的最終 Review 為 pass：https://github.com/acme/widgets/pull/12#issuecomment-50。

### Remaining work
原範圍內沒有未完成項目。Issue #7 的驗收與結案另行處理。

## Next actions

負責人依授權合併 PR #12，再核對 Issue #7 的完成條件。

## Author

Co-Authored-By: Claude Code
AI-Assisted-By: Claude Opus 5.5
SESSION-ID: sess-7781
XIRP-SESSION-ID: xirp-42
```

## commit 後 push 失敗，再接續

來源：第一輪 push 因認證失敗中斷；使用者修好後要求繼續。

第一輪：

```text
| commit | c7 feat(add-export): add CSV export |
| push | rejected — "Authentication failed"; remote head still c6 |
| PR update | not performed — waits for push |
| final review | not performed |
| Closure | not performed |
```

第二輪先以 `git log -1 --format=%H -- openspec/changes/archive/2026-11-14-add-export/`
確認 `c7`，不再 archive 或 commit：

```text
| archive | reused — committed in c7 |
| commit | existing commit reused (c7) |
| push | remote head read back c7 |
| PR update | read back; describes c7 |
```

## Closure 逾時

`github-pr reply` 逾時、沒有回傳 URL 時，先重新列出 PR 留言比對，再依結果分兩種：

確認沒有發布（confirmed not posted）——重新讀取 PR head 仍等於受審版本，以同一工具重試一次並回讀：

```text
| Closure | first reply timed out; re-read found no matching comment (confirmed not posted);
            retried once with the same tool — https://github.com/acme/widgets/pull/12#issuecomment-52 (read back) |
```

仍然無法判定（still unclear）——例如留言列表讀取失敗，或找到內容只部分相符的留言：

```text
| Closure | uncertain — reply timed out and the re-read is still unclear; not resent |
```

## 取消並關閉 PR

來源：使用者說「不做了，收尾後關掉 PR #12，理由是需求取消」。

```text
| commit | c7 chore(add-export): archive cancelled change |
| push | not performed — abandoned work is not published |
| close | delegated to github-pr close: Closure
          https://github.com/acme/widgets/pull/12#issuecomment-60 read back; PR CLOSED |

Unchanged: Issue #7, branch feature/add-export.
```
