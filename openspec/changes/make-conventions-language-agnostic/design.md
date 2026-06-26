## Context

`scripts/skills/install.sh` 把 `template/common/docs/conventions.md` 以 `rsync --ignore-existing` 一次性複製到目標專案 `docs/`，作為使用者之後客製的起點範本。此檔目前寫死 JS 風格（camelCase / kebab-case / JSDoc / 禁 console.log），但 common 會裝進所有 profile，與 python profile 的 `pytest_testing_style_guide.md`（snake_case / bare assert）矛盾。

## Goals / Non-Goals

**Goals:**
- 讓 `conventions.md` 語言中立，安裝後不與任何 profile 的語言專屬 rule 衝突。
- 保留它「可客製起點範本」的定位與既有四個 section 結構。

**Non-Goals:**
- 不新增 `python/docs/` 或 `node/docs/`（profile 不層疊 docs，且 docs 走 `--ignore-existing`，新增會增加複雜度）。
- 不改 install.sh 行為。
- 不動 git-commit-writer 版號標記、supabase 規則、.github 鏡像。

## Decisions

- **單檔就地改寫**，沿用原四個 section（Naming / Prohibited / Error Handling / Documentation）。語言差異用「Python / JS-TS」小對照表表達，而非各自獨立檔案 — 範本本就讓使用者裝完刪掉用不到的那欄。
- 通用原則（no hardcoded secrets、no logic-heavy constructors、Why-not-What 註解）原樣保留，只把語言專屬措辭中立化。

## Risks / Trade-offs

- 對照表同時列兩種語言，單一語言專案讀來略有冗餘 — 可接受，因為這是使用者裝完即客製的範本，且消除矛盾的價值遠大於冗餘成本。
- 既有已安裝專案不受影響（`--ignore-existing`），故無回溯遷移風險。
