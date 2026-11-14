# Tasks

## 1. 執行提示與本地證據

- [ ] 1.1 先擴充 `tests/test_change_review.sh` 與 acceptance cases，覆蓋 no-PR／unknown 的開始提示與報告去向，再補上 Skill 對應步驟。測試要求：記錄舊版本的有效 Red 及修改後 Green，提示不要求重複確認，也不把 PR 查詢失敗當成沒有 PR；同步本段 examples／checklists。
- [ ] 1.2 銜接既有 Work Item 紀錄規範，補齊本地報告保存、included／excluded 範圍、快照指紋與版本移動處理。測試要求：先取得相關期待的 Red，再重播 dirty checkout、untracked、既有／缺少 Work Item、其他 Agent 報告與中途修改；舊報告不覆寫、不跨 worktree 補回。

## 2. 明確授權的本機修正交接

- [ ] 2.1 新增並實作本地交接案例，保留預設無 PR 不通知與 PR 發布先行規則。測試要求：先 Red，再驗證使用者明確指定、報告保存成功、原實作者可核對才送出；未授權、local-only、代發者混淆、mapping 不符、PR 發布未確認時不送；實際與模擬送出分開記錄。

## 3. 延後發布與規則去重

- [ ] 3.1 補上後建 PR 的既有 reply 使用情境及版本比對，精簡重複格式文字但保留 workflow guard。測試要求：先 Red，再重播相同內容、新增差異、原快照不可得、歷史報告明確代發與後續複審；不自動建 PR／補貼，不以舊 pass 驗收新 head，Finding ID 與原作者保持。
- [ ] 3.2 更新 checklists、acceptance cases 與必要的 review-loop SVG／相關文件說明，對齊本地及 PR 分支。測試要求：逐案檢查既有三種 verdict、設計 review、正常複審與通知錯誤恢復不退化；改圖時做 XML、渲染及實際視覺檢查，確認名稱仍為 change-review。

## 4. 安裝與整合驗證

- [ ] 4.1 經 `scripts/skills/install.sh` 同步 template，在臨時 repo 驗證安裝與重裝。測試要求：來源與 managed 目標一致，reference 可達，不改 installer 範圍外配置或既有 Work Item；跑 `test_change_review.sh`、`test_github_handoff.sh` 與適用專案檢查。
- [ ] 4.2 執行本 Change strict validate、OpenSpec verify 及完整離線重播，保存正式驗證紀錄。測試要求：每項 requirement／scenario 有對應證據，清楚區分靜態、語意、installer、GitHub／Session 真實寫入；未測項明記，不宣稱已遠端驗收。

## Workflow follow-up

- 本次先由使用者檢查 proposal／design／specs／tasks。確認後另行依 github-issue 建立可讀 Issue，不因 FF 完成自動發布或 Apply。
- 適用的人類設計確認後才執行 openspec-apply-change；完成 Review 後再依授權封存與提交。
