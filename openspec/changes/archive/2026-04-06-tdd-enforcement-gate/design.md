## Context

目前 wk-agent-ops 的 template 系統已有：
- `template/python/hooks/pre-commit`：完整的 pytest runner，已可安裝至 `.git/hooks/`
- `template/node/hooks/pre-commit`：placeholder，只輸出警告，不執行任何測試
- `scripts/skills/install.sh`：已支援 git hooks 安裝（`chmod +x`）
- `template/common/.claude/rules/`：現有 `multi-tool-compatibility.md`、`openspec-commits.md`
- `template/common/.github/instructions/`：同上兩個規則檔

缺少的是：
1. TDD 強制規則檔（Claude Code + Copilot CLI 皆可讀）
2. Node pre-commit hook 的實際實作
3. tasks.md 格式中的測試要求欄位

## Goals / Non-Goals

**Goals:**
- 讓 AI agents 在每個 session 自動看到 TDD 規則，不依賴任何 skill
- 讓 Python 和 Node 專案在 commit 時有輕量的測試關卡
- 讓規則與 hook 可透過現有 install.sh 複製到其他專案

**Non-Goals:**
- 不強制覆蓋率百分比（避免 gate 過嚴阻礙開發流程）
- 不修改第三方 skill（opsx:apply、opsx:verify 等）
- 不新增 CI/CD pipeline（本次範圍只到 local gate）
- 不支援 Gemini CLI / Codex（本次以 Claude Code + Copilot CLI 為主）

## Decisions

**決策 1：TDD 規則放 `.claude/rules/` 和 `.github/instructions/`，不修改 skill**

理由：rules/ 目錄的規則在每個 session 自動載入，不受 skill 版本影響；`.github/instructions/` 對 Copilot CLI 等效。修改第三方 skill 會在升級時遺失。

替代方案：修改 `opsx:apply` skill 的 TDD checklist → 排除，因為 opsx 是第三方 skill，升級會覆蓋修改。

**決策 2：Node pre-commit hook 使用 `npm test`，不指定具體框架**

理由：`npm test` 是 Node 生態的標準入口，jest 和 vitest 都透過 `package.json` 的 `scripts.test` 設定，hook 不需要知道具體框架。

替代方案：分別偵測 jest / vitest binary → 排除，過於複雜且不夠通用。

**決策 3：tasks.md 格式加入測試要求欄位（建議格式，非強制 schema）**

理由：在任務旁邊明確標注測試要求，讓 AI 在讀 tasks.md 時就能看到，不需另查 openspec/config.yaml。格式採建議而非 schema 強制，保持彈性。

**決策 4：不更新 install.sh**

理由：現有 install.sh 已支援 `template/<profile>/hooks/` → `.git/hooks/` 安裝，並已 `chmod +x`。只需確保 hook 檔案內容正確即可。

## Risks / Trade-offs

**[Risk] Python hook 在沒有 venv 的環境執行失敗** → 已處理：hook 有 fallback 到系統 `python3`

**[Risk] Node hook 在沒有 `npm test` script 的專案報錯** → Mitigation：hook 偵測 `package.json` 存在才執行，不存在則跳過

**[Risk] TDD 規則與現有 `openspec/config.yaml` 的規則重複** → Trade-off 接受：rules/ 的規則更精簡、更直接；config.yaml 的規則較完整但不一定被 AI 讀到

**[Risk] Copilot CLI 讀 `.github/instructions/` 的行為因版本而異** → Mitigation：兩個工具都寫相同內容，確保至少其中一個有效
