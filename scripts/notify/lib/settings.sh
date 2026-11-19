#!/usr/bin/env bash
# Shared draft-only category editor; source config.sh first.

init_notify_draft() {
  NOTIFY_DRAFT=()
  local key
  # Indexes 0-3 are the four categories, 4-6 the handoff progress switches.
  for key in "${NOTIFY_CATEGORY_KEYS[@]}" "${NOTIFY_HANDOFF_KEYS[@]}"; do
    NOTIFY_DRAFT+=("$(notify_category_value "${key}")")
  done
  NOTIFY_DRAFT_LEVEL="$(normalize_notify_level "${NOTIFY_LEVEL:-all}" 2>/dev/null || echo all)"
}

notify_switch_label() {
  if [[ "$1" == true ]]; then printf '開'; else printf '關'; fi
}

notify_authorization_delay() {
  local value="${NOTIFY_AUTHORIZATION_DELAY_SECONDS:-}"
  [[ "${value}" =~ ^[0-9]+$ ]] && printf '%s' "$((10#${value}))" || printf '30'
}

show_notify_draft() {
  printf '\n── 通知類型 ──────────────────────────\n'
  printf '  1  [%s] 工作結束\n' "$(notify_switch_label "${NOTIFY_DRAFT[0]}")"
  printf '  2  [%s] 授權要求\n' "$(notify_switch_label "${NOTIFY_DRAFT[1]}")"
  printf '           Agent 仍在等待授權 %s 秒後才通知；自動審核放行的請求不通知\n' "$(notify_authorization_delay)"
  printf '  3  [%s] 等待回應\n' "$(notify_switch_label "${NOTIFY_DRAFT[2]}")"
  printf '           Agent 提問、等待你輸入時立即通知\n'
  printf '  4  [%s] 異常停止（Antigravity、Pi 提供訊號）\n' "$(notify_switch_label "${NOTIFY_DRAFT[3]}")"
  printf '\n── 交接迴圈 ──────────────────────────\n'
  printf '  5  [%s] 交件單實作完成\n' "$(notify_switch_label "${NOTIFY_DRAFT[4]}")"
  printf '  6  [%s] 交件單每輪審查\n' "$(notify_switch_label "${NOTIFY_DRAFT[5]}")"
  printf '  7  [%s] 交件單收尾\n' "$(notify_switch_label "${NOTIFY_DRAFT[6]}")"
  printf '           「需要你處理」（迴圈停下等你）一律送出，不受開關影響\n'
}

show_notify_help() {
  printf '\n工作結束：各工具既有的完成事件；不保證整個專案所有工作均完成。\n'
  printf '授權要求：Claude Code、Codex、Antigravity 提出授權後，延遲 %s 秒仍在等才通知，\n' "$(notify_authorization_delay)"
  printf '          同一段等待只通知一次。延遲由 NOTIFY_AUTHORIZATION_DELAY_SECONDS 設定，0 為立即。\n'
  printf '          Codex 無法查詢執行狀態時，改發「Approval Status Unknown」（可能在等待授權，無法確認）的通知。\n'
  printf '等待回應：Claude 的提問與等待輸入、Codex 的結構化問題；一般文字問句不偵測。\n'
  printf '異常停止：依 Antigravity 與 Pi 的錯誤／終止原因辨識，其他工具未提供對應訊號。\n'
  printf '交件單：交接迴圈的實作完成、每輪審查與收尾進度，缺少設定時為開；「需要你處理」一律送出。\n'
  printf 'Codex 的授權與同步問題由 hook 觸發的暫時檢查器判斷，輪次結束即退出；\n'
  printf '需要 Python 3 與專用環境中的 websocket-client，不修改全域 Python。\n'
  printf '若介面或 hook 不支援，狀態畫面會列出限制；勾選不等於已實測可用。\n'
}

edit_notify_types() {
  init_notify_draft
  local choice confirm index
  while true; do
    show_notify_draft
    printf '\n輸入編號切換；h 說明；s 儲存；q 放棄\n'
    printf '舊版快速預設：all / attention_required（選取即確認此預設）\n'
    if ! read -rp '選擇：' choice; then echo '已取消，未儲存。'; return 1; fi
    case "${choice}" in
      1|2|3|4|5|6|7)
        index=$((choice - 1))
        if [[ "${NOTIFY_DRAFT[index]}" == true ]]; then NOTIFY_DRAFT[index]=false; else NOTIFY_DRAFT[index]=true; fi ;;
      h|H) show_notify_help ;;
      q|Q) echo '已取消，未儲存。'; return 1 ;;
      s|S)
        echo '── 儲存摘要 ──'
        show_notify_draft
        if [[ "${NOTIFY_DRAFT[1]}" == true || "${NOTIFY_DRAFT[2]}" == true ]]; then
          echo '將部署 Codex 按需檢查器與專用 Python 環境；原本的授權流程不變。'
        fi
        if ! read -rp '儲存以上設定？[y/N]：' confirm; then return 1; fi
        [[ "${confirm}" =~ ^[Yy]$ ]] && return 0 ;;
      all|attention_required)
        NOTIFY_DRAFT_LEVEL="${choice}"
        # A level only defines completion; the other switches keep their state.
        NOTIFY_DRAFT[0]=true
        [[ "${choice}" == attention_required ]] && NOTIFY_DRAFT[0]=false
        echo '── 儲存摘要：套用層級預設；只改變工作結束 ──'
        show_notify_draft
        return 0 ;;
      *) echo '請輸入畫面上的編號或指令。' ;;
    esac
  done
}

# Writes the category and handoff keys and retires the legacy ones in one atomic write.
save_notify_draft() {
  local i keys=("${NOTIFY_CATEGORY_KEYS[@]}" "${NOTIFY_HANDOFF_KEYS[@]}") args=("$@" NOTIFY_LEVEL "${NOTIFY_DRAFT_LEVEL}")
  for ((i=0; i<${#keys[@]}; i++)); do
    args+=("${keys[i]}" "${NOTIFY_DRAFT[i]}")
  done
  update_config_keys_dropping "${NOTIFY_LEGACY_CATEGORY_KEYS[*]}" "${args[@]}"
  for ((i=0; i<${#keys[@]}; i++)); do
    printf -v "${keys[i]}" '%s' "${NOTIFY_DRAFT[i]}"
  done
  NOTIFY_LEVEL="${NOTIFY_DRAFT_LEVEL}"
}
