#!/usr/bin/env bash
# Deployment is explicit; sourcing this library never changes machine state.

NOTIFY_SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

deploy_notify_files() {
  local root="${HOME}/.config/ai-notify"
  mkdir -p "${root}/hooks" "${root}/lib"
  cp "${NOTIFY_SOURCE_ROOT}/telegram/hook.sh" "${root}/hooks/telegram-notify.sh"
  cp "${NOTIFY_SOURCE_ROOT}/lib/config.sh" "${root}/lib/config.sh"
  cp "${NOTIFY_SOURCE_ROOT}/codex/wait.py" "${root}/hooks/codex-wait.py"
  cp "${NOTIFY_SOURCE_ROOT}/codex/requirements.txt" "${root}/hooks/codex-wait-requirements.txt"
  chmod +x "${root}/hooks/telegram-notify.sh"
  rm -f -- "${root}/state/codex-disabled"
}

codex_inspection_selected() {
  notify_category_enabled NOTIFY_CODEX_HUMAN_APPROVAL || notify_category_enabled NOTIFY_CODEX_USER_INPUT
}

ensure_codex_runtime() {
  codex_inspection_selected || return 0
  local runtime="${HOME}/.config/ai-notify/runtime/codex-wait"
  local python="${runtime}/bin/python3"
  if [[ -x "${python}" ]] && "${python}" -c 'import websocket, fcntl; assert websocket.__version__ == "1.9.0"' >/dev/null 2>&1; then
    return 0
  fi
  echo '  ℹ 安裝 Codex 按需檢查依賴：專用 Python 環境與 websocket-client；不安裝常駐服務。'
  if ! command -v python3 >/dev/null 2>&1; then
    echo '  ⚠ 缺少 Python 3；新等待通知目前不可用，既有通知不受影響。' >&2
    return 1
  fi
  if ! python3 -m venv "${runtime}" >/dev/null 2>&1; then
    echo '  ⚠ 無法建立專用 Python 環境；新等待通知目前不可用。' >&2
    return 1
  fi
  if ! "${python}" -m pip install --disable-pip-version-check -r "${HOME}/.config/ai-notify/hooks/codex-wait-requirements.txt" >/dev/null 2>&1 ||
     ! "${python}" -c 'import websocket, fcntl; assert websocket.__version__ == "1.9.0"' >/dev/null 2>&1; then
    echo '  ⚠ Codex 檢查依賴安裝失敗；可用 fix-hooks 重試，既有通知不受影響。' >&2
    return 1
  fi
  echo '  ✓ Codex 按需檢查依賴已就緒。'
}

show_codex_wait_status() {
  local root="${HOME}/.config/ai-notify" python result
  python="${root}/runtime/codex-wait/bin/python3"
  echo ''
  echo '── Codex 人工等待通知 ──'
  echo '執行方式：hook 觸發、按需啟動；沒有 LaunchAgent 或登入服務。'
  echo '範圍：授權與同步問題需本機 daemon；非同步題目依成功送出通知；一般文字問句不偵測。'
  if ! codex_inspection_selected; then
    echo '設定：兩項新通知皆關閉，不會查看 daemon。'
    return 0
  fi
  if [[ ! -f "${root}/hooks/codex-wait.py" ]]; then
    echo '檢查器：未部署；請執行 fix-hooks。'; return 0
  fi
  if [[ ! -x "${python}" ]] || ! "${python}" -c 'import websocket, fcntl' >/dev/null 2>&1; then
    echo '依賴：未就緒；請執行 fix-hooks。'; return 0
  fi
  echo '檢查器與依賴：已部署；未執行時可能只是尚未收到相關 hook。'
  result="$("${python}" "${root}/hooks/codex-wait.py" probe 2>/dev/null)" || result='{}'
  if printf '%s' "${result}" | jq -e '.available == true' >/dev/null 2>&1; then
    echo 'daemon：唯讀連線可用。'
  else
    echo 'daemon：不可用或協定不支援；不會推測人工等待。'
  fi
  echo '本機端到端驗收：尚未記錄；設定開啟不代表人工授權／問題 hook 已實測。'
  echo '另需在 Codex /hooks 信任並勾選 owned hooks；此處無法讀取該啟用狀態。'
}

remove_codex_notify_runtime() {
  local root="${HOME}/.config/ai-notify" python
  # Let workers observe disabled categories before removing their scripts.
  update_config_keys NOTIFY_CODEX_HUMAN_APPROVAL false NOTIFY_CODEX_USER_INPUT false
  python="${root}/runtime/codex-wait/bin/python3"
  [[ -x "${python}" ]] || python="$(command -v python3 || true)"
  if [[ -n "${python}" && -f "${root}/hooks/codex-wait.py" ]]; then
    if ! "${python}" "${root}/hooks/codex-wait.py" stop >/dev/null 2>&1; then
      echo '⚠ 按需檢查器仍在退出中；保留檔案，請稍後重試解除安裝。' >&2
      return 1
    fi
  fi
  rm -f -- "${root}/hooks/codex-wait.py" "${root}/hooks/codex-wait-requirements.txt"
  rm -rf -- "${root}/runtime/codex-wait"
  rm -f -- "${root}/state/codex-disabled"
}
