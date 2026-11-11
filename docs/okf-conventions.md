---
type: Reference
title: 文件與圖稿撰寫規範
description: OKF v0.2 格式、分類寫作、有效設計與 SVG／HTML 交付要求。
tags: [meta, conventions, okf, documentation, diagrams]
generated: { by: codex/GPT-6, at: 2026-11-11T12:07:41+08:00 }
sources:
  - id: okf-spec
    resource: https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md
    title: Open Knowledge Format v0.2
---

<!-- Managed by wk-agent-ops · do not edit here — re-running install.sh overwrites this file. -->

# 文件與圖稿撰寫規範 — OKF v0.2

文件應讓初次閱讀或數月後回訪的人，不依賴對話背景也能理解用途、概念與操作方式。
先說明讀者要完成什麼，再提供必要細節；術語首次出現時解釋，避免重複敘述。

## 適用範圍與文件分工

- 寫作與圖稿規則適用於根目錄及模組內的 `docs/`、README及操作說明。
- OKF 格式適用於專案文件 bundle；AGENTS、SKILL、OpenSpec artifacts 等有自身 schema 的檔案保留原格式。歷史紀錄不套用「只保留現況」的要求。
- Work Item 專屬內容與圖稿存放規則見 [Work Item 協作紀錄規範](../work-items/AGENTS.md)。
- 依文件用途選用分類，不要求搬動既有目錄。一份文件可包含多種類型，但應容易找到各自內容。
- 優先更新既有文件、範例與圖表，避免維護兩份相同內容；索引頁連到唯一權威文件。
- 修改功能時同步更新相關文件、範例、圖稿與連結；只改受影響部分，不重寫無關內容。

## OKF 格式與本專案要求

OKF 使用 Markdown 與 YAML frontmatter，`type` 是概念文件唯一始終必要的欄位；
其他 metadata 多為選填。本專案另外要求 `title`、`description`、`tags`，並採用以下分類；
這些較嚴格的要求不代表 OKF 官方限制。[^okf-spec]

| type | 用途 |
| --- | --- |
| `API` | API 使用契約 |
| `Playbook` | 操作手冊、SOP |
| `Architecture` | 系統架構與設計 |
| `Spec` | 正式規格說明；不改變 OpenSpec 自身 schema |
| `Reference` | 參考資料、慣例與指南 |
| `Decision` | 獨立決策紀錄；現況文件不複製其討論歷程 |

新概念文件範例（身分、時間與來源須替換為實際已知值）：

```yaml
---
type: API
title: 查詢設備資料
description: 查詢設備目前狀態的參數、回應與錯誤處理。
tags: [api, devices]
generated: { by: "<producer>/<version>", at: "<實際內容更新時間，含時區>" }
sources:
  - id: device-contract
    resource: /specs/device-api.md
    title: 設備 API 契約
---
```

`generated` 表示內容產生者與更新時間；身分不明時省略該選填欄位並交代未知，
不得猜測原作者。不得將內容更新時間當作來源資料日期或驗證時間。
`verified` 僅記錄實際完成且有依據的查驗；未查驗時省略，不能因文件寫完或測試指令結束就新增。
`status` 若使用，只表示文件生命週期（`draft`、`stable`、`deprecated`）；實作、部署與驗證狀態另在正文描述。
`stable` 不代表已部署。`stale_after` 等選填 metadata 僅在有實際用途及依據時加入。[^okf-spec]

### 來源與連結

有來源支持的關鍵論點使用具名腳註，標籤對應 `sources[].id`；每個來源條目須有 `resource`。
不要只列無法對應論點的來源清單。[^okf-spec]

```markdown
設備 ID 為必要參數。[^device-contract]

[^device-contract]: [設備 API 契約](/specs/device-api.md)
```

文件之間可用 bundle-relative 路徑（例如 `/docs/architecture.md`）或相對路徑；
鄰近圖稿優先使用 `diagrams/flow.svg`。bundle-relative 不是本機檔案系統的絕對路徑，
不得寫入私人工作區路徑。檢查目標閱讀方式，不假設瀏覽器把 `/docs/` 當 repo root。[^okf-spec]

`index.md` 負責索引，`log.md` 記錄歷史；它們不套用一般概念 frontmatter。
只有 bundle 根目錄的 `index.md` 可選擇放 `okf_version: "0.2"`；不為升級強制新增索引。
`log.md` 以 ISO 日期分組、由新到舊排列。不得宣稱未檢查的整個 bundle 已完成遷移。[^okf-spec]

### 漸進遷移

新文件與實質更新的文件採 v0.2：舊 `timestamp` 由 `generated.at` 承接目前內容更新時間，
獨立 `# Citations` 清單改為 `sources` 與對應腳註。這是 v0.2 明列的遷移差異；既有 v0.1 內容仍有相容讀取方式。[^okf-spec]

- 只遷移此次實質更新的文件，不為連結修正而全面重寫 metadata，也不批次改寫下游 repo 或歷史檔案。
- 原時間若仍是必要歷史證據，保留其意義；不得將目前編輯者填成當年作者。
- 引用與論點無法可靠對應時保留原引用並回報待確認處，不猜配、不刪證據。
- 保留未知擴充欄位；自訂 `status` 若代表實作進度，將資訊移至清楚命名的擴充欄位或正文，不能直接丟棄。
- 缺少選填 metadata、未知 type 或舊格式不等於文件無效；格式符合性、寫作完整性與內容正確性分別檢查。

## API 文件

讓讀者清楚知道「如何呼叫、會得到什麼、出錯如何處理」。至少包含：

1. 用途、適用版本／環境、Base URL 或取得方式；未部署時明示，不編造可用網址。
2. 路徑、HTTP 方法、認證與必要 headers。
3. Path／Query／Body 參數：名稱、型別、必填與否、預設值及限制；不適用者明示。
4. 完整請求範例；命令可執行，替換值、憑證取得方式及執行目錄清楚，範例不含真實秘密。
5. 成功回應範例與欄位說明：型別、單位、時間語意、空值及部分成功的含義（適用時）。
6. 常見 HTTP 狀態碼／錯誤碼、錯誤範例、原因與修正方式。

完整 JSON 與節錄要分清；合成、實測與未驗證範例明確標示。
已有 schema 或範例檔時引用並同步更新，不再維護另一份矛盾的契約。

## 操作文件

把讀者當作第一次操作，不要求記得先前 session 的設定。

1. **目標與前置條件**：工具／版本、權限、設定及需要先完成的步驟。
2. **依序操作**：以編號步驟描述，每段命令註明執行目錄；共用目錄可在一組步驟前統一聲明。
3. **可執行命令**：說明哪些值必須替換、如何取得；命令執行前交代破壞性或外部影響。
4. **預期結果**：每個重要步驟提供可辨識的畫面、輸出、檔案或狀態，並說明如何確認整體成功。
5. **常見問題 Q&A**：按症狀列出可能原因、檢查位置／命令、處理方式與恢復後的預期結果。

適用時提供安全回復步驟；不為湊章節編造錯誤或回復方法。未實際走過的操作標示未驗證，
不能把程序啟動或單一端點成功當成端到端成功。

## 設計與規格文件

先說目的與範圍，再說核心概念、架構／元件責任、主要流程、規則與限制。
複雜流程或資料流以圖稿輔助，圖中名稱、方向、狀態及邊界須與文字一致。

- 正文只維護目前有效決定，刪除受影響的過時與重複描述；保留理解架構所需的技術理由。
- 使用「路線 A：由後端集中取數，前端透過同源 API 讀取」，避免「使用者要求 XXX，所以後來改走 A」等對話敘事。
- 探索、替代方案、歷史證據放在既有協作紀錄、OpenSpec archive 或歷史文件；不刪除它們，也不要求讀者先讀討論才能理解現況。
- 已核定設計、已實作、已部署、尚未驗證分開說明。未完成設計標示為目標設計，不寫成目前運作結果。
- OpenSpec design 等自有 schema 要求的技術取捨保留；不放討論紀錄不表示刪除必要理由、來源或限制。

## 圖稿格式與交付

| 閱讀需求 | 優先交付 |
| --- | --- |
| 流程圖、循序圖、系統架構圖 | 獨立 SVG |
| 靜態平面設計、版面與 UI 設計稿 | 獨立 SVG |
| 需要點擊、切換、輸入等 UX 互動 | HTML |

使用者明確指定格式時依其要求；工具或用途有實際限制時說明例外。
Mermaid 等來源可保留，但不得只交付需要另行渲染的原始碼。

- 圖檔放在所屬文件的 `diagrams/`，在相關文件提供預覽或可直接開啟的連結。
- 優先更新既有圖；複雜內容拆圖，保留可讀字級、清楚箭頭與圖例，不只用顏色區別狀態。
- SVG 提供可理解的標題／描述；HTML 互動使用可操作的語意控制項與標籤，不能只畫出看似可點擊的按鈕。
- 檢查格式、連結與圖文一致性後，實際開啟渲染結果，確認文字不溢出、不重疊，箭頭方向清楚，正常瀏覽及縮放時可讀；HTML 另操作相關互動。
- 語法通過不代表視覺驗收通過。無法渲染或操作時，明示未完成哪一項，不宣稱驗收成功。

## 交付前檢查

確認讀者不需要對話背景；分類必要內容齊全；命令、範例、圖稿與連結一致；
受影響的舊敘述已清理；來源可對應論點；實作、部署與驗證狀態未混淆。
回報實際執行的檢查與重要限制，不把文件更新成功當成系統功能成功。

[^okf-spec]: [GoogleCloudPlatform OKF SPEC v0.2](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)，§4–9、§11–13，2026-11-11 查閱。分類內容及 SVG 優先為本專案政策。
