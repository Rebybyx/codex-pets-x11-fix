#!/usr/bin/env bash
# 2026-05-15, 苍朮：生成 Codex Desktop pet overlay 的 X11 修复版启动器。
# 用途：复制官方 app.asar 到本工作目录，给 avatar overlay 的鼠标穿透和命中区域逻辑加环境变量开关。
# 参数：无；依赖 /usr/bin/asar 与 /usr/lib/electron39/electron。
# 返回值：在仓库根目录生成 codex-desktop-pets-fix 可执行启动器。
set -euo pipefail

# 2026-05-15, 苍朮：解析当前项目根目录。
# 用途：让构建脚本脱离临时对话目录，可在迁移后的固定项目中运行。
# 参数说明：无。
# 返回值：通过 ROOT 变量提供项目根目录。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APPDIR="/usr/lib/openai-codex-desktop"
ELECTRON="/usr/lib/electron39/electron"
BIN_DIR="${ROOT}/bin"
RUNTIME_DIR="${BIN_DIR}/.runtime"
WORKDIR="${RUNTIME_DIR}/build"
EXTRACTED="${WORKDIR}/app"
PATCHED_ASAR="${RUNTIME_DIR}/app-pets-x11-fix.asar"
SHAPE_HELPER="${RUNTIME_DIR}/codex-pets-x11-input-shape"
LAUNCHER="${BIN_DIR}/codex-desktop-pets-fix"
WATCHER="${BIN_DIR}/codex-pets-shape-watcher.sh"
SHAPE_SOURCE="${BIN_DIR}/codex-pets-x11-input-shape.c"

[[ -x "${ELECTRON}" ]] || {
  echo "Missing Electron runtime: ${ELECTRON}" >&2
  exit 1
}

[[ -f "${APPDIR}/resources/app.asar" ]] || {
  echo "Missing Codex app.asar: ${APPDIR}/resources/app.asar" >&2
  exit 1
}

command -v asar >/dev/null || {
  echo "Missing asar command" >&2
  exit 1
}

command -v gcc >/dev/null || {
  echo "Missing gcc command" >&2
  exit 1
}

rm -rf "${EXTRACTED}"
mkdir -p "${WORKDIR}" "${BIN_DIR}" "${RUNTIME_DIR}"
asar extract "${APPDIR}/resources/app.asar" "${EXTRACTED}"

MAIN_JS="$(find "${EXTRACTED}/.vite/build" -maxdepth 1 -type f -name 'main-*.js' | head -n 1)"
[[ -n "${MAIN_JS}" ]] || {
  echo "Unable to find extracted main bundle" >&2
  exit 1
}

node - "${MAIN_JS}" <<'NODE'
const fs = require("node:fs");
const mainPath = process.argv[2];
let source = fs.readFileSync(mainPath, "utf8");
const passthroughOriginal = "let t=!this.pointerInteractive;if(this.mousePassthroughEnabled!==t){if(this.mousePassthroughEnabled=t,t){e.setIgnoreMouseEvents(!0,{forward:!0});return}e.setIgnoreMouseEvents(!1),this.refreshCursorAtCurrentMousePosition(e)}}";
const passthroughPatched = "let t=process.env.CODEX_DISABLE_AVATAR_MOUSE_PASSTHROUGH===`1`?!1:!this.pointerInteractive;if(this.mousePassthroughEnabled!==t){if(this.mousePassthroughEnabled=t,t){e.setIgnoreMouseEvents(!0,{forward:!0});return}e.setIgnoreMouseEvents(!1),this.refreshCursorAtCurrentMousePosition(e)}}";
const persistOriginal = "e.isDestroyed()||this.globalState.set(Ee,{...e.getContentBounds(),anchor:this.anchor,mascot:this.layout?.mascot,placement:this.placement,tray:this.layout?.tray})}";
const persistPatched = "e.isDestroyed()||this.globalState.set(Ee,{...e.getContentBounds(),anchor:this.anchor,mascot:this.layout?.mascot,placement:this.placement,tray:this.layout?.tray,isTrayVisible:this.isTrayVisible===!0})}";
const avatarBoundsSchemaOriginal = "tray:Me.nullable().optional()})";
const avatarBoundsSchemaPatched = "tray:Me.nullable().optional(),isTrayVisible:e.gr.boolean().optional()})";

/*
 * 2026-05-16, 苍朮：执行一次精确替换并给出可定位错误。
 * 用途：Codex Desktop 更新后，构建脚本能明确指出是哪一个补丁锚点漂移。
 * 参数说明：name 为锚点名称，original 为旧片段，patched 为新片段。
 * 返回值：无；直接更新外层 source。
 */
function replaceOnce(name, original, patched) {
  if (!source.includes(original)) {
    throw new Error(`Target avatar overlay ${name} code was not found.`);
  }
  source = source.replace(original, patched);
}

/*
 * 2026-05-16, 苍朮：给新版 setElementSize 注入托盘可见状态持久化。
 * 用途：保留官方新增的 mascot resize 防抖逻辑，只追加 isTrayVisible 和 persistWindowBounds。
 * 参数说明：无，读写外层 source。
 * 返回值：无；找不到预期锚点时抛出错误。
 */
function patchElementSize() {
  const signatureOriginal = "setElementSize(e,{mascot:t,tray:n})";
  const signaturePatched = "setElementSize(e,{isTrayVisible:i,mascot:t,tray:n})";
  if (!source.includes(signatureOriginal)) {
    throw new Error("Target avatar overlay element-size signature was not found.");
  }
  source = source.replace(signatureOriginal, signaturePatched);

  const methodStart = source.indexOf(signaturePatched);
  const methodEnd = source.indexOf("async ensureWindow()", methodStart);
  if (methodStart < 0 || methodEnd < 0) {
    throw new Error("Target avatar overlay element-size method boundary was not found.");
  }

  let methodSource = source.slice(methodStart, methodEnd);
  const guardOriginal = "if(!(r==null||r.isDestroyed()||r.webContents.id!==e)){";
  const guardPatched = `${guardOriginal}this.isTrayVisible=i===!0;`;
  if (!methodSource.includes(guardOriginal)) {
    throw new Error("Target avatar overlay element-size window guard was not found.");
  }
  methodSource = methodSource.replace(guardOriginal, guardPatched);

  const applyLayoutOriginal = "this.mascotSize=t,this.traySize=n,this.applyLayout(r)";
  const applyLayoutPatched = "this.mascotSize=t,this.traySize=n,this.applyLayout(r),this.persistWindowBounds(r)";
  if (!methodSource.includes(applyLayoutOriginal)) {
    throw new Error("Target avatar overlay element-size applyLayout code was not found.");
  }
  methodSource = methodSource.replace(applyLayoutOriginal, applyLayoutPatched);

  source = source.slice(0, methodStart) + methodSource + source.slice(methodEnd);
}

replaceOnce("mouse passthrough", passthroughOriginal, passthroughPatched);
patchElementSize();
replaceOnce("persist", persistOriginal, persistPatched);
replaceOnce("bounds schema", avatarBoundsSchemaOriginal, avatarBoundsSchemaPatched);

fs.writeFileSync(mainPath, source, "utf8");
NODE

asar pack "${EXTRACTED}" "${PATCHED_ASAR}"
gcc "${ROOT}/scripts/codex-pets-x11-input-shape.c" -o "${SHAPE_HELPER}" $(pkg-config --cflags --libs x11 xext)
cp "${ROOT}/scripts/codex-pets-shape-watcher.sh" "${WATCHER}"
cp "${ROOT}/scripts/codex-pets-x11-input-shape.c" "${SHAPE_SOURCE}"
chmod +x "${WATCHER}"
rm -rf "${WORKDIR}"

cat >"${LAUNCHER}" <<EOF
#!/usr/bin/env bash
# 2026-05-15, 苍朮：启动启用 pet overlay X11 鼠标命中修复的 Codex Desktop。
# 用途：复用官方 Arch 启动流程，但加载当前 bin 目录里的 patched app.asar。
# 参数：透传给 Codex Desktop。
set -euo pipefail

appdir="${APPDIR}"
electron="${ELECTRON}"
webview_dir="\${appdir}/content/webview"

# 2026-05-15, 苍朮：解析可搬迁 bin 目录。
# 用途：让启动器复制到其他目录后仍能找到同目录下的运行资产。
# 参数说明：无。
# 返回值：通过 bin_dir/runtime_dir 等变量提供运行路径。
bin_dir="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
runtime_dir="\${bin_dir}/.runtime"
patched_asar="\${runtime_dir}/app-pets-x11-fix.asar"
shape_watcher="\${bin_dir}/codex-pets-shape-watcher.sh"
user_flags=()

[[ -x "\${electron}" ]] || {
  echo "Missing Electron runtime: \${electron}" >&2
  exit 1
}

[[ -f "\${patched_asar}" ]] || {
  echo "Missing patched Codex app: \${patched_asar}" >&2
  exit 1
}

[[ -x "\${shape_watcher}" ]] || {
  echo "Missing shape watcher: \${shape_watcher}" >&2
  exit 1
}

config_home="\${XDG_CONFIG_HOME:-}"
if [[ -z "\${config_home}" && -n "\${HOME:-}" ]]; then
  config_home="\${HOME}/.config"
fi

if [[ -n "\${config_home}" && -f "\${config_home}/codex-flags.conf" ]]; then
  while IFS= read -r flag_line || [[ -n "\${flag_line}" ]]; do
    flag_line="\${flag_line%%#*}"
    read -r -a flag_parts <<<"\${flag_line}"
    user_flags+=("\${flag_parts[@]}")
  done <"\${config_home}/codex-flags.conf"
fi

export CODEX_DISABLE_AVATAR_MOUSE_PASSTHROUGH=1
export CODEX_AVATAR_INPUT_PADDING="\${CODEX_AVATAR_INPUT_PADDING:-8}"
export CODEX_CLI_PATH="\${CODEX_CLI_PATH:-\$(command -v codex || true)}"
export BUILD_FLAVOR="\${BUILD_FLAVOR:-prod}"
export NODE_ENV="\${NODE_ENV:-production}"
export ELECTRON_RENDERER_URL="\${ELECTRON_RENDERER_URL:-http://localhost:5175/}"

http_pid=""
electron_pid=""
shape_pid=""
tmpdir=""

cleanup() {
  [[ -n "\${shape_pid}" ]] && kill "\${shape_pid}" 2>/dev/null || true
  [[ -n "\${shape_pid}" ]] && wait "\${shape_pid}" 2>/dev/null || true
  [[ -n "\${electron_pid}" ]] && wait "\${electron_pid}" 2>/dev/null || true
  [[ -n "\${http_pid}" ]] && kill "\${http_pid}" 2>/dev/null || true
  [[ -n "\${http_pid}" ]] && wait "\${http_pid}" 2>/dev/null || true
  [[ -n "\${tmpdir}" ]] && rm -rf "\${tmpdir}"
}

forward_signal() {
  local sig="\$1"
  if [[ -n "\${electron_pid}" ]] && kill -0 "\${electron_pid}" 2>/dev/null; then
    kill -"\${sig}" "\${electron_pid}" 2>/dev/null || true
    wait "\${electron_pid}" 2>/dev/null || true
  fi
  exit 0
}

trap cleanup EXIT
trap 'forward_signal HUP' HUP
trap 'forward_signal INT' INT
trap 'forward_signal TERM' TERM

if [[ -d "\${webview_dir}" ]] && find "\${webview_dir}" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
  tmpdir="\$(mktemp -d)"
  ready_file="\${tmpdir}/ready"
  fail_file="\${tmpdir}/fail"

  python - 5175 "\${webview_dir}" "\${ready_file}" "\${fail_file}" >/dev/null 2>&1 <<'PY' &
import http.server
import os
import socketserver
import sys

port = int(sys.argv[1])
root = sys.argv[2]
ready_file = sys.argv[3]
fail_file = sys.argv[4]

os.chdir(root)

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

class TCPServer(socketserver.TCPServer):
    allow_reuse_address = True

try:
    with TCPServer(("127.0.0.1", port), Handler) as httpd:
        with open(ready_file, "w") as f:
            f.write("ok")
        httpd.serve_forever()
except Exception as e:
    with open(fail_file, "w") as f:
        f.write(str(e))
    raise
PY
  http_pid=\$!

  for _ in {1..50}; do
    [[ -f "\${ready_file}" ]] && break
    if [[ -f "\${fail_file}" ]]; then
      echo "Failed to start local webview server on 127.0.0.1:5175" >&2
      cat "\${fail_file}" >&2
      exit 1
    fi
    kill -0 "\${http_pid}" 2>/dev/null || {
      echo "Local webview server exited before becoming ready" >&2
      exit 1
    }
    sleep 0.1
  done

  [[ -f "\${ready_file}" ]] || {
    echo "Timed out waiting for local webview server on 127.0.0.1:5175" >&2
    exit 1
  }
fi

"\${electron}" \\
  --enable-sandbox \\
  --ozone-platform-hint=auto \\
  --class=Codex \\
  "\${user_flags[@]}" \\
  "\${patched_asar}" \\
  "\$@" &
electron_pid=\$!
"\${shape_watcher}" "\${electron_pid}" >/dev/null 2>&1 &
shape_pid=\$!
wait "\${electron_pid}"
EOF

chmod +x "${LAUNCHER}"

echo "Patched asar: ${PATCHED_ASAR}"
echo "Shape helper: ${SHAPE_HELPER}"
echo "Launcher: ${LAUNCHER}"
