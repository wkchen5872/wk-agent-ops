## Context

目前 `openspec-commit` skill 是三合一流程（archive → docs → commit），全部跑在主 model（Sonnet）上。git commit 格式化是機械化工作，適合在更便宜的 model 上執行。

現有 skill 架構：每個 skill 部署至三個位置（`template/common/skills/`、`.claude/skills/`、`.agent/skills/`），各工具讀取自己的位置。

## Goals / Non-Goals

**Goals:**
- 建立可獨立呼叫的 `git-commit-writer` skill
- 支援有/無 openspec change 兩種情境（scope 規則不同）
- 在 Claude Code 中透過 `Agent(model="haiku")` 執行以節省成本
- Copilot CLI / Antigravity 透過工具層 model 設定獲得同等效果

**Non-Goals:**
- docs 更新自動化（另立 change 處理）
- 修改 `openspec-commit` 的 archive 流程
- 支援互動式 commit 編輯（設計上不需要確認）

## Decisions

**Skill 作為定義層，Agent dispatch 作為 CC 的執行最佳化**
- Skill markdown 是 model-agnostic 的指令集，任何工具都能讀取執行
- Claude Code 額外在 `openspec-commit` Step 5 加入 `Agent(model="haiku")` dispatch，讓 commit 步驟跑在 Haiku 上
- 替代方案：只做 Haiku subagent，不建立 skill → 捨棄，因為無法跨工具使用

**Scope 規則：有 change 才加 scope**
- 有 openspec active/archive context → `feat(<change-id>): subject`
- 無 openspec context → `feat: subject`
- 替代方案：永遠加 scope → 捨棄，因為非 openspec 的 commit 沒有 change-id

**直接執行，不需要確認**
- git commit 是最終動作，確認由使用者在呼叫前判斷
- 替代方案：顯示訊息等確認 → 捨棄，增加摩擦、破壞 background 執行場景

## Risks / Trade-offs

- Haiku 品質 vs Sonnet：commit 訊息可能較不精準 → 使用者可 `git commit --amend` 修正
- 三個位置需手動同步：template 改完需複製到 `.claude/` 和 `.agent/` → 可接受，現有所有 skill 都這樣
