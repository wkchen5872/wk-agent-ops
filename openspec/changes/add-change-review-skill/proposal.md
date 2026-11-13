# Proposal

## Why

每次啟動 Reviewer 都要重新交代 Change、PR、審查階段、回報格式與修正通知對象，容易漏掉版本或把設計審查當成實作驗收。需要一個以 PR 為入口的輕量 Review Skill，保留現有 verify／品質審查能力與 Session 通知方式，讓報告及修正複審可被其他 Agent 接手。

## What Changes

- 新增跨工具 `change-review` Skill，接受 PR URL、design／implementation 階段，以及可選的 expected-head、上一輪報告與通知目標；第一版不另建專用 Agent 配置。
- 依 PR／Issue 找到正確 Change、base／head、正式 artifacts 與測試環境。無法取得必要版本或有歧義時不猜測、不錯版通過。
- design 檢查規格、風險與驗收可行性；implementation 以 Skill 自帶的規格／相連程式／測試檢查為基線，組合當時可用的 OpenSpec verification 及品質 Review，不因設計尚未實作就用完整性標準否決設計。`ponytail-review` 是可選加強，缺席不免除基線審查，也不單獨阻塞。
- 使用 `add-github-change-handoff` 的共用格式、provenance、目標／操作檢查及正文 ownership 規則；以當前可用且已配置的 gh 或 GitHub MCP 讀取 PR、發布 Review／留言與回覆，也不調用可能 commit／push 的 PR 建立／發布路徑。
- 保留穩定 Findings、版本與證據。報告先發布，再通知原實作者；實作者讀 PR、修正測試並發布版本、逐項回覆，再通知 Reviewer 複審。找不到原 Session 時可交由新 Agent 接手。
- 每次呼叫完成一輪審查與交接，明確回傳 pass、changes-required 或 blocked；必要證據不足不寫 pass，純風格或範圍外建議不阻塞，反覆無新證據時轉人處理。

驗收需涵蓋 expected-head、防止 Skill 來源與待審版本混用、上游批准欄位精度及記錄者授權、發布回讀不符，以及 design／implementation 分流、版本移動、真正的修正複驗、未執行檢查、等待真實資料、同 GitHub 帳號的報告形式，以及通知失敗／原 Session 消失後接手。Skill 不得修改被審查產品程式或暗中 commit／push。

## Capabilities

### New Capabilities

- `change-review`: 具名且綁版本的兩階段 Review、原生報告發布、修正通知、複審及無進展停止條件。

### Modified Capabilities

無。共用格式與 Work Item 遠端交接邊界由相依的 `add-github-change-handoff` 修改，本 Change 不重複定義。

## Impact

- 新增 `template/common/skills/change-review/SKILL.md` 與必要的審查案例／階段檢查清單，沿用既有 installer 同步至 Claude Code、Codex、Antigravity。
- 更新必要的 README 與共用交接文件入口；報告 schema 仍由前一 Change 持有，Review 專用檢查不散入另一套 metadata 文件。
- 補入契約／安裝檢查及有正式證據落點的人工情境重播；沿用上游共用案例格式，不新增 Agent harness。真實 PR 發報告、帳號與通知驗收須明確指定測試對象，沒有實測不聲稱端到端通過。
- 整合前提是 `add-github-change-handoff` 的共用契約與入口已有可取得的明確版本，不要求其最終 implementation Review 先通過。本 Skill 可用 PR #2 的待複審版本作實際驗收案例；上游仍保留待複審狀態，Skill 本身另需驗收，不能由自己的報告宣稱兩個 Change 同時通過。
- 執行環境需要至少一個具備所需能力的 gh 或 GitHub MCP。認證由工具管理，無強制 identity script／blob 前提；明示帳號限制才核對，能力不足或操作拒絕如實回報，不用另一工具的登入替當前連線背書。
- 不修改第三方 OpenSpec／Ponytail Skill，不新增通知器、常駐輪詢、多機啟動器、自動修復／合併或無上限 Review 迴圈。
