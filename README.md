# Codex Pets X11 Fix

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
![Platform: Linux X11](https://img.shields.io/badge/platform-Linux%20%7C%20X11-blue)
![Tested: Arch + XFCE](https://img.shields.io/badge/tested-Arch%20%2B%20XFCE-1793d1)
![Status: Unofficial Workaround](https://img.shields.io/badge/status-unofficial%20workaround-orange)
![Shell: Bash](https://img.shields.io/badge/shell-Bash-4EAA25?logo=gnubash&logoColor=white)

[简体中文](./README.zh-CN.md)

Codex Pets X11 Fix is a local launcher and X11 input-region workaround for Codex Desktop pets on Linux/X11 desktops.

It was created for environments where the Codex Desktop pet/avatar overlay appears on screen but cannot be dragged or clicked correctly, especially on Arch Linux + X11 + XFCE.

## What It Does

- Starts Codex Desktop with a locally patched `app.asar`.
- Disables the pet overlay mouse passthrough behavior that can fail on X11 window managers.
- Uses the X11 Shape extension to shrink the overlay input area to the visible pet.
- Dynamically adds the working-status tray area to the input shape only while the tray is visible.
- Keeps the system Codex Desktop installation untouched.

## Compatibility

Tested with:

- Arch Linux
- X11 session
- XFCE / xfwm4
- Codex Desktop installed under `/usr/lib/openai-codex-desktop`
- Electron runtime at `/usr/lib/electron39/electron`

This project is intentionally conservative. It targets X11 behavior and does not claim Wayland support.

## Requirements

You need a working Codex Desktop installation and these command-line tools:

- `bash`
- `node`
- `asar`
- `gcc`
- `pkg-config`
- X11 development libraries: `x11`, `xext`
- Runtime tools: `jq`, `xprop`, `xwininfo`

## Build

Run the build script from the project root:

```bash
./scripts/build-codex-pets-x11-fix.sh
```

The script will:

1. Copy the official Codex Desktop `app.asar` from your local installation.
2. Apply a small runtime patch to the pet overlay manager.
3. Compile the X11 input-shape helper.
4. Generate a portable launcher under `bin/`.

## Run

After building:

```bash
./bin/codex-desktop-pets-fix
```

The generated `bin/` directory is portable on the same machine or on another compatible Linux/X11 machine with Codex Desktop and Electron installed in the same locations.

## Configuration

The input area includes a small padding around the pet so it is easier to grab. You can adjust it with:

```bash
CODEX_AVATAR_INPUT_PADDING=4 ./bin/codex-desktop-pets-fix
```

Use `0` for the tightest input area:

```bash
CODEX_AVATAR_INPUT_PADDING=0 ./bin/codex-desktop-pets-fix
```

## Generated Files

The build creates generated runtime files under `bin/`, including a patched `app.asar` copied from your local Codex Desktop installation.

Do not publish generated Codex Desktop runtime files to a public repository. This repository should only publish the scripts and source code needed to build the local workaround.

## How It Works

Codex Desktop stores the pet overlay bounds in its global state file. The watcher reads the current pet and tray rectangles, finds the matching X11 overlay window, and applies an X11 `ShapeInput` region.

When the tray is hidden, only the pet area receives pointer events. When the tray is visible, the tray rectangle is temporarily added as a second input region.

## Limitations

- This is an unofficial workaround.
- It depends on the current minified Codex Desktop main bundle shape.
- A Codex Desktop update may require rebuilding or adjusting the patch strings.
- It does not modify or replace the system Codex Desktop installation.
- It does not provide or redistribute Codex Desktop itself.

## License

See [LICENSE](./LICENSE).

## Disclaimer

This project is not affiliated with, endorsed by, or sponsored by OpenAI. "Codex" and related product names belong to their respective owners.
