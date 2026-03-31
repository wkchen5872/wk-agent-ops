## Context

`hook.sh` 的 `stop|afteragent` 分支目前使用 `🟢 **TASK COMPLETE**` 作為標題。只需將字串改為 `🟢 **Task complete**`，不影響其他邏輯。

## Goals / Non-Goals

**Goals:**
- 將標題由 `TASK COMPLETE` 改為 `Task complete`

**Non-Goals:**
- 不更動任何其他欄位或邏輯

## Decisions

單一字串替換，無架構決策。

## Risks / Trade-offs

無。
