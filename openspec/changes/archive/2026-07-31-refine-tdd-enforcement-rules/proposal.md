## Why

現行 TDD rule 把所有 task 一律套用完整 Red/Green/Refactor、每 task 全量測試與強制 revert-check，與 portable agent protocol 對 Level 1 小型工作的豁免互相衝突，也讓程序證據比測試是否守護可觀察行為更受重視。規則同時以 Claude 專用路徑作為單一來源，導致 Codex 只能讀到較弱的共用流程，三個 Provider 的實際要求不一致。

## What Changes

- 將 managed `docs/agent-protocol.md` 的 TDD policy 設為 provider-neutral 單一規範；`AGENTS.md`、Claude rule 與 Antigravity mirror 都只負責載入或指向它。
- 將正式 test-first 流程限定於 Level 2 行為變更與 bug fix；純文件、生成檔、設定同步及探索性工作改用與風險相稱的替代驗證。
- Red 證據改為「失敗測試、非零 exit code、預期失敗原因與經清理的最小輸出」，不得用 setup/syntax error 或未清理的完整輸出充數。
- 明定不得藉由弱化、跳過或刪除需求測試取得 Green，並採 focused test → affected suite → seal 時完整 required checks 的分層驗證。
- 只有在缺少可信 Red、高風險或測試因果關係不清時才執行 revert-check；mutation testing 維持 optional/advisory，不成為完成或 commit gate。
- 沿用 installer 現有 `.claude/rules/` → `.agents/rules/` mirror，不新增 `.codex/rules/` 或第三份完整規則。
- 收斂仍 active 的 `add-mutation-check` TDD delta，只保留 mutation audit 本身，避免日後 archive 重新引入舊政策。

## Capabilities

### New Capabilities

<!-- None. -->

### Modified Capabilities

- `tdd-enforcement-rules`: 調整 TDD 適用範圍、證據品質、分層驗證、conditional causal checks，以及 Claude/Codex/Antigravity 的共用載入架構。

## Impact

- Source templates：`template/common/docs/agent-protocol.md`、`template/common/.claude/rules/tdd-enforcement.md`
- 安裝結果：`docs/agent-protocol.md`、`.claude/rules/tdd-enforcement.md`、`.agents/rules/tdd-enforcement.md`
- 驗證：擴充現有 shell tests，確認 portable policy、薄入口與 installer mirror
- OpenSpec：更新 `tdd-enforcement-rules` delta，並清理 `add-mutation-check` 中已被本 change 取代的 TDD requirements
- 不新增 dependency、不修改 installer 複製邏輯、不新增 Codex 專用 rules 目錄
