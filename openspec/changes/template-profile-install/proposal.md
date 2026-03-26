## Why

`template/` 目前是扁平結構，`install.sh` 會把所有內容無差別地複製到目標專案。當未來加入 Python、Node.js 的 coding style rules 和 git hooks 後，一個純 Python 專案會被裝到 Node.js 的規範，反之亦然。

需要一個 **profile-based** 的結構，讓 install 時可以選擇只裝「這個專案需要的部分」。

## What Changes

- 重組 `template/` 目錄為 `common/`、`python/`、`node/` 三個 profile
- 現有 `template/` 的所有內容移至 `template/common/`（language-agnostic）
- 新增 `template/python/`：Python coding style rules、pre-commit lint hook
- 新增 `template/node/`：Node.js coding style rules、pre-commit lint hook
- `install.sh` 支援 profile 參數：`bash install.sh [python] [node]`，預設只裝 common
- 新增 `docs/template-profiles.md`：說明整體結構與 install 用法

## Capabilities

### New Capabilities
- `template-profile-structure`: template/ 目錄的 profile-based 組織結構定義
- `install-profile-cli`: install.sh 的 profile 參數介面與安裝邏輯

### Modified Capabilities
- 無 spec-level requirement 異動

## Impact

- `template/` 目錄結構重組（現有檔案全部移動，內容不變）
- `scripts/skills/install.sh` 改寫
- 新增 `docs/template-profiles.md`
- 不影響已安裝至其他專案的內容（裝過的不會自動更新）
