---
type: Reference
title: openspec-commit 交付擴充驗證紀錄 2026-11-14-extend-delivery-r02
description: 針對 Review codex-sol-commit-r01 的修正驗證：F-03 head 一致性保護與 F-04 fixture 簽章獨立的 Red／Green，F-01／F-02 在新 HEAD 的核對，以及 12 套檢查、strict validate 與盲測重播；沒有真實交付寫入。
tags: [verification, openspec-commit]
generated: { by: "claude-code/Claude Opus 5.5", at: "2026-11-14T13:30:00+08:00" }
sources:
  - id: cases
    resource: template/common/skills/openspec-commit/references/acceptance-cases.md（工作區未提交版本，base a8fcc03）
    title: openspec-commit 可重播案例
---

# openspec-commit 交付擴充驗證紀錄 2026-11-14-extend-delivery-r02

## 範圍與版本

- Review：[codex-sol-commit-r01](https://github.com/wkchen5872/wk-agent-ops/pull/16#issuecomment-6871954422)，結論 changes-required。
- 已發布：PR #16 head 與 `origin/feature/extend-openspec-commit-delivery` 都是 `a77c009`。
- 本地 HEAD：`a8fcc033e073a801f3fbc9ed7274f3a0b914b3ec`，是文件 Codex 的文件與圖稿 commit，尚未 push。
- 受驗內容：`a8fcc03` 加上未提交的 Skill、references、test、tasks 與本證據；index 為空。
- 不包含：另一個 Change 的未追蹤副本與 ignored Work Item。
- 先前的 r01 證據與 Review 快照（`a77c009` + 25 檔）不涵蓋 `a8fcc03`。
- 執行者：Claude Code · Claude Opus 5.5，原生 Session `76a402cb-24eb-4002-b17a-88d15a596163`，Xirp `eb4f5f48-3592-47fd-90e9-21249f334648`。

## F-04：fixture 不受使用者簽章設定影響

**Red**：以 `GIT_CONFIG_GLOBAL` 指向臨時設定檔（`commit.gpgsign = true`、`gpg.program = /usr/bin/false`），沒有更改使用者的全域設定。在這個設定下執行舊 fixture 的 `bash tests/test_openspec_commit.sh rehearsal`：

- exit 1。
- clone `O` 的 commit 失敗（`error: gpg failed to sign the data`），連帶 `a non-fast-forward push is rejected` 與 `rejected push leaves the moved remote head untouched` 兩項 FAIL。
- 這與 Review 描述的失敗相同。

**修正**：

- 每個 disposable repo 都用 `fixture_repo` 設定自己的 user，並設 `commit.gpgsign false` 與 `tag.gpgsign false`。
- 必要的 Git 命令經 `must` 執行，失敗時明確 FAIL「fixture command failed」，並有「every required fixture command succeeded」的總檢查。

**Green**：同一個 hostile 設定下，`test_openspec_commit.sh` 整套 exit 0、299 ok。驗證前後執行 `git config --global --get commit.gpgsign`，都仍是 `true`。

## F-03：update 前三個 SHA 必須一致

**Red**：新增的靜態期待與案例在修正前 exit 1，有 8 項 FAIL。其中 F-03 的 5 項是：

- `intended completion SHA is pinned`
- `PR head is read before update`
- `commit, remote and PR head must agree before update`
- `a moved head is not delivered instead`
- `case for 'push 後 update 前 head 移動'`

另外 3 項屬於 timeout 範例。

**修正**（SKILL Step 7a）：

1. 固定 `intended_sha=<completion commit>`。
2. update 前以 `git ls-remote` 與 `gh pr view … --json headRefOid` 讀取，要求 `intended_sha`、remote head、PR head 三者相同。
3. 不同時回報兩個 SHA，停在 update、最終 Review 與 Closure 之前，不改替較新的 head 交付。
4. 只說 `intended_sha` 已推上並讀回，不宣稱它仍在分支上。

錯誤處理表新增對應列，並新增案例 OC-25「push 後 update 前 head 移動」。

**Bare remote 實跑**：

1. 推上 `intended_sha`，讀回相符。
2. 另一個 clone 把分支推到新的 commit。
3. `ls-remote` 讀到的新 head 不等於 `intended_sha`。

這一項通過，用來驗證 Skill 所寫的 Git 讀取足以偵測移動。

## Timeout 範例

`references/examples.md` 改成兩種情況，與 SKILL 的 recovery 規則及 OC-20 一致：

- 確認未發布（confirmed not posted）：重新讀取 PR head 後，以同一工具重試一次並回讀。
- 仍無法判定（still unclear）：記為 uncertain，不重送。

測試另外確認舊的「not resent」寫法已移除。

## F-01／F-02：在 `a8fcc03` 核對（只驗證，未修改）

- **F-01**：從 `a8fcc03` clone 出乾淨 checkout，沒有 Work Item，也沒有另一個 Change 的副本。`local-development.md`、`commit.md`、`guide.md`、`docs/diagrams/README.md`、README、AGENTS.md、`architecture.md` 的 100 個相對連結全部可解析。`local-development.md:121` 只以文字提到另一個 Change 的名稱，沒有連結，也不依賴它。結論：已滿足。
- **F-02**：以 `rsvg-convert -w 1600` 重新渲染四張 SVG，與已提交的 PNG 比較：
  - 尺寸相同。
  - 約 3% 的像素差異集中在字形抗鋸齒，判斷是 renderer 不同造成。
  - 並排檢視 finish 的分支區，兩者節點與路徑相同：本地完成（預設）、成功交付、取消或被取代，取消路徑寫明「不 push 放棄成果」。

  結論：已滿足，但兩者不是逐位元相同。

## 整合檢查

- 最後一次 `scripts/skills/install.sh` 的 exit 為 0，只更新 `openspec-commit` 的安裝目標；已提交的 review-loop 與 github-handoff 圖稿沒有被改動。
- 12 個套件逐一以 `rc=$?` 取得 exit code，全部為 0、FAIL 數為 0：agents_dir、bulk_read_routing、change_review、documentation_authoring、github_handoff、github_pr_publication、mutation_skills、openspec_commit、portable_agents_md、tdd_enforcement、work_items、workflow。
- `openspec validate extend-openspec-commit-delivery --strict`：通過。
- 盲測重播：新的 subagent 只拿到 OC-07 與 OC-25 的 Fixture 與模擬回覆。
  - OC-07：完成交付，停在 Closure，與判定一致。
  - OC-25：update 前比對三個 SHA 後停止，不替 `c8` 交付，與判定一致。
  - 重播提出的「`c7` 可能已被 force push 移除」已依此調整措辭。

## OpenSpec verify

- Completeness：9/9 tasks。
- Correctness：2 項 MODIFIED、5 項 ADDED requirement 都有對應。「Push fails or head moves」這個 scenario 現在同時涵蓋 push 被拒，以及 push 後、update 前 head 移動。
- Coherence：遵循 design 決策 1–6；正式文件由文件 Codex 在 `a8fcc03` 交付，不依賴未追蹤內容。

## 未執行與限制

- 沒有真實執行 push、PR update、最終 Review、Closure、close 或 merge；GitHub 競態只以模擬與本地 bare remote 驗證。
- 盲測重播者與實作者是同一個模型家族。
- 尚未處理的設計問題：取消時的 spec sync、commit type，以及在 Step 1 就停止時是否查詢 PR。這些不在本輪範圍內。
