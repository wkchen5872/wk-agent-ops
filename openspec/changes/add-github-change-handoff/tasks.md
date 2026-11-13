# Tasks

本版是使用者要求的工具／認證責任調整，需由 Claude 依新設計修改既有實作。舊版 13 項完成與歷史證據不代表本版已驗收；下列受影響工作重新開啟。保留舊報告與證據，不回寫成新版通過。這次授權包含設計調整與實作交接，不自動新增 commit／push／merge／archive 授權。

歷史證據：[apply-r01](../../../docs/verification/github-handoff/2026-11-13-apply-r01.md)、[gh-r02](../../../docs/verification/github-handoff/2026-11-13-gh-r02.md)。本版證據：[native-r03](../../../docs/verification/github-handoff/2026-11-13-native-r03.md)（自動測試、63 案重播、唯讀真實 gh；尚未發布）。舊 head 922d29a 的 implementation Review 有三個 identity-script 缺陷及 fork 核對缺口；本版採移除 credential reconstruction 解決前者，不再擴充 parser。修正後須對實際新版本複審。

## 1. 共用契約與簡化操作檢查

- [x] 1.1 更新共用契約為完整 host／owner／repo、operation、使用者授權、當次工具連線／可得權限與結果回讀。先保存 fixture：host 相同但 repo 不同、只有讀取權限、實際寫入拒絕、權限 metadata 不完整但授權操作可成功；不得為探權限額外建立 Issue／PR 或空 commit。
- [x] 1.2 移除必經 identity policy、可信 script blob、SSH 問候語與 HTTPS helper 解析；停用並移除舊 check-identity.sh 的來源／本 repo managed 副本與 installer 登錄，清除 protocol／rule／Skill／README／架構中的強制依賴。測試先驗舊前提造成的失敗，再驗無 script／policy 仍能使用原生工具；不動登入、keys、credential helper 或無關下游 scripts，不能安全刪除的遺留檔回報而不再呼叫。
- [x] 1.3 區分預設無帳號限制與明示限制；Git author／committer、API 與 push 不必相同。先保存案例：合法不同身分、實際 actor 不可得如實記錄、明示限制不符／無法核對則停止、候選 PR 不得放寬可信限制。人類批准記錄者授權仍獨立核對，不由 repo 權限推導。
- [x] 1.4 保留共用 Issue／PR／Review schema、完整 Scope and Baseline、provenance、Finding IDs 與單一 ownership，補操作工具與可得 actor 證據，不記 credential／helper 內容。F-01 以去除敏感來源與秘密不進輸出驗證；F-02／F-03 以不再執行 parser 及原生操作驗證，不要求修補舊 parser。新增正式修訂證據，保留原 Review 的歷史適用版本。

## 2. Issue 建立與更新入口

- [x] 2.1 更新 github-issue：可用 gh 或 MCP，依同一精確關聯查重、建立／更新及結果回讀；使用各自實際上下文，不借用另一工具的登入證據，不新增 adapter。案例包含 gh 缺少但 MCP 可用、MCP 無能力、明確拒絕、timeout 後跨通道先查重、部分成功；不得擅自登入或盲目重送。
- [x] 2.2 重驗首次採用 managed 區塊、人工正文保留、父子與 dependency 區分、等待真實資料及 next-action；不複製 tasks、不因日期或 PR 合併自動關閉 Issue。

## 3. PR 發布、更新與版本證據

- [x] 3.1 更新 github-pr create／publish：先盤點完整 dirty 與 base-to-head scope，按需沿用 writer，使用原生 Git 非 force push，核對實際目的 repo／ref 及 remote head，再用選定 GitHub 工具建立／更新。先驗混合 dirty、commit／hook／push 失敗、既有 commit 重用、原生 SSH／HTTPS 不需 principal parser、實際發布後版本回讀；不得自行 stash、reset、改認證或製造空 commit。
- [x] 3.2 保留純 update 無 Git 副作用、既有 PR create 只回傳、publish 才發布新版本與正文 ownership；以 gh／MCP 可用能力逐案重播。W-01 必須核對實際 headRepository、head owner、base／head branch，fork create 明確表達目的；工具無法表達則停止，不靠同名分支、正文或 SHA 冒充 repo 身分。
- [ ] 3.3 同步生命週期手冊與正式 SVG、批准事件及 Review 發布方式。保留設計批准／實作 Review／merge／部署／資料驗收／archive 分離，依新設計回讀事件作者；本次實質修訂的新批准版本與範圍須如實另記，舊事件不改寫。Review 發布不經 create／publish，通知送出不等於接收。

## 4. 安裝與一致性

- [x] 4.1 先更新 installer／contract 的必要測試再改產品來源；保留 managed doc／SVG、rule mirror、Skills 同步與跨工具入口，不再安裝 identity script。暫存 target 驗初裝、重裝／冪等、無關 scripts／WI／本機認證配置保留；舊字串存在測試不能冒充操作驗收。
- [x] 4.2 透過 installer 更新本 repo，核對 template 與 managed 副本、引用與 Claude Code／Codex／Antigravity 的入口；未啟動的 runtime 如實標記。檢查任何保留的舊腳本不再被呼叫；不回復其他 Agent 的未提交內容。

## 5. 本版整體驗收與交接

- [ ] 5.1 先保存新情境／預期／禁止，再用 Agent 重播 gh、MCP 等價決策、能力不足、指定帳號、秘密不輸出、timeout reconciliation 及無 WI 接手。在既有授權測試 repo，以任一可用通道真實驗證建立、查重、保留人工內容、原生 Git 發布、remote head 與接手；另一通道未具備時列未實測，不為湊驗收安裝／登入。記工具／版本、可得 actor、URL、實際回應與限制。
- [ ] 5.2 執行必要專案檢查、openspec validate add-github-change-handoff --strict、git diff --check、連結與 SVG XML／實際渲染。去敏證據使用 docs/verification/github-handoff/<run-id>.md 的 OKF Reference，對應當次版本，不修改舊 run。依既有授權發布修訂內容並交回 Reviewer，逐項說明 F-01／F-02／F-03／W-01 如何在新實作解決，重新審查實際新 head。

## Workflow follow-up

- add-change-review-skill 只同步上游契約依賴，仍是另一份 Change；本次不順帶實作 Review Skill。
- 本版沒有改 Issue／PR 的核心格式與既有 provenance 揭露決策；折疊歷史等精簡建議不藉此擴張。
- 新版本需明確區分設計已修訂、實作已調整、已發布與已驗收；archive／merge／部署仍按當次授權。
