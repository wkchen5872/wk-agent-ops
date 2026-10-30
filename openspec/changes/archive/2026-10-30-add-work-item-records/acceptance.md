# 獨立驗收：add-work-item-records

日期：2026-10-30。驗收者：Codex（本對話本地別名 codex-s01）。

**功能驗收通過。** 原實作者修正本輪四項問題後，獨立重跑的完整測試、補充案例、安裝副本與 Codex 實際載入檢查均通過。另有一件已發生的暫存刪除事件，其目錄歸屬無法完整核實，列於下方保留事項，不能視為已解決。

## 基準與範圍

- branch：feature/add-work-item-records；驗收時 HEAD：4cdf6949d5a868b38b9ff817c6bb01585172b4da，加上未提交與未追蹤的本 change 內容。
- 原始及修正後各 27 份檔案與 SHA-256，保存於本機稽核目錄的 manifest.json 及 verified/manifest.json；不是僅以 HEAD 固定未提交版本。
- 正式設計與四份 delta specs 和先前通過的設計複審版本相符。修正後 OpenSpec apply context 為 18/18 tasks complete。
- 驗收範圍是本 repo 與隔離測試 target；不代表其他消費專案已安裝，也不代表所有 Agent 行為均由機制強制。

## 實際執行結果

| 檢查 | 結果 |
|---|---|
| 逐一以獨立 bash process 執行八支 tests/test_*.sh | 8/8 exit 0 |
| 補充 installer 行為案例 | 四項均 exit 0；規則例外會回報，未擅自修改使用者的規則 |
| template 與本 repo 安裝結果 | 完整規範、managed protocol、Claude 入口及 Antigravity 鏡像四組 byte-identical |
| 新 Codex 唯讀 ephemeral session | exit 0；JSONL 記錄實讀 protocol 與 Work Item 規範的 command_execution，兩者 exit 0 |
| Work Item 測試暫存根目錄 | 測試結束後沒有殘留 fixture repo；系統產生的 xcrun_db 快取未刪除 |
| installer 與兩支異動測試的 bash -n | exit 0 |
| OpenSpec change strict JSON validation | exit 0、valid=true、issues=[] |
| git diff --check | exit 0 |

八支套件為 test_agents_dir、test_bulk_read_routing、test_mutation_skills、test_openspec_commit、test_portable_agents_md、test_tdd_enforcement、test_work_items 與 test_workflow。

Codex runtime 使用正常專案指示、read-only sandbox 與 --ephemeral，未提供答案路徑。實際走過載入的根 AGENTS 指示 → docs/agent-protocol.md → work-items/AGENTS.md，並讀回規範與忽略設定。Claude／Antigravity 在本輪驗證的是安裝與內容一致，沒有額外啟動兩種工具的 runtime session。

## 發現、修正與複驗

| Finding | 原始問題 | 修正及驗證 | 結果 |
|---|---|---|---|
| F-01 / P1 | 固定 probe 漏掉實際 WI 例外；第一版每目錄 README 代表仍漏掉 context.md | 改為列舉既有紀錄下所有實際檔案，批次以 Git 檢查；個別目錄、context.md 及巢狀檔案例外均有回歸測試，回報路徑與責任規則，不改寫例外 | Resolved |
| F-02 / P2 | 已有 /work-items/WI-*/** 等價規則仍追加第二條 | 保留規則來源檢查，以專案 .gitignore 的實際效果判定；重跑不追加等價規則，也不把個人或 repo-local 排除當成專案規則 | Resolved |
| F-03 / P2 | subshell 中更新 TMPDIRS，父 shell 無法清理 fixture | 父 shell 建立單一 TMPROOT，全部 target 放在其下；獨立測試後沒有殘留 fixture repo | Resolved |
| F-04 / P2 | 原生入口重述規則，並指示直接編輯 managed 安裝目標 | 縮成條件式短指標，移除規則清單與直接編輯目標的指示；兩份安裝入口與 source 相符 | Resolved |

本輪補充 Red 命令曾 exit 1，原始 control 正常而問題 case 失敗；補正後四項案例通過。原實作者的 red-all.log 與 red-perfile.log 已實際讀取，失敗斷言與 verification.md 的紀錄相符。首次實作的其餘 Red 敘述保留原作者來源，沒有由本驗收者重建或冒稱親自見證其時間順序。

## 原始證據與重播

本機稽核目錄：
/var/folders/3v/mzr9gm9x4vb3kyqf82p4ct_80000gn/T/codex-work-item-acceptance-_uq1cdgr

其中：

- manifest.json、verified/manifest.json：審查基準與 SHA-256。
- verified/test-logs/：修正後八支套件的原始輸出。
- supplemental-probes.py、supplemental-red.log、verified/supplemental-green.log：補充行為案例與失敗／通過輸出；最後腳本另含 per-file case。
- runtime-prompt.txt、runtime.jsonl、runtime-final.md：新 Codex session 的輸入、事件與回答。

補充案例可用 python3 <本機稽核目錄>/supplemental-probes.py 重播。完整功能案例亦已收入本 repo 的 tests/test_work_items.sh，所以正式驗收條件不依賴本機暫存目錄或 Work Item 才能理解。

## 保留事項

1. **已發生的暫存刪除。** 原實作者在修正 fixture 清理時，另外執行了超出驗收範圍的廣泛清理，回報刪除 275 個匹配 tmp.*/repo/work-items/AGENTS.md 的暫存目錄。未保留逐目錄清單，因此無法完整核實歸屬或重建精確刪除集合；完整命令、時間窗與限制記錄在 verification.md 的 Out-of-scope action taken during this round。這是程序事件，不因功能驗收通過而成為已授權或已解決。
2. **保留證據已核對。** 驗收者重新核對四批已保存快照的 SHA-256，全部相符；本 repo 的 WI Review 與原始重現目錄仍在。沒有進一步廣泛清理或寫入式恢復。
3. **已追蹤紀錄的保護上限。** .gitignore 不會取消既有追蹤；installer 僅回報而不修改 index。既有 Git 例外衝突也只回報，需要專案自行處理。
4. **交付範圍。** 使用者已授權透過 openspec-commit 同步規格、封存、更新文件及本地提交；不包含推送、合併或部署。

## 規格同步與全專案檢查

四份 delta specs 已同步：新增 35 項需求、修改 2 項需求；同步前的 51 個既有 scenario 及未涉及的需求內容均以斷言確認保留。新 capability 的 Purpose 沿用已審閱的完整說明。

同步後一項本次修改的 ownership 需求觸發 500 字元長度警告，已在 delta 與 main spec 等義精簡為 491 字元，保留 managed／seed、目標根相對路徑、父目錄建立、路徑不變及全部檔案分類。change、install-profile-cli 與 work-item-records 的 strict validation 均為 exit 0、issues=[]。

全專案 openspec validate --all --strict 仍為 exit 1：25 個項目中 20 個通過，5 份既有規格有長度 WARNING，沒有 ERROR。已把原 HEAD 的 23 份 canonical specs 複製到隔離目錄重新執行 strict，結果同樣是這 5 份警告；id、位置、等級與訊息全部相同，沒有本次新增的失敗。沒有省略警告或改用較寬鬆模式冒稱全專案 strict 通過。

既有警告位於 codex-human-wait-notifications、git-commit-writer、openspec-commit、portable-agents-md、telegram-notify-hook。基準原始輸出：/var/folders/3v/mzr9gm9x4vb3kyqf82p4ct_80000gn/T/codex-openspec-head-baseline-39g3lh51/validation.json；本次原始輸出位於本機稽核目錄的 pre-archive-validation-after-condense.json。
