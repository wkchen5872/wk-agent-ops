# Verification

## 結果

2026-11-11：7 項任務、7 項 requirements、13 個 scenarios 均有對應規範及入口。
未發現阻擋實作完成的缺口。規範語意以文件審查驗收；未將其當作跨工具 runtime 成功。

| 面向 | 證據 |
|---|---|
| 完整性 | proposal、design、兩份 delta specs、tasks 齊全；strict validation 通過 |
| 正確性 | 共用規範與三個 updater 入口覆蓋分類、遷移、圖稿、狀態、最小修改要求；下列案例逐項核對 |
| 一致性 | 規則集中在既有 managed doc；未新增 skill、依賴或 installer 行為；6 組來源／安裝檔逐位元組相同 |

## 自動檢查

在 repository root 執行：

| 命令／檢查 | 結果 |
|---|---|
| `bash tests/test_documentation_authoring.sh` | Red exit 1：修改前 17 項缺少新契約／入口；修改後 Green exit 0，17 項通過 |
| `bash tests/test_portable_agents_md.sh` | 通過；起初作者 metadata 被全文搜尋誤判，改為只檢查正文的工具綁定 |
| `bash tests/test_openspec_commit.sh` | 通過；既有模式及提交協作契約保留 |
| `bash tests/test_agents_dir.sh` | 通過；含暫存目標重複安裝、自訂 agent、Codex config／skills 保留與 repo 同步 |
| `bash tests/test_tdd_enforcement.sh` | 通過；protocol 與安裝入口保持一致 |
| `bash tests/test_work_items.sh` | 通過；版本預期由 2.5.0 更新為 2.6.0，既有文件與 WI 紀錄保留 |
| `bash scripts/skills/install.sh` | common profile 安裝成功，只同步管理範圍 |
| YAML／TOML parsing | 2 份 managed docs、skill、Claude agent frontmatter 及 Codex agent TOML 可解析 |
| 來源／安裝檔比較 | 2 份 managed docs、2 份 installed skills、2 份 agents 全部相同 |
| `openspec validate standardize-docs-and-diagrams --strict` | 通過 |
| `git diff --check` | 通過 |

## 可重播的語意審查

方法：閱讀 `template/common/docs/okf-conventions.md` 對應章節及 updater 的
Shared authoring contract，以下輸入逐項判斷規範是否給出明確處置。
這是 agent 進行的文件語意審查，不是人類簽核，也不是另啟 session 的產物實測。

| 案例輸入 | 預期處置／本次審查結果 |
|---|---|
| module/docs API 只有方法與路徑 | API 章節要求用途、認證、參數、完整請求、回應欄位／單位／空值、錯誤及修正；updater 明列 nested module docs、examples、diagrams。符合 |
| SOP 只有一串命令 | 操作章節要求前置條件、編號步驟、執行目錄、替換值、逐步預期結果、完成檢查與症狀式 Q&A。符合 |
| 設計稿含「使用者要求」，且前後功能狀態矛盾 | 設計章節要求直接說明有效架構，清理過時／重複處並保留技術理由；updater 要求 reconcile。符合 |
| 已核定但未部署的設計，旁有歷史證據 | 設計、部署、驗證分開；歷史保留於原用途紀錄，不能為維護現況而刪除證據。符合 |
| v0.1 文件作者未知、引用無法對應 | 漸進遷移不猜作者／引用，保留證據並回報；未知擴充欄位保留，自訂部署 status 另存。符合 |
| 新 API 與 reserved index/log | 新概念有 type 及專案額外欄位，known generated 與 sources 腳註；index/log 不強加一般 frontmatter。符合 |
| Work Item 靜態流程或 UI 平面稿 | protocol 明列 Work Item diagrams；規範預設獨立 SVG、相對連結，不強迫 Work Item 紀錄改 OKF。符合 |
| 需要輸入及切換的 UX 設計 | 使用可操作 HTML；語法與互動／渲染驗收分開。符合 |
| 只交 Mermaid 原始碼或沒有瀏覽器工具 | 規範要求可直接瀏覽的交付；無法視覺驗收時明示，不假裝通過。符合 |
| 三種 updater 入口更新文件 | 都引用同一規範，檢查變更路徑及限制；既有 no-commit 與 mode 行為保留。符合 |

## 限制與後續

- 未另啟 Claude Code、Codex、Antigravity session 測試實際遵循；入口鏈與同步已檢查。
- 本次沒有產出或修改 SVG／HTML 設計稿，因此未做圖稿渲染／互動驗收。
- 未改寫 fio-pv-twin 或全面遷移歷史文件，未宣稱所有文件符合 v0.2。
- 未執行無關 workflow／通知功能全套測試；此次僅執行上述受影響檢查。
- 尚未 archive 或 commit；這些交付動作與本次 apply 完成分開。

## Work Item 規範分工調整驗證

- 保留使用者的「所屬文件 diagrams/」與表格格式修改，回填 template 來源後透過 installer 同步。
- 共用文件規範只留 Work Item 規範連結；專屬 schema、歷史、圖稿位置及正式交接要求集中在 `template/common/work-items/AGENTS.md`，圖稿格式與驗收仍引用共用規範。
- 契約檢查新增 3 個入口／位置檢查及 1 個禁止重複存放規則檢查：修改前 exit 1，修改後 exit 0。
- `test_documentation_authoring.sh`、`test_work_items.sh`、`test_portable_agents_md.sh`、strict validation、diff whitespace 及 3 組來源／安裝檔比較通過。
- 未另啟 agent runtime；未產生或搬動任何實際 Work Item 紀錄或圖檔。
