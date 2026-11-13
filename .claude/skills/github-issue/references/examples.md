# github-issue 範例

以下範例只示範 managed 區塊內受影響的區段；完整範本與欄位語意見
`docs/github-handoff.md` 第 6.1 節。範例中的編號、日期與帳號都是虛構的。

## 一個目標拆成多個 Change

父 Issue 追蹤整體目標，每個子 Change 一行，連到它自己的 Issue 或 PR：

```markdown
### Relations
- parent: none
- child: add-export → https://github.com/acme/widgets/issues/7
- child: add-import → https://github.com/acme/widgets/issues/21
```

子 Issue 指回父項，並寫出依賴的**解除條件**。只寫「等 #7」不夠，接手的人需要知道
等的是批准、合併、部署，還是驗收：

```markdown
### Relations
- parent: https://github.com/acme/widgets/issues/20
- depends-on: https://github.com/acme/widgets/issues/7 · release: merge · 匯入沿用匯出的檔案格式
```

`release` 只使用 `design-approval`、`merge`、`deployment`、`acceptance`。

## 等待真實資料

實作已合併並部署，但驗收需要一段時間的實際資料：

```markdown
- owner: octo-dev
- next-action: 2026-12-01 之後依驗收條件檢查匯出紀錄（octo-dev）

### Waiting
- started: PR #12 合併並部署，head a1b2c3d
- earliest-check: 2026-12-01T09:00:00+08:00
- data-window: 部署後連續 14 天的匯出紀錄
- acceptance: 每日匯出筆數與來源一致，無失敗批次 · evidence: docs/verification/add-export/
- delivery-status: 已合併並部署 · acceptance-status: pending
```

`earliest-check` 是最早可以檢查的時間。時間到了要做的是「依驗收條件檢查資料」，
不是關閉 Issue；有證據後才把 `acceptance-status` 改為 `passed` 或 `failed`。
關閉 Issue 另需使用者授權。

## 首次接管既有正文

Issue 原本由人撰寫、沒有標記。只有在使用者明確要求採用區塊時才加入，而且把區塊
**附加在原文之後**，原文一字不改：

```markdown
匯出功能的需求整理（原作者的文字，維持原樣）

- 需要支援 CSV
- 檔名要帶日期

<!-- wk-agent-ops:handoff:start -->
## Handoff

- openspec-change: add-export
- repository: github.com/acme/widgets
…
<!-- wk-agent-ops:handoff:end -->
```

之後的更新只動標記之間的內容。標記缺少、只有一半或出現多組時，先回報，不猜測。
