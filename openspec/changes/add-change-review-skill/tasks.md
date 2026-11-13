# Tasks

本清單只追蹤實作／驗證。實作前取得設計的人類審閱，並確認上游 `add-github-change-handoff` 契約與入口的明確版本已交付可取得；不要求上游先通過延後由本 Skill 承接的最終複審。兩個 Change 的驗收分開記錄。情境驗證依上游共同人工方法，案例放 `template/common/skills/change-review/references/acceptance-cases.md`，去敏執行證據放專案 `docs/verification/change-review/<run-id>.md`，不新增 harness 或只存在 WI 的測試結果。

## 1. 審查入口與版本固定

- [ ] 1.1 先依共用格式保存固定案例、模擬工具回覆、預期決策／擬議呼叫與禁止行為，再新增 `template/common/skills/change-review/SKILL.md` 的 PR／phase 入口與版本檢查。測試要求：正常 Agent Session 人工比對未指定階段、多 Change 未選目標／已選目標但另一 Change 尚未實作、expected-head 不符、錯版／dirty、head 移動、缺 artifacts、候選 head 修改明示帳號限制的案例；記實際模型／工具與證據，不能 commit、丟棄他人工作或把模擬當真實操作。
- [ ] 1.2 加入共用契約／provenance 引用與獨立首輪、複審上下文分流。測試要求：契約已 archive 後仍可從已安裝文件取得；首輪不借用其他 Reviewer 未確認結論，複審正確引用原 Findings；不另維護第二套 metadata schema。記實際使用的共用契約與受測 Skill 來源 revision／未提交來源指紋，與目標 reviewed head 分開；上游未完成最終 Review 不形成啟動本 Change 的循環前提。
- [ ] 1.3 依上游範本輸出三個明確章節，填寫 Scope and Baseline 的 Session 與 Git 資訊，不另定 schema。測試要求：以使用者指定的本地 Review 形狀作結構參考，人工重播原生 ID 已知／未知／withheld、使用者提供 ID、錯版 checkout、未提交與未版本化文件，檢查來源標記、alias 分離及各版本證據一致。補 approved_by 純人類 GitHub 帳號、approved_at 日期已知保留 YYYY-MM-DD／完全未知 null、不得補造午夜或借 recorded_at 的案例，只引用上游 schema。
- [ ] 1.4 引用上游原生工具的目標／operation／可得權限與回讀規則，使用可用 gh 或 MCP，不依賴 identity script／blob。測試要求：先保存 gh 缺少但 MCP 可用、另一連線登入不能代證、可讀不可寫、權限 metadata 不完整、無帳號限制可工作、明示限制衝突則停止的案例；認證交工具管理，不另建 parser／adapter。

## 2. 階段檢查與 Findings

- [ ] 2.1 實作 design 檢查清單與結果界線，文件附規格缺口及等待資料的例子。測試要求：spec-only PR 不因未完成實作任務失敗；缺驗收標準能指出具體 requirement；design pass 不代表人類批准或測試已執行；缺少記錄者獨立授權只代表不能依該代記 Apply，不阻止唯讀審查或已授權技術報告發布。先保存預期失敗與通過案例，再檢查實際 Agent 回報。
- [ ] 2.2 實作 implementation 自帶的規格／相連程式／測試基線，組合當時可用的 verification 與可選品質 Review，保留原方法限制。測試要求：人工重播缺 ponytail-review 仍完成基線、缺 OpenSpec verify 入口時如實逐條對照、安全／Bug 缺陷、caller 回歸、缺必要環境、等資料及可重用證據；可選擴充缺席不單獨 blocked，必要證據缺漏不得 pass。
- [ ] 2.3 加入跨輪 Findings 的穩定來源 ID、狀態與複驗規則。測試要求：不同 Reviewer 的 F-01 不衝突，實作者自稱修復不會直接變 Resolved；提供反證可有理由 Rejected，修復及受影響檢查都有證據才 Resolved。

## 3. 報告發布與修正交接

- [ ] 3.1 用選定 gh 或 MCP 讀 PR／發布三種結論，預設 COMMENT 綁 reviewed commit，能力不足時可用同樣獲授權的版本化一般留言。測試要求：重播同帳號、blocked 仍發布、原生 Review 不可用、權限拒絕、明示帳號限制、timeout 後跨通道先 reconciliation；不走 create／publish／commit／push，不以留言繞過限制，工具回成功後回讀目標、Review-ID、phase、head 與正文；不符或回讀失敗記「可能已發布／尚未確認」，不冒稱交接完成、不盲目重送。
- [ ] 3.2 實作預設可轉交訊息與可選的已驗證 Session 定向工具，保留報告先發布、實作者逐項回覆／新 head、再交 Reviewer 的順序。測試要求：訊息含 PR／已核對報告 URL、head、Finding IDs；核對通知工具所用管理 Session ID 與原生 Session ID 的差別，不互換；重播無 Session 工具、原 Session 消失、新 Agent 接手及直接通知失敗，沒有工具時只記待人工轉交，不冒稱 Telegram／人員提示可定向 Session。
- [ ] 3.3 實作單輪結束與複審入口，保留歷史結論且檢查新 head 的受影響行為。測試要求：人工重播未修完、引入回歸、同爭議無新證據、archive／doc 提交後的最終差異與通過；僅有證據為純交付整理才縮小範圍，不能把先前 pass 套到新 head，無進展 blocked，不常駐或擴需求。

## 4. 安裝與操作文件

- [ ] 4.1 更新 README／共用交接文件的 Review 操作入口，提供 Claude Code、Codex、Antigravity 呼叫與工具限制說明，沿用 installer 安裝。測試要求：以暫存 target 驗證 Skill／引用送達、重裝一致、第三方 Skills 不被改寫；靜態 contract 只回報文件送達，不冒稱 runtime 行為。
- [ ] 4.2 將修正複審 SVG 放在 `template/common/skills/change-review/references/review-loop.svg`，與案例一併由 Skill 引用，再以 installer 安裝本 repo。測試要求：暫存 target 的第二次安裝更新案例和 SVG，來源／副本一致、blocked 與 pass 都經發布報告後分流，另做 XML／渲染與連結檢查；無法啟動的 provider 明列未測。

## 5. 整體 Review 往返驗收

- [ ] 5.1 第一個真實 implementation 整合案例使用 PR https://github.com/wkchen5872/wk-agent-ops/pull/2、Change add-github-change-handoff、expected-head dee0855d1bdb026ef238b64374f80ea8275346d7；執行前核對實際 head，不符不默默換版。分開記受測 Skill 來源與目標 checkout，實際檢查上游並依既有授權發布／回讀及交接，結果由證據決定，不預設 pass。design 及 changes-required→修正回覆→新 head 複審先以固定案例覆蓋；真實失敗往返只用既有實質 Finding 或另經授權可丟棄 PR，不製造正式缺陷。保存工具／版本、可得 actor、報告 URL／內容、SHA、通知結果與無 WI 接手證據；原 10 支測試是使用者回報，未自行執行就明記來源。未測通道／真實往返如實列限制，不以一張上游報告自證本 Skill 已驗收。
- [ ] 5.2 執行受影響 contract／安裝測試、必要專案檢查、`openspec validate add-change-review-skill --strict`、`git diff --check` 及文件檢查。測試要求：正式 run 採上游 OKF Reference／必要 metadata／sources，保留歷史結果；明列各工具 runtime、跨機器、真實資料與 required-review 是否實測，不誤報交付。

## Workflow follow-up

- 是否建立 provider-native Review Agent 由後續具體需要決定，本 Change 不包含 Agent runtime 配置。
- Archive、commit、push、merge 與部署按當次授權處理；不得因 Review pass 自動執行。
