# Tasks

本清單只追蹤實作與驗證。開始前須取得本 Change 設計的人類審閱；建立 artifacts 不等於批准實作。第一版 GitHub 操作統一 gh，Git commit／push 使用 git；帳號腳本與 installer 用測試先行，Skill 指令採 design 的人工重播方法。純文字 contract 不能冒充操作驗收，去敏正式證據落在專案 `docs/verification/github-handoff/<run-id>.md`。

驗證證據：[2026-11-13-apply-r01](../../../docs/verification/github-handoff/2026-11-13-apply-r01.md)。重播案例由 Agent 子 Session 執行、實作 Session 比對，尚無人類比對；5.1 未執行，5.2 的檢查已在目前工作區通過，待 5.1 之後重跑並交付 Review。

## 1. 共用契約與正式交接邊界

- [x] 1.1 在共用契約定義範本／遠端 schema、IDs、provenance 預設、design-approval、可信政策及認證證據表，並定義共同人工案例與正式證據格式。測試要求：先保存 fixture／模擬回覆／預期及禁止呼叫；案例驗證已授權具名代記跨機器可用、實際 comment author 不符／Agent 自行宣告不能批准、superseded、候選 PR 改政策、SSH exit 1、HTTPS 證據缺漏、原生 Session 預設保留與未知／withheld；逐案比對，不輸出秘密。
- [x] 1.2 局部更新 Work Item Review 邊界及 managed protocol／OpenSpec workflow，新增 `template/common/.claude/rules/github-handoff.md` 薄指標，要求本流程寫入前按操作跑共用 preflight，第一版不加 hook。測試要求：擴充 Work Item／入口 contract，證明本地模式有效、WI 不進 Git或同步、無 WI 可接手，rule mirror 與 Codex protocol 鏈可達；不以 rule 文件存在宣稱 runtime 全面攔截，規範修改前記錄預期失敗。
- [x] 1.3 在共用契約落實 Work Item Review 章節與完整 Scope and Baseline，明列 Session-ID／source／alias、工具／模型、Git 分支／比較 base／reviewed head／checkout HEAD、未提交內容、快照與實際檢查。測試要求：人工案例與 contract 覆蓋已知原生 ID、user-provided、未知／withheld、alias 不冒充原生 ID、未版本化文件、detached checkout、base／head 不同與未提交內容；不能填造 SHA 或將錯版檢查當 pass。
- [x] 1.4 先寫 `tests/test_github_identity.sh` 的 PATH stub 行為測試，再實作唯一腳本與可信版本取得流程，支援 api／commit／push 與預期值／policy_source。測試要求：Red 後驗證來源 blob／普通檔案類型、候選腳本被替換仍只執行可信內容、來源缺漏／bootstrap、目標 cwd 與來源分離、Git env 覆寫、gh actor、SSH exit 1、HTTPS 分流及各退出碼／去敏結果；不得 staging、commit／push、切換認證、credential fill 或回顯 token。

## 2. Issue 建立與更新入口

- [x] 2.1 新增 `github-issue` Skill，解析 Change／repo、精確鍵查重，遠端寫入前呼叫共用 api preflight，再用 gh create／update 並核對結果；案例存 `references/acceptance-cases.md`。測試要求：人工重播新建、重複、多候選、相似標題鍵不符、gh／script 缺漏、非 pass、timeout 與部分成功，比對 script→gh 順序與禁止寫入，不切換 MCP，不自行 commit／push，模擬不冒稱執行。
- [x] 2.2 加入父子、依賴解除條件與等待資料更新範例，以及首次接管既有正文的操作說明。測試要求：重播一個目標拆多個 Change、等待 N 天、marker 缺漏及人工新增正文；更新保留原內容，不複製 `tasks.md`，時間到不誤關 Issue。

## 3. PR 建立、版本發布與摘要更新

- [x] 3.1 新增 `github-pr` create／publish：核對 repo、base／head、可信政策及完整 diff，在各寫入前分別調用共用 commit／push／api preflight，再按需委派 writer、git push、gh 建立／更新 PR。測試要求：案例含乾淨已提交、混合 dirty／兩 Change／untracked、錯帳號／remote、missing gh／script、unsupported、hook／push 失敗；非 pass 不繼續，不重寫身分檢查或切換 MCP，人工案例不冒稱真實 staging。
- [x] 3.2 實作 update-description 路徑與 shared-body 保留規則，獨立於 Git publication；已有 PR 的 create 回傳原 PR，publish 明確發布新版本。測試要求：重播人工正文、其他 Reviewer 報告、重複 marker、並行 ownership 衝突及既有 PR；update 呼叫序列不得包含 add／commit／push／merge／改 base／close。
- [x] 3.3 在共用手冊記錄人工斷點、design-approval、兩階段 PR、預設可轉交訊息，以及授權 archive／doc-updater／commit 後 publish 再複審最終 head 的順序。正式圖來源為 `template/common/docs/diagrams/github-handoff.svg`。測試要求：人工案例涵蓋 local-only、批准遺漏、實質設計改變、archive 搬移／spec 同步、語意修訂及已 merged PR 需另授權 follow-up；圖稿另驗 XML、渲染、文字圖例與連結。

## 4. 安裝與使用說明隨功能落地

- [x] 4.1 將共用 doc、SVG、`scripts/github/check-identity.sh` 同列 installer managed 清單，沿用 Skill 同步及 rule mirror，更新必要 README／架構／入口。測試要求：暫存 repo 預期 Red 涵蓋第二次安裝同時更新三個 managed 檔及腳本可執行權限；再驗初裝、冪等、Skills／案例／契約／rule 一致、無關 scripts 與 WI 保留，執行受影響 installer／Work Item／handoff 測試。
- [x] 4.2 暫存 target 驗證後執行 `scripts/skills/install.sh` 安裝本 repo，檢查 Claude Code、Codex、Antigravity 的入口與欄位規範。測試要求：比對來源與安裝副本、確認必要引用可解析；工具無法啟動時明記只驗證安裝／文件，不能宣稱 runtime 通過。

## 5. 整體交接驗收

- [ ] 5.1 在明確授權的測試 repo 透過 gh 完成 Issue／Draft PR 建立、重試查重、更新保留人工內容、git 發布版本與另一 Session 無 WI 接手。測試要求：記錄 gh 版本、api／commit／push preflight 結果、實際各 actor、Issue／PR URL、remote head；不足時保留未完成，不以 stub／人工模擬代替，不要求 MCP 驗收分支。
- [ ] 5.2 執行必要專案檢查、`openspec validate add-github-change-handoff --strict`、`git diff --check` 及文件／SVG 檢查，確認各生命週期分開。測試要求：正式 run 文件採 OKF Reference 與必要 metadata／sources，保留歷史結果；記實際命令、限制及跨機器是否實測，完成後提供設計與驗收 Review。

## Workflow follow-up

- `add-change-review-skill` 的 PR 整合依賴本 Change 的共用契約與已安裝入口；兩邊不得各維護一套 schema。
- Archive、commit、push 正式交付、merge 與部署依當次使用者授權執行，不列為本清單的實作完成假設。
