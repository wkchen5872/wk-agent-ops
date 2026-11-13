---
type: Reference
title: GitHub 交接驗證紀錄 2026-11-13-simplify-issue-r05
description: simplify-github-issue 實作的驗證：Issue 來源選擇、精簡正文、只新增留言的更新與共用契約限縮，包括靜態契約測試、離線決策重播與 SVG 渲染；沒有真實的 GitHub 寫入。
tags: [verification, github-handoff]
generated: { by: claude-code/Claude Opus 5.5, at: 2026-11-13T20:40:00+08:00 }
sources:
  - id: cases
    resource: /template/common/skills/github-issue/references/acceptance-cases.md
    title: github-issue 可重播案例 GI-01–GI-34（工作區版本，尚未 commit）
  - id: contract
    resource: /template/common/docs/github-handoff.md
    title: 共用契約第 5、6.1、7、10、11 節與附錄 A
  - id: change
    resource: /openspec/changes/simplify-github-issue/
    title: OpenSpec Change simplify-github-issue
---

# GitHub 交接驗證紀錄 2026-11-13-simplify-issue-r05

## 範圍與授權

- 執行者：Claude Code，模型 Claude Opus 5.5。離線重播由同一 Session 啟動的兩個獨立子
  Agent 執行（general-purpose，沿用同一模型）。
- 範圍：`simplify-github-issue` 的 tasks 1.1–4.2。使用者授權 apply；**沒有**授權遠端寫入，
  所以本輪沒有建立 Issue 或留言。
- 證據分三類：靜態契約測試（檢查文字與安裝結果）、離線決策重播（依模擬回覆推導呼叫，
  不實際呼叫工具）、真實 GitHub 寫入（**本輪未執行**）。

## 靜態契約測試

`tests/test_github_handoff.sh` 新增三組檢查，每組都先在舊版取得 Red，再實作轉 Green：

| 群組 | 檢查內容 | Red（舊版） | Green |
| --- | --- | --- | --- |
| SGI-1 | §6.1 初始正文的順序是 Handoff → Goal → Author，有三個 Handoff 欄位與 Author 行，沒有標記、`repository`、Provenance、owner；skill 提到 Work Item／Session-only／直接讀 `work-items/WI-*/README.md`／`null`；11 類來源案例 | 25 項 FAIL，`exit 1`，例如 `FAIL Issue template drops '- repository:'` | 通過 |
| SGI-2 | §6.1 更新留言是 Handoff → Changes → Author；update 使用 `gh issue comment` 並讀取 comments；skill、案例與範例在禁止項以外不出現正文／留言編輯；沒有 adoption；12 類更新案例 | 17 項 FAIL（`gh issue comment` 與留言範本尚不存在） | 通過 |
| SGI-3 | §5 的精確鍵查找只涵蓋 PR；§7、§11 寫出 Issue 例外；§10 不再依賴 Issue 的 Waiting 區段；C-13 改用 References；契約、github-pr、change-review、rule 在禁止項以外不要求改寫 Issue 正文 | 6 項 FAIL（含 C-20 的 `gh issue edit` 與 CR-27 的 Waiting 區段） | 通過 |

Red 都是預期的行為原因（舊範本與舊流程），不是語法或環境問題。

最後一次全套執行（`for t in tests/test_*.sh`）全部 `rc=0`：agents_dir、bulk_read_routing、
change_review、documentation_authoring、github_handoff、mutation_skills、openspec_commit、
portable_agents_md、tdd_enforcement、work_items、workflow。`openspec validate
simplify-github-issue --strict` 回報 valid。

## 安裝

`bash scripts/skills/install.sh` 的 exit code 為 0。之後 template 與 `.claude/skills/`、`.agents/skills/`
下的 `github-issue`、`change-review` 逐一 `diff -r` 一致；`docs/github-handoff.md`、交接 SVG 與
`work-items/AGENTS.md` 也和來源一致（由 4.2 的同步檢查確認）。`.codex/` 只有 `agents/`，
installer 沒有建立或修改 `.codex/skills/` 或 `.codex/config.toml`。installer fixture 測試
（保留無關腳本、圖、Work Item 與 credential 設定）照常通過。

## 離線決策重播

依契約第 12 節：子 Agent 只讀 skill 與契約，先依 Fixture 與模擬回覆推導呼叫，之後才看
預期呼叫、禁止與判定。

- **第一輪（GI-01–GI-34）**：33 例通過，GI-21（分支歧義）勉強通過。另外指出附錄 A 的
  C-13、C-19、C-20、C-24 與 §10 還在用舊的 Issue 語意，GI-06 的呼叫順序和 skill 不一致，
  回讀失敗也沒有明確規則。
- **修正**：C-13、C-20 和 §10 已在 3.1 改好。C-19、C-24 不再寫「兩個精確鍵」。skill
  把「分支上合理但無法證實的對應」也算候選，必須詢問、不能退到 Session-only。建立與
  留言都補上「回讀失敗：回報為未確認，不重送」。GI-06 改成不限定核對前是否先讀取。
- **第二輪（GI-06、GI-09、GI-21、GI-34、C-13、C-19、C-20、C-24）**：見下節。

## 第二輪重播結果

| Case | 結果 | 說明 |
| --- | --- | --- |
| C-13 | pass | References 標明 local-only，發布後以留言補連結 |
| C-19 | pass | 只用 MCP，讀候選的正文與留言才判定沒有重複 |
| C-20 | fail → 已修正 | skill Step 3 把「缺少能力」寫成一律停止，與 C-20／§13 改用另一個已配置工具的做法衝突。已補上「另一個已配置工具有此能力時，回報缺口後在同一授權內重新核對該工具」；修正後未再重播 |
| C-24 | pass | 逾時後重新查找並比對正文，沒有重送 |
| GI-06 | pass | 唯一的工具缺少能力，停止且不寫入 |
| GI-09 | pass | 回讀失敗，回報為已建立但未確認，不重送 |
| GI-21 | pass | 列出候選並詢問，不退到 Session-only |
| GI-34 | pass | 回讀失敗，回報為已留言但未確認，不說成建立了 Issue |

範圍外的觀察（沒有在本 change 處理）：C-21 的禁止項「換另一個工具重送而不先說明拒絕」，
看起來允許在說明拒絕後換工具重送，與 §3 步驟 4「明確拒絕就停止」不一致。這是既有的共用
規則，跟 Issue 精簡化無關，留待另外處理。§6 開頭的「或依第 7 節處理」對 Issue 只剩揭露
規則適用，屬於措辭問題。

## SVG

`rsvg-convert` 已實際渲染 `template/common/docs/diagrams/github-handoff.svg`，人工檢查改過的
五行文字（步驟 02、右側「Issue 是工作入口」與「純 update 不改 Git」）：沒有超出框線，也沒有
重疊。`xmllint --noout` 通過。

## 已知限制

- **真實 GitHub 的 create 與 comment 都沒有驗證。** 本輪沒有遠端寫入授權。`gh issue comment`
  回傳的 URL、留言回讀的 API 欄位，以及 `in:body,comments` 搜尋在真實 repository 上的行為，
  都需要另外取得授權，在測試 repository 驗收。
- 靜態測試只證明文字與安裝結果。Agent 實際怎麼選擇，只有上面的離線重播可以佐證。
- 上游 `add-github-change-handoff` 尚未封存。封存本 change 之前，依 design 的 Migration Plan
  第 5 步處理共用 capability 的 MODIFIED delta。
