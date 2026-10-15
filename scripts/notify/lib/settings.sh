#!/usr/bin/env bash
# Shared draft-only category editor; source config.sh first.

init_notify_draft() {
  NOTIFY_DRAFT=()
  local key
  for key in "${NOTIFY_CATEGORY_KEYS[@]}"; do
    NOTIFY_DRAFT+=("$(notify_category_value "${key}")")
  done
  NOTIFY_DRAFT_LEVEL="$(normalize_notify_level "${NOTIFY_LEVEL:-all}" 2>/dev/null || echo all)"
}

notify_switch_label() {
  if [[ "$1" == true ]]; then printf '開'; else printf '關'; fi
}

show_notify_draft() {
  printf '\n── 通知類型 ──────────────────────────\n'
  printf '共用事件\n'
  printf '  1  [%s] 工作結束\n' "$(notify_switch_label "${NOTIFY_DRAFT[0]}")"
  printf '  2  [%s] 既有操作提醒\n' "$(notify_switch_label "${NOTIFY_DRAFT[1]}")"
  printf '           包含 Codex PermissionRequest；自動審核也可能觸發\n'
  printf '  3  [%s] 異常停止（目前僅 Antigravity 提供訊號）\n' "$(notify_switch_label "${NOTIFY_DRAFT[2]}")"
  printf '\nCodex 專用（新增；hook 觸發按需檢查，不安裝常駐服務）\n'
  printf '  4  [%s] 等待你授權\n' "$(notify_switch_label "${NOTIFY_DRAFT[3]}")"
  printf '  5  [%s] 等待你回答（僅結構化問題）\n' "$(notify_switch_label "${NOTIFY_DRAFT[4]}")"
  printf '           同步等待需本機 daemon；非同步題目送出即提醒；一般文字問句不偵測\n'
}

show_notify_help() {
  printf '\n工作結束：各工具既有的完成事件；不保證整個專案所有工作均完成。\n'
  printf '既有操作提醒：沿用各工具現有映射，包含 Codex PermissionRequest。\n'
  printf '異常停止：目前依 Antigravity 的終止原因辨識，其他工具未提供對應訊號。\n'
  printf 'Codex 新項目：授權與同步問題讀取明確等待狀態；非同步題目成功送出即提醒。\n'
  printf '非同步提醒表示有題目待回覆，Codex 仍可繼續工作；不需 daemon 連線。\n'
  printf '同一 session 同段等待只提醒一次。hook 可啟動暫時檢查器，輪次結束退出。\n'
  printf '授權與同步問題需 Python 3、專用環境中的 websocket-client，以及既有 Codex daemon。\n'
  printf '啟用新項目時會部署檢查器與專用 Python 環境；不修改全域 Python。\n'
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
      1|2|3|4|5)
        index=$((choice - 1))
        if [[ "${NOTIFY_DRAFT[index]}" == true ]]; then NOTIFY_DRAFT[index]=false; else NOTIFY_DRAFT[index]=true; fi ;;
      h|H) show_notify_help ;;
      q|Q) echo '已取消，未儲存。'; return 1 ;;
      s|S)
        echo '── 儲存摘要 ──'
        show_notify_draft
        if [[ "${NOTIFY_DRAFT[3]}" == true || "${NOTIFY_DRAFT[4]}" == true ]]; then
          echo '將部署按需檢查器與專用 Python 環境；原本的授權流程不變。'
        fi
        if ! read -rp '儲存以上設定？[y/N]：' confirm; then return 1; fi
        [[ "${confirm}" =~ ^[Yy]$ ]] && return 0 ;;
      all|attention_required)
        NOTIFY_DRAFT_LEVEL="${choice}"
        NOTIFY_DRAFT[0]=true
        [[ "${choice}" == attention_required ]] && NOTIFY_DRAFT[0]=false
        NOTIFY_DRAFT[1]=true; NOTIFY_DRAFT[2]=true
        echo '── 儲存摘要：套用舊版預設；Codex 新項目維持原選擇 ──'
        show_notify_draft
        return 0 ;;
      *) echo '請輸入畫面上的編號或指令。' ;;
    esac
  done
}

save_notify_draft() {
  local i args=("$@" NOTIFY_LEVEL "${NOTIFY_DRAFT_LEVEL}")
  for ((i=0; i<${#NOTIFY_CATEGORY_KEYS[@]}; i++)); do
    args+=("${NOTIFY_CATEGORY_KEYS[i]}" "${NOTIFY_DRAFT[i]}")
  done
  update_config_keys "${args[@]}"
  for ((i=0; i<${#NOTIFY_CATEGORY_KEYS[@]}; i++)); do
    printf -v "${NOTIFY_CATEGORY_KEYS[i]}" '%s' "${NOTIFY_DRAFT[i]}"
  done
  NOTIFY_LEVEL="${NOTIFY_DRAFT_LEVEL}"
}
