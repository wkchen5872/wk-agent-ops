# Proposal

## Why

人類與 Agent 共同開發時，團隊需要從 Issue／PR 直接理解工作、驗證、下一步與內容來源。目前 Issue 缺少 Session 追蹤與結案入口，PR 參考範例偏重欄位片段，交接與結案也缺少統一摘要，造成不同操作的內容及責任不一致。

## What Changes

- 將團隊發布格式集中於共用交接契約，Issue／PR Skills 負責整理內容及原生 gh／MCP 操作，個人 OpenSpec 流程封裝另行規劃。
- 統一 Handoff、依用途撰寫的正文、Next actions、Author。保留已確認的 Change、branch、Issue／PR 關聯，Work Item 標為 local-only，未知的選用關聯省略，舊 null 欄位仍可讀。
- **BREAKING** Issue 的 Agent Author 加入原生與 Xirp Session ID，與 PR／回覆共用人類、Agent 工具及已知模型的追蹤語意。代發的原內容作者與發布者分開標示。
- 增加交接 Checkpoint 的內容規則，涵蓋目前狀態、已確認結果／決策、未決事項、版本／證據及下一步。以既有 update／reply 發布，日常更新保留精簡差異。
- **BREAKING** 新增 Issue close，PR close 預設只處理指定 PR。結案先發布 Closure 摘要，再執行已授權的狀態操作並回讀，部分失敗與重試沿用既有查核要求。
- 遠端 Review 在已授權的範圍內，發布 pass、changes-required、blocked 三種版本綁定結果，修正回覆逐項對應 Finding。
- 更新 Skills 的 references/examples.md、acceptance-cases.md、共用文件與受影響測試，使完整建立、更新、Review、修正、Checkpoint 與結案案例符合本次格式。

驗收重點為接手者能從已發布內容定位工作、受審版本、實際結果、下一步及本輪來源。人工與 Agent 範例均清楚，格式不捏造未知資訊，結案不越權操作其他工作。離線測試與案例重播須分開報告，真實 GitHub 寫入另記實證。

## Capabilities

### New Capabilities

本次延伸既有能力。

### Modified Capabilities

- `github-change-handoff`: 共用格式、追蹤資訊、Checkpoint、結案語意及舊契約一致性。
- `github-issue`: 建立與追加更新的內容標準、Session 追蹤、工作識別及獨立 close。
- `github-pr`: 正文、回覆與 Closure 範本，以及 PR close 的單一目標範圍。
- `change-review`: 遠端 pass 發布、Next actions 與本輪作者追蹤。

## Impact

主要來源為 `template/common/docs/github-handoff.md`、其既有圖稿、`template/common/skills/github-issue/`、`github-pr/`、`change-review/` 及相關入口說明。後續實作透過 `scripts/skills/install.sh` 同步至 Claude Code、Codex 可讀的共用 Skills、Antigravity 與 managed 文件。

受影響檢查包含 `tests/test_github_handoff.sh`、`tests/test_change_review.sh`、`tests/test_github_pr_publication.sh` 及引用舊格式／結案語意的案例。使用既有 Git、gh 或 MCP，無新增依賴。Projects、排程、自動派工、個人四階段封裝與新增 merge 操作不在本次範圍。現有 scoped commit／正常 push、安全核對與批准規則繼續作為操作基礎。
