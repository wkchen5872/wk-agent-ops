## Why

目前由 `wk-agent-ops` 自行維護 `mutation-setup` 與 `mutation-check`，同時承擔工具安裝、mutation 執行、survivor 分診與流程政策，造成重複維護且只覆蓋 Python 與 JS/TS。改用 `testland/qa` 的語言 runner 與共用 survivor triage，可讓本 repo 專注於 OpenSpec/TDD 整合、安裝選擇、分數政策與安全邊界。

## What Changes

- **BREAKING**：移除自有 `mutation-setup` 與 `mutation-check` skill，不再將它們複製到目標專案。
- 依語言 profile 安裝一個 `testland/qa` mutation runner 與 `mutant-survival-triage`：Node 對應 Stryker、Python 對應 mutmut，並新增 JVM/PIT 與 .NET/Stryker.NET 對應。
- 以 project scope、主流 Provider（Claude Code、Codex、Antigravity）及連結模式作為自動安裝預設；無法自動安裝時顯示可重播的 `npx skills add` 指令，不改用 global install。
- 將 mutation testing 定義為 TDD 完成後的階段性品質審查：Red → Green → Refactor → Mutate → Triage；只有有效測試缺口才回到下一輪 TDD。
- 將 mutation score 政策改為 baseline、可比較範圍內不得下降、逐步提高門檻，並允許關鍵模組採較高門檻；無效或不可比較的 run 不得形成 gate。
- 更新 mutation playbook、managed agent protocol、架構與使用文件，並以本 change 的 `design.md` 保存完整設計與決策。

## Capabilities

### New Capabilities

- 無。

### Modified Capabilities

- `mutation-check`：由自有 setup/check skills 改為第三方語言 runner、共用 survivor triage 與本地政策協調。
- `install-profile-cli`：profile 安裝流程新增對應第三方 skills 的 project-local 自動安裝及失敗指令提示。
- `template-profile-structure`：語言 profiles 擴充為 Node、Python、JVM 與 .NET，且第三方 mutation skills 不納入自有 common template。
- `tdd-enforcement-rules`：加入五步閉環、survivor 回流規則、執行頻率與漸進式 mutation score policy。

## Impact

- 移除 `template/common/skills/mutation-setup/`、`template/common/skills/mutation-check/`，並精確清理 installer 曾產生的同名安裝目標。
- 修改 `scripts/skills/install.sh`、profile templates、相關 shell tests 與 OpenSpec canonical specs。
- 更新 `template/common/docs/agent-protocol.md`、`template/common/docs/mutation-testing.md`，再由 installer 同步 managed docs；同步調整 `docs/architecture.md`、`README.md` 與 `AGENTS.md` 中的責任邊界和使用說明。
- 新增執行期依賴：Node.js/npm 可執行 `npx skills add testland/qa`；mutation runner 本身的專案依賴與設定仍由第三方 skill 依目標專案情境處理。
