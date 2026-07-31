## Context

目前同一能力分散在三個層次：

- `template/common/docs/agent-protocol.md` 是會由 installer 覆寫更新的 provider-neutral managed document，但 TDD 段落只有四步摘要。
- `template/common/.claude/rules/tdd-enforcement.md` 包含較完整且過度一致化的程序；installer 已把它原樣 mirror 到 `.agents/rules/`。
- `template/common/AGENTS.md` 是只在首次安裝時建立的 project-owned seed，負責要求 agent 讀取 managed protocol。

另有仍 active 的 `add-mutation-check` change，包含會重新加入強制 revert-check 與 Claude 路徑單一來源的 delta。若不先收斂，兩個 change 的 archive 順序會改變最終主規格。

## Goals / Non-Goals

**Goals:**

- 讓三個 Provider 取得同一份 TDD 行為契約，同時保留各 Provider 的原生載入入口。
- 讓 test-first 強度依行為與風險決定，並讓 Red 證據可用、最小且不洩漏敏感資訊。
- 以現有 installer、managed docs 與 shell tests 完成，不增加 runtime 或 dependency。
- 使仍 active 的 mutation change 與本 change 能以任意順序 archive 而不恢復舊政策。

**Non-Goals:**

- 不以 hook 或 transcript parser 嘗試機械化證明「測試一定先寫」。
- 不新增 `.codex/rules/`、Provider-specific 完整政策副本或新的 installer 分支。
- 不改 mutation-check skill 的執行流程、不新增 mutation score gate。
- 不替每種語言列出固定 test command。

## Decisions

### D1: Managed protocol 是規範來源，Provider rule 是薄入口

完整 policy 放在 `template/common/docs/agent-protocol.md`，因為 installer 會把它列為 managed doc 並更新既有專案。`template/common/AGENTS.md` 繼續作為 project-owned pointer；Claude rule 只要求讀取 protocol 的 task-scale、implementation 與 DoD 段落，installer 再把同一薄入口 mirror 給 Antigravity。

替代方案：

- 以 `.claude/rules/` 為單一來源：Codex 不會透過原生入口取得同等內容，拒絕。
- 在三個目錄維護完整副本：會產生 drift，拒絕。
- 把完整 policy inline 到 `AGENTS.md`：seed file 不會覆寫既有專案，無法傳播更新，拒絕。

### D2: 以行為類型決定 TDD，而不是一律依 task 套用

Level 1 收斂為文件、生成檔與不改變行為的設定同步；所有行為變更與 bug fix 進 Level 2 test-first。無法合理自動化時，要求在實作前定義可重播 acceptance evidence，而不是假裝已有 unit test。

### D3: Red 證據證明預期失敗，但只保留最小安全片段

有效 Red 同時包含 command、test 名稱、非零 exit code、預期原因與 sanitized excerpt。這能排除 syntax/setup failure，也避免「貼完整 raw output」造成噪音或洩漏路徑、資料與 secrets。Green 加入 test-integrity guard，只有 spec 或 acceptance criteria 確實錯誤時才可先修 artifact 再改測試。

### D4: 分層測試取代每 task 全量 suite 與固定 revert-check

- iteration：focused test
- task boundary：focused test + affected suite
- seal/commit：project-defined full required checks

可信 Red 已經提供因果證據，不再重跑 revert-check。只有 tests-after、高風險或因果不清時，才使用不會破壞 dirty worktree 的 safe causal check。Mutation testing 保持可選 audit，survivor 必須被報告但不阻擋完成或 commit。

### D5: 由本 change 收斂 active mutation delta

`add-mutation-check` 的 `tdd-enforcement-rules` delta 改為只描述 optional mutation audit；刪除 raw-output、固定 revert-check、`.claude` 單一來源與 Copilot removal 等由本 change 接管的 requirements。同步修正其 proposal、design 與已完成 task 描述，避免 artifacts 與最終 implementation 互相矛盾。

### D6: 沿用現有 installer，不新增 provider branch

目前 installer 已完成 managed protocol 更新、Claude rule 安裝及 Antigravity mirror；實作只需修改 source templates 並重跑 installer。Codex 由 `AGENTS.md` pointer 取得 policy，因此不需程式碼變更。

## TDD 策略與測試邊界

先擴充現有 shell tests，讓下列條件在 template 尚未修改前失敗：

- managed protocol 含適用範圍、有效 Red、test integrity、分層驗證與 conditional causal check。
- Claude rule 是指向 protocol 的薄入口，不再含「任何 task」、每 task 全量 suite 或固定 stash/comment revert。
- scratch install 後 Claude 與 Antigravity rule 相同，且 target `AGENTS.md` 指向 managed protocol。
- repository 不建立 `.codex/rules/`。

Markdown 對 agent 的語意服從無法由 shell test 完整證明；shell tests 只守護可機械驗證的載入路徑與最低政策 invariants，規格語意另以 OpenSpec strict validation 與人工 diff review 驗收。

## Risks / Trade-offs

- [薄入口要求 agent 再讀 managed doc，runtime 仍可能不服從] → `AGENTS.md` 與 native rule 雙入口都使用強制語句；最終 Green 仍由專案 test/CI gate 保證。
- [content grep 只能驗證字詞而非完整語意] → assertions 保持少量、只守護不可退化 invariants，避免把 prose 鎖死。
- [兩個 active changes 同時修改 capability] → 立即把 mutation delta 收斂為不重疊的 advisory requirement，並分別執行 strict validation。
- [Level 1 範圍縮小增加小型 bug fix 的成本] → 只對 observable behavior 套用 focused test，不要求每 iteration 全量 suite。

## Migration Plan

1. 新增並執行 failing shell assertions，保留預期 Red。
2. 更新 source templates 與 active mutation artifacts。
3. 執行 installer，把 managed protocol 與 rule 傳播至本 repository 的安裝目標。
4. 執行相關 shell tests、全部 `tests/*.sh` 與 OpenSpec strict validation。

若需 rollback，revert source template 與 artifact diff 後重跑 installer；不涉及資料遷移或外部狀態。
