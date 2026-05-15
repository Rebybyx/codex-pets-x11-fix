#!/usr/bin/env bash
# 2026-05-15, 苍朮：跟随 Codex pet 浮窗并持续设置 X11 输入命中区域。
# 用途：读取 Codex 全局状态里的 mascot 矩形，把 Electron overlay 的可点击范围缩小。
# 参数：第一个参数为 Electron 主进程 pid；可通过 CODEX_AVATAR_INPUT_PADDING 设置边距。
# 返回值：进程持续运行；目标 pid 退出后自然退出。
set -euo pipefail

electron_pid="${1:-}"
padding="${CODEX_AVATAR_INPUT_PADDING:-8}"
state_file="${CODEX_HOME:-$HOME/.codex}/.codex-global-state.json"

# 2026-05-15, 苍朮：解析 watcher 所在目录与 helper 路径。
# 用途：让 watcher 跟随 bin 目录迁移，不依赖临时对话目录。
# 参数说明：无。
# 返回值：通过 script_dir 和 shape_helper 变量提供运行路径。
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shape_helper="${script_dir}/.runtime/codex-pets-x11-input-shape"

if [[ -z "${electron_pid}" ]]; then
  echo "Missing Electron pid." >&2
  exit 2
fi

if [[ ! -x "${shape_helper}" ]]; then
  echo "Missing shape helper: ${shape_helper}" >&2
  exit 2
fi

# 这段是 shell 脚本，下面用函数注释承接 AGENTS 的“协商式注释”约束。

# 2026-05-15, 苍朮：寻找当前 Codex avatar overlay 的 X11 window id。
# 用途：只匹配指定 Electron pid 下 WM_CLASS 为 codex/Codex 且可见的浮窗。
# 参数说明：无，依赖外层 electron_pid。
# 返回值：stdout 输出 window id；找不到时输出空。
find_overlay_window_id() {
  local id
  while read -r id _; do
    [[ -n "${id}" ]] || continue
    xprop -id "${id}" _NET_WM_PID WM_CLASS 2>/dev/null |
      awk -v pid="${electron_pid}" '
        /_NET_WM_PID/ { has_pid = ($NF == pid) }
        /WM_CLASS/ { has_class = ($0 ~ /"codex", "Codex"/) }
        END { exit !(has_pid && has_class) }
      ' || continue
    xwininfo -id "${id}" 2>/dev/null | awk '/Map State:/ { exit !($0 ~ /IsViewable/) }' || continue
    printf '%s\n' "${id}"
    return 0
  done < <(xwininfo -root -children 2>/dev/null | awk '/"Codex"/ {print $1, $0}')
}

# 2026-05-15, 苍朮：从 Codex 全局状态读取当前应开放的命中矩形。
# 用途：默认只跟随宠物本体；通知托盘真正可见时再追加托盘区域。
# 参数说明：无，依赖外层 state_file。
# 返回值：stdout 输出一行或多行 left top width height；缺失时返回非 0。
read_hit_rects() {
  [[ -f "${state_file}" ]] || return 1
  jq -r '
    ."electron-avatar-overlay-bounds" as $bounds
    | select($bounds.mascot != null)
    | (
        [$bounds.mascot.left, $bounds.mascot.top, $bounds.mascot.width, $bounds.mascot.height],
        (
          if $bounds.isTrayVisible == true and $bounds.tray != null then
            [$bounds.tray.left, $bounds.tray.top, $bounds.tray.width, $bounds.tray.height]
          else empty end
        )
      )
    | @tsv
  ' "${state_file}" 2>/dev/null
}

while kill -0 "${electron_pid}" 2>/dev/null; do
  window_id="$(find_overlay_window_id || true)"
  rects="$(read_hit_rects || true)"
  if [[ -n "${window_id}" && -n "${rects}" ]]; then
    args=("${window_id}" "${padding}")
    while read -r left top width height; do
      [[ -n "${left:-}" && -n "${top:-}" && -n "${width:-}" && -n "${height:-}" ]] || continue
      args+=("${left}" "${top}" "${width}" "${height}")
    done <<<"${rects}"
    if [[ "${#args[@]}" -gt 2 ]]; then
      "${shape_helper}" "${args[@]}" 2>/dev/null || true
    fi
  fi
  sleep 0.25
done
