---
type: Reference
title: GitHub Copilot CLI Hook Integration
description: Repository-local Copilot CLI hooks installed or offered by wk-agent-ops.
tags: [hooks, github-copilot, workflow, notifications]
timestamp: 2026-08-01T00:00:00+08:00
---

# GitHub Copilot CLI Hook Integration

Copilot CLI hooks 是 repository-local 設定；與 Claude、Codex 的 user-level 設定
不同，這些檔案可能會被提交並由團隊共用。

## 本專案使用的設定

| 功能 | 設定檔 | 事件 | 安裝方式 |
|---|---|---|---|
| OpenSpec branch compatibility | `.github/hooks/openspec-branch-creator.json` | `postToolUse` | `scripts/workflow/install.sh` |
| Entropy counter | `.github/hooks/entropy-counter.json` | `postToolUse` | `scripts/workflow/install.sh` |
| Telegram notifications | `.github/hooks/hooks.json` | `sessionEnd`, `userPromptSubmitted` | Telegram installer opt-in |

Workflow installer 會直接維護兩個單一用途的 hook files。Telegram hooks 則是
opt-in，因為 `.github/hooks/hooks.json` 是專案狀態，可能影響其他協作者。

```bash
bash scripts/notify/telegram/update.sh copilot-hooks
```

OpenSpec compatibility hook 只觀察成功的 `openspec new change <change-id>`，並委派
給 `opsx-branch`；它不取代 Agent-mediated branch guard。

## 相關文件

- [Provider hook 總覽](/docs/hooks/index.md)
- [Telegram Notify](/docs/notify/telegram.md)
- [Workflow scripts](/scripts/workflow/README.md)
