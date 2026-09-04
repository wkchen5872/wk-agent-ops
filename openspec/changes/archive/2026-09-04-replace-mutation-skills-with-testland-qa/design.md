## Context

目前 mutation testing 的工具設定、執行、結果解讀與流程政策都寫在 `wk-agent-ops` 自有的 `mutation-setup` / `mutation-check`。這使本 repo 必須追蹤各 runner 的 CLI 與報告格式，也把 mutation 執行能力和 OpenSpec/TDD 治理混在同一層。詳見 [proposal.md](./proposal.md)。

本設計改採第三方 [testland/qa](https://github.com/testland/qa) skills，但第三方內容不成為本 repo 的政策來源。`wk-agent-ops` 的 managed protocol 仍控制何時執行、哪些結果可形成 score verdict、survivor 如何回到 TDD，以及安裝與 Git 操作的安全邊界。

## Goals / Non-Goals

**Goals:**

- 每個語言 profile 只選一個 mutation runner，加上一個共用 survivor triage。
- 讓 common installer 自動完成 project-local、多 Provider、連結模式的 skill 安裝，失敗時提供可重播命令。
- 保存 Red → Green → Refactor → Mutate → Triage 的閉環，以及 survivor 類型到處理方式的唯一政策。
- 讓 mutation score 從 baseline 開始，只在相同量測口徑下做 no-regression 與後續 ratchet。
- 保留可回復的 migration，不靜默刪除既有 mutation 決策紀錄。

**Non-Goals:**

- 不 fork、vendoring 或修改 `testland/qa` 的 SKILL.md。
- 不建立新的 mutation wrapper skill、統一 runner CLI 或自有 survivor parser。
- 不在每次 Red/Green iteration 執行 mutation testing。
- 不以任意固定百分比（例如 80%）作為初始通用門檻。
- 不由 installer 安裝 mutmut、Stryker、PIT 或 Stryker.NET 的專案套件，也不修改目標專案 manifest、lockfile 或 runner 設定。

## Decisions

### 1. 三層責任架構

```text
OpenSpec scenarios / acceptance criteria
                  │
                  ▼
┌────────────────────────────────────────────┐
│ wk-agent-ops                               │
│ TDD loop、profile mapping、score policy、  │
│ 安裝安全邊界、執行頻率與文件               │
└───────────────────┬────────────────────────┘
                    │ selects / constrains
          ┌─────────┴─────────┐
          ▼                   ▼
┌───────────────────┐  ┌──────────────────────────┐
│ testland runner   │  │ mutant-survival-triage  │
│ 執行工具與產生報告 │  │ 分類 survivors 與建議處理 │
└───────────────────┘  └────────────┬─────────────┘
                                    │ valid test gap
                                    ▼
                              下一輪 TDD
```

`wk-agent-ops` 不再包裝第三方 runner；只負責選擇、政策與 handoff。這比維護另一組 setup/check wrapper 少一層同步成本，也避免把第三方工具細節複製回本 repo。

替代方案是保留 `mutation-check` 作為 facade。未採用，因為 facade 仍需追蹤四個 runner 的參數、狀態與報告格式，正是本次要移除的維護責任。

### 2. profile 到 skills 的固定對應

| Profile / language | Runner skill | Triage skill |
|---|---|---|
| `node` / JS、TS | `stryker-mutation` | `mutant-survival-triage` |
| `python` / Python | `mutmut-mutation` | `mutant-survival-triage` |
| `jvm` / Java、Kotlin | `pitest-mutation` | `mutant-survival-triage` |
| `dotnet` / .NET | `stryker-net-mutation` | `mutant-survival-triage` |

profile 是選擇來源；本次不再增加 manifest 自動偵測器。多 profile 安裝時，各 runner 安裝一次，triage 去重後只安裝一次。common-only 安裝不猜測語言，也不安裝 mutation skills。

替代方案是掃描 manifest 自動判斷語言。未採用，因為 monorepo、多語言 repo 與巢狀 project unit 需要額外歧義處理；既有 profile CLI 已提供明確輸入。

### 3. 自動安裝優先，命令提示作為降級

installer 對所選 profile 組成一個非互動命令：

```bash
npx skills add testland/qa \
  --skill <runner> \
  --skill mutant-survival-triage \
  --agent claude-code \
  --agent codex \
  --agent antigravity \
  --yes
```

命令在 target repository 執行，維持 skills CLI 的 project scope 預設；不傳 global 選項，也不傳 `--copy`，因此保留預設連結模式。多語言時在同一命令加入多個 runner `--skill`。

若缺少 `npx`、網路/registry/GitHub 失敗、upstream skill 不存在，或 CLI 結束碼非零，installer 不假裝成功，也不偷偷改用 global/copy 模式；它顯示同一條可重播命令與未安裝的 skill 清單，並以非零結束，避免目標專案處於「profile 已完成但 mutation 能力缺失」的半成功狀態。common profile 本身的檔案同步仍應保持冪等。

替代方案是只顯示命令。保留為 fallback，但不作為主路徑，因為使用者已選擇由 installer 安裝 profile。

### 4. 第三方 skill 受本地政策約束

managed protocol 明定：第三方 skill 的 runner-specific 指引可決定工具操作，但不得覆蓋目標 repo 的 package manager、lockfile、權限、Git 安全規則與「先顯示副作用、取得必要同意」政策。特別是不得因第三方範例而 blind global install、建立競爭 lockfile，或用破壞性 Git 命令清除使用者變更。

installer 只安裝 agent skills；runner 套件與設定由使用者稍後啟動對應 skill 時處理。這保留安裝 agent 能力與修改 application dependency 之間的 consent boundary。

### 5. 五步閉環與 survivor handoff

```text
[OpenSpec / SDD]
        │
        ▼
1. Red ──► 2. Green ──► 3. Refactor
                              │
                              ▼
                         4. Mutate
                              │
                              ▼
                         5. Triage
                              │
              ┌───────────────┴────────────────┐
              │ 有效測試缺口                   │ 不是測試缺口
              ▼                                ▼
       回到 Red 或 Refactor              記錄／清理／穩定化
```

OpenSpec scenario 先驅動日常 TDD。功能與一般測試全綠後，才在階段邊界執行 mutation runner；triage 不直接把每個 survivor 當成缺測試。

| Triage 類型 | 處理 |
|---|---|
| `missing-case` | 新增失敗測試，重新走 Red → Green → Refactor |
| `weak-assertion` | 強化既有 assertion；先取得能證明弱點的 Red evidence，不強制新增測試檔 |
| `equivalent-mutant` | 記錄可追溯理由，不新增無意義測試 |
| `unreachable` | 先證明不可達，再優先刪除死程式；不以「目前沒 coverage」直接推定 |
| `flaky-killer` | 將 mutation 結果標為不可靠，先修穩定性再重跑 |

### 6. 執行頻率與 scope

| 時機 | 一般測試 | Mutation testing |
|---|---|---|
| 每個小型 TDD iteration | focused test | 不執行 |
| 模組完成 | affected suite | 該模組 |
| Pull Request | required tests | changed files / runner incremental 能力 |
| 主分支排程 | full required checks | 完整 run |
| Release 前 | full required checks | 關鍵業務模組完整 run |

changed-files 或 incremental 的實際表達交由語言 runner skill。`wk-agent-ops` 只定義 scope intent，不重建各工具的 selection engine。

### 7. Mutation score 採 baseline 與可比較性門檻

score policy 分四階段：

1. 第一個有效 run 建立 baseline，不套用通用固定百分比。
2. CI 僅在可比較 run 上要求不得低於適用 baseline。
3. 團隊處理重要 survivors 後，明確更新 baseline 或 ratchet threshold。
4. 權限、交易、金額計算等關鍵模組可配置較高門檻。

兩個結果只有在 project unit、runner 與主要版本、mutation 設定、測試命令、mutator 集合、scope 和 exclusion policy 相容時才可比較。若任一條件不同、baseline tests 失敗、runner error，或報告不完整，結果標為 `inconclusive`，不得用來更新 baseline或做 score regression verdict。

runner 原生的 killed、survived、no coverage/untested、timeout、invalid/error、skipped 等狀態需保留。百分比只是摘要，不取代 triage；100% 也不代表未納入 scope 的程式已被驗證。

### 8. 第三方安裝狀態與既有 triage 紀錄分開處理

skills CLI 自己的 project-local metadata/lockfile 作為第三方 skill 來源與更新狀態，不另建一份 wk-agent-ops registry。既有 `openspec/.mutation-state` 或 `.mutation-state` 可能含人工 equivalent/deferred 理由；migration 不自動刪除，文件將其標為 legacy record，待使用者確認已轉存後再自行清理。

## TDD Strategy and Test Boundaries

本 change 的 installer 行為先以 shell acceptance test 建立 Red，至少覆蓋：

- 每個 profile 產生正確 runner + triage 組合。
- common-only 不呼叫 third-party installer。
- 多 profile runner 不重複，triage 只出現一次。
- 命令固定為 project scope、三個 Provider、預設 link mode，不含 global 或 copy fallback。
- 模擬成功、缺少 `npx` 與 command failure；失敗時輸出可重播命令並回傳非零。
- 精確移除四個 legacy generated skill 目錄，不碰其他第三方或使用者 skills。
- template source、managed docs 與安裝結果保持一致。

測試以 fake `npx` 放在暫存 PATH 中觀察 argv，不連真實網路，也不實際安裝 GitHub skills。OpenSpec verify 再檢查 delta spec、文件連結、shell syntax 與現有 installer regression suite。

## Risks / Trade-offs

- [上游 skill 名稱、CLI flags 或內容變更] → 以 project-local skills metadata 保留來源狀態；acceptance test 固定預期命令，升級時先 review upstream 再調整。
- [第三方指引和本地 package/Git 安全政策衝突] → managed protocol 明定本地政策優先；不修改 vendored skill。
- [.NET 報告是否完整符合共用 triage 的輸入期待仍需實測] → implementation 時以最小 fixture/範例報告做 acceptance check；不符合時安裝可保留，但文件標示限制，不自行新增 parser。
- [網路失敗造成 profile 安裝中止] → 顯示可重播命令與已完成項目；重跑必須冪等。
- [不同 scope 的 score 被誤比] → baseline metadata 必須滿足可比較條件，否則只報告 `inconclusive`。
- [移除 legacy skills 造成既有呼叫失效] → installer 精確清理並在文件提供新 skill 對應與 migration table。

## Migration Plan

1. 先新增/調整 acceptance tests，建立舊 installer 不會安裝第三方 skills 的 Red evidence。
2. 擴充 profiles 與 installer 的第三方 skill 安裝；以 fake `npx` 驗證，不碰真實目標專案依賴。
3. 移除 template source 中兩個 legacy skills，並由 installer 精確清理它曾產生的同名目標。
4. 更新 managed protocol、mutation playbook、architecture、README 與 AGENTS 說明，再重跑 installer 同步本 repo 的 generated targets/managed docs。
5. 驗證四種 profile、fallback、冪等性、文件與 OpenSpec specs。

Rollback 時回復本 change 的 commit 並重跑舊 installer，即可恢復 legacy skills。legacy mutation state 在 migration 中未自動刪除，因此 rollback 不需重建人工決策紀錄。

## References

- [testland/qa](https://github.com/testland/qa)
- [skills CLI](https://github.com/vercel-labs/skills)
- [StrykerJS incremental mode](https://stryker-mutator.io/docs/stryker-js/incremental/)
