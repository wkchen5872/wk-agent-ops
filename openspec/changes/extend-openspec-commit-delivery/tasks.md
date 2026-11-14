# Tasks

## 1. 本地完成與遠端意圖

- [ ] 1.1 擴充 `tests/test_openspec_commit.sh`，為本地預設、無 PR、unknown、遠端交付及 close 授權新增先行期待，建立 openspec-commit 的 acceptance references。測試要求：記錄有效 Red，再改 template 轉 Green；無 PR 可本地完成，未授權不 push／close，不自動建立 PR／Issue。
- [ ] 1.2 保留核心順序、exact archive context、隔離工作區 staging、provider routing 與 attribution，補上分階段結果說明。測試要求：既有 archive／docs 失敗、subagent 缺失、模型未知及 pre-commit retry 案例仍通過；混有其他工作時不將其提交。

## 2. 成功交付與放棄分流

- [ ] 2.1 整合已授權的正常 push、remote head 核對、github-pr update、最終版本 Review 與 reply Closure。測試要求：先 Red，再以本地 bare remote／離線案例驗證正確 host／head ref、push 被拒、head 移動、舊 pass 過時、未授權複審或 Review 未通過時停止；成功只交接待 merge，不 merge 或 close。
- [ ] 2.2 整合取消／被取代時的 github-pr close 委派與說明，不複製其 Closure 或錯誤恢復邏輯。測試要求：先 Red，再重播理由與授權缺失、取消不需 pass、已 merged／closed、摘要未確認、close 失敗；不推送放棄成果，不關聯動 Issue，不刪分支。

## 3. 部分完成與恢復

- [ ] 3.1 擴充 commit 已完成後的 archive／commit 證據解析與遠端進度恢復，不新增持久狀態 registry。測試要求：先 Red，再驗證 commit 後 push 失敗、push 後 update 失敗、Closure 後 close 失敗、timeout、多候選及缺少證據；只補缺少且已授權的操作，不重做 archive／commit／已確認摘要。
- [ ] 3.2 同步 SKILL 的 error handling／reporting 與完整來源到輸出範例，保持薄入口只委派一次。測試要求：每段成功／失敗／不明各自回報，既有入口及 root attribution 測試仍通過，未發生的 merge／部署／Issue 驗收不寫成完成。

## 4. 已確認流程的正式文件

- [ ] 4.1 依 `references/confirmed-workflows.md` 與本 Change 的設計，將四張已確認圖及說明落到 `docs/workflow/local-development.md`、`docs/diagrams/` 的獨立 SVG／PNG，更新受影響索引。測試要求：在沒有 Work Item 的臨時 checkout 核對全部連結、人工發布檢核與成功／取消分流；不新增前兩階段 Skills，不將個人選擇寫入全域 managed protocol；SVG 實際渲染並逐張視覺檢查。

## 5. 安裝與整合驗證

- [ ] 5.1 經 `scripts/skills/install.sh` 同步 template，並驗證臨時 repo 安裝／重裝。測試要求：來源與安裝副本及 references 一致、第三方及 installer 範圍外配置保留，既有 Work Item 不刪除；跑 openspec-commit、github-handoff、github-pr-publication 與文件相關 suites。
- [ ] 5.2 執行 strict validate、適用 OpenSpec verify、完整交付／恢復語意重播與專案必要檢查，保存正式驗證證據。測試要求：分開標示靜態、installer、本地 Git remote、模擬 gh／MCP／Session 與真實寫入；所有未執行遠端檢查如實記錄，不依本機通過宣稱真實交付成功。

## Workflow follow-up

- 先由使用者檢查本地 proposal／design／specs／tasks。確認後依 github-issue 建立獨立 Issue；不自動發 PR。
- 適用的人類設計確認後再 Apply，實作驗收後才依授權封存、commit 或遠端交付。本 Change 的規劃建立不啟動這些動作。
