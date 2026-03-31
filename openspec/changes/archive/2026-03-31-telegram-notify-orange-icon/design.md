## Context

`hook.sh` 的 `notification` 分支目前組裝訊息時使用 `🔴 **Action Required**` 作為標題。只需將該 emoji 替換為 🟠，不影響其他任何邏輯。

## Goals / Non-Goals

**Goals:**
- 將 Action Required 標題中的 🔴 替換為 🟠

**Non-Goals:**
- 不更動訊息結構、欄位順序、fallback 文案或任何其他邏輯

## Decisions

單一字元替換，無架構決策。

## Risks / Trade-offs

無。
