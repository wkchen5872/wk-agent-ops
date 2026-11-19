# Proposal

## Why

交接迴圈目前只能用 Claude Code 與 Codex 擔任實作、審查、收尾角色。使用者也用 Pi 開發，而 Pi 的模型同時有訂閱登入
（例如 `openai-codex`）與 API key（例如 `openai`、`anthropic`）兩種來源，同一個模型 ID 可能出現在兩個 provider 底下
（`gpt-6.2-sol` 在 `openai` 與 `openai-codex` 都有）。自動接棒時沒有人盯著畫面，若角色在錯的 provider 或計費方式上啟動，
就會在使用者不知情時消耗錯的額度。

Xirp 已支援 `pi` harness（啟動選項有 `provider` 與 `thinking`），Pi 也提供不輸出 secret 的
`pi auth check --provider <p> --json`（回報 `authType`: `oauth` 或 `api_key`），所以現在可以把 Pi 接進迴圈並在每個關口驗證計費方式。

## What Changes

- **Pi 角色範本**：`roles.yaml` 的角色可設 `harness: pi`，且必須同時設 `provider`、`model`（該 provider 底下的精確模型 ID，
  不接受別名或模糊比對）、`effort`（Pi 的 thinking 等級）與 `billing`（`subscription` 或 `api`）。`provider`、`billing` 只限 Pi 角色。
- **一律停下的驗證**：模型 ID 在該 provider 下不存在、認證狀態不是 ready、`authType` 與宣告的 `billing` 對不上
  （`oauth` 對 `subscription`、`api_key` 對 `api`，其他認證方式一律視為對不上）、或 Session 實際的 provider、模型、effort
  與範本不同，都停下：
  - `handoff-start` 在開任何 Session 前驗證所有 Pi 角色，任何一個不通過就不開。
  - hook 開啟審查或收尾 Session 前再驗證一次；不通過就不開，通知使用者，交件單保留待重試。
  - 交件單由 Pi Session 寫下時記錄當下的 provider、模型、effort、計費方式與 Session ID；路由前與該角色範本比對，
    任何一項不同就不接棒，通知使用者。
- **以角色 worktree 的 Pi 設定開啟**：Xirp 目前不套用 Pi 1.x 的啟動選項，所以開 Pi 角色前在該角色的 worktree 寫入
  `.pi/settings.json`（provider、model、thinking），以 repo 本機的 exclude 忽略、不進 Git；一個 worktree 最多一個 Pi 角色，
  一個 Pi 角色可以和 Claude Code、Codex 角色共用 worktree。
- **只對交接 worktree 自動信任**：Pi 會在背景 Session 停在信任提示；Pi extension 只對「主 repo 已被使用者信任、且未被追蹤的
  `loop.yaml` 列為角色 worktree」的交接 worktree 回答信任，不保存決定。缺 extension 或主 repo 未被信任時，迴圈不開 Pi 角色。
- **Anthropic 訂閱只提醒**：Pi 角色宣告 `anthropic` + `subscription` 且實際為 `oauth` 時照常執行，但 `handoff-start`
  提醒可能使用付費的 extra usage。宣告與實際不一致時仍然停下。
- **不改動角色內的 subagent 機制**：pstack 在 Pi 上把模型別名解析成父 Session 同一個 provider 的模型，調高模型或 effort
  不會換 provider；本 change 不攔截或改寫 subagent 呼叫。會換 provider 的三種情況（明確指定別家 `provider/id`、
  `pstack-models.md` 的 `pi models:` 設定、父 provider 不在 pstack 對照表內而退回 anthropic）寫入文件作為已知限制。
  本 repo 的 `.claude/agents/`、`.codex/agents/` 定義在 Pi 上不會被讀取，不在本 change 範圍。
- **Pi 的停止觸發**：新增 Pi extension，在 Pi 確定不再自動續跑時（`agent_settled`）呼叫既有的 `handoff-route`；
  subagent 停下時不觸發；同一個 extension 負責上述的信任判斷。由 `scripts/handoff/install.sh` 安裝到 `~/.pi/agent/extensions/`。
- **其他配合**：`loop.yaml` 一併記錄實作範本；`handoff-start` 的覆寫參數支援 Pi；`handoff-author --tool Pi` 讀 `PI_SESSION_ID`；
  範例範本與文件說明 Pi 的 skill 呼叫語法 `/skill:<name>`；交件單通知的 Agent 資訊顯示 Pi 的 provider 與計費方式。

支援的 AI CLI：Claude Code、Codex（行為不變）、Pi（新增）。Antigravity 仍不在交接迴圈內。

驗收條件：

- Pi 角色宣告 `openai-codex` + `subscription`、實際為 `oauth` 時，迴圈照常開啟、交件、接棒。
- 宣告 `subscription` 但實際為 `api_key`（或反之）、模型不在該 provider 下、認證不是 ready，`handoff-start` 不開任何 Session 並說明哪一項對不上。
- Pi 角色中途用 `/model` 換了 provider、模型或 effort 後寫下交件單，hook 不接棒並通知使用者，交件單不再重複處理。
- hook 開啟 Pi 審查者前認證已改變時，不開 Session、通知使用者，修正後再次觸發會重試。
- Anthropic 訂閱宣告一致時迴圈照常，`handoff-start` 印出 extra usage 提醒。
- Claude Code 與 Codex 角色的迴圈行為與現在相同。

依賴：`add-handoff-notifications`（正在另一個 worktree 實作）大幅修改 `handoff-route` 與通知流程；本 change 在它封存後實作，
並沿用它的「人工停點」與「可重試失敗」分類與 Agent 資訊欄位。

## Capabilities

### New Capabilities

- `agent-handoff-pi`: Pi 角色的計費與模型驗證規則、Anthropic 提醒，以及 Pi 停止觸發。

### Modified Capabilities

- `agent-crew-launcher`: 範本支援 `harness: pi` 與 `provider`、`billing`；Session 以明確的 provider 開啟；覆寫參數支援 Pi；開始前驗證所有 Pi 角色。
- `agent-handoff-records`: Pi Session 寫下的交件單記錄 Agent 身分；`loop.yaml` 記錄實作範本；`handoff-author` 支援 Pi。
- `agent-handoff-routing`: Pi 停下時也會路由；Pi 交件單與範本不符時停下；hook 開啟 Pi 角色前驗證；installer 安裝 Pi extension。
- `agent-handoff-notifications`（由 `add-handoff-notifications` 新增）: Agent 資訊顯示 Pi 的 provider 與計費方式。

## Impact

- 程式：`scripts/handoff/lib/handoff.sh`（範本驗證、Pi 驗證、Xirp 開啟參數）、`scripts/handoff/handoff-start`、
  `scripts/handoff/handoff-route`、`scripts/handoff/handoff-cleanup`、`scripts/handoff/install.sh`、新增 `scripts/handoff/handoff-pi-trust`、新增 `scripts/handoff/pi/wk-handoff.ts`（Pi 停止觸發）、
  `template/common/skills/agent-handoff/scripts/{handoff-write,handoff-author}`、`roles.example.yaml`、`SKILL.md`。
- 測試：`tests/test_agent_handoff.sh`（假的 `pi` 與 `xirp`）。
- 文件：`scripts/handoff/README.md`、`docs/hooks/index.md`、`docs/skills/agent-handoff.md`。
- 依賴：Pi CLI（`pi auth check`、`pi --list-models`）、Xirp 的 `pi` harness。
- 使用者設定：`~/.pi/agent/extensions/` 新增一個檔案；`roles.yaml` 新增欄位（舊檔不受影響）；使用 Pi 角色的 repo 在
  `info/exclude` 加入 `/.pi/settings.json`，且主 worktree 需先在 Pi 執行過 `/trust`。
