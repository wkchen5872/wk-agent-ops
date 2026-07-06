# tooling-target-scope Specification

## Purpose

Define the supported AI tooling scope for this project and its `template/` deliverables:
only Claude Code and Antigravity are supported targets. Rules, docs, skills, and install
scripts must not retain detection, configuration, or documentation for deactivated tools
(GitHub Copilot, Codex, Gemini CLI), and the installer must deliver rules to both Claude
Code and Antigravity paths.

## Requirements

### Requirement: 工具範圍限定 Claude Code 與 Antigravity

本專案與其 `template/` 出貨物 SHALL 只支援 Claude Code 與 Antigravity。Rules、docs、skills、install 腳本 MUST NOT 殘留 GitHub Copilot、Codex 或 Gemini CLI 的偵測、設定或說明（如 `GEMINI_PROJECT_DIR` 偵測、`.github/instructions/` Copilot 鏡像、Copilot/Codex/Gemini CLI 字樣）。

#### Scenario: 規則不再提及已停用工具
- **WHEN** 搜尋 `template/` 與專案根的 rules / AGENTS.md / skills
- **THEN** 不出現 `GEMINI_PROJECT_DIR`、Gemini CLI、Copilot、Codex 作為支援目標（git-commit-writer「印出自己模型名」的自我標記設計除外，且不含特定第三方工具假設）

#### Scenario: 移除 Copilot 鏡像
- **WHEN** 安裝任一 profile
- **THEN** 不產生 `.github/instructions/`，install 腳本亦無對應 sync 步驟

### Requirement: Rules 必須同時送達 Claude Code 與 Antigravity

`install.sh` SHALL 把安裝的規則檔同時放到 Claude Code 路徑（`.claude/rules/`）與扁平的
`.agents/rules/*.md`（複數 `.agents`，即較多 AGENTS.md-aware 工具讀取的目錄）。Workflows MUST
確實複製到 `.agents/workflows/`，不得因 `.agent`/`.agents` 命名不一致而成為 no-op。所有安裝路徑
一律使用複數 `.agents/`。

#### Scenario: 安裝後其他工具讀得到規則
- **WHEN** 在目標專案執行 `install.sh python`
- **THEN** `.agents/rules/` 內有扁平的規則 markdown（含 common 與 python profile 的規則），且 `.claude/rules/` 也有同一批規則
- **AND** 不產生任何單數 `.agent/` 目錄

#### Scenario: workflows 真正落地
- **WHEN** 安裝 common
- **THEN** `template` 內的 `.agents/workflows/*.md` 被複製到目標 `.agents/workflows/`（非空、非 no-op）
