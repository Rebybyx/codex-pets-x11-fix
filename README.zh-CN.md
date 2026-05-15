# Codex Pets X11 Fix

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
![Platform: Linux X11](https://img.shields.io/badge/platform-Linux%20%7C%20X11-blue)
![Tested: Arch + XFCE](https://img.shields.io/badge/tested-Arch%20%2B%20XFCE-1793d1)
![Status: Unofficial Workaround](https://img.shields.io/badge/status-unofficial%20workaround-orange)
![Shell: Bash](https://img.shields.io/badge/shell-Bash-4EAA25?logo=gnubash&logoColor=white)

[English](./README.md)

Codex Pets X11 Fix 是一个面向 Linux/X11 桌面的 Codex Desktop 宠物浮窗修复工具。

它主要解决这类问题：Codex Desktop 的 pet/avatar overlay 能显示在屏幕上，但在 Arch Linux + X11 + XFCE 等环境里无法正确拖动、点击，或者点击区域异常。

## 它做了什么

- 用本地 patched `app.asar` 启动 Codex Desktop。
- 禁用在部分 X11 窗口管理器下失效的宠物浮窗鼠标穿透逻辑。
- 使用 X11 Shape 扩展，把浮窗可点击区域缩到宠物本体附近。
- 工作状态提示框/托盘显示时，动态追加托盘可点击区域。
- 不修改系统安装目录里的 Codex Desktop。

## 兼容性

当前已在以下环境验证：

- Arch Linux
- X11 会话
- XFCE / xfwm4
- Codex Desktop 安装在 `/usr/lib/openai-codex-desktop`
- Electron runtime 位于 `/usr/lib/electron39/electron`

这个项目是一个保守的 X11 兼容性修复，不声明支持 Wayland。

## 依赖

你需要先有可运行的 Codex Desktop，并准备这些命令行工具：

- `bash`
- `node`
- `asar`
- `gcc`
- `pkg-config`
- X11 开发库：`x11`、`xext`
- 运行时工具：`jq`、`xprop`、`xwininfo`

## 构建

在项目根目录执行：

```bash
./scripts/build-codex-pets-x11-fix.sh
```

构建脚本会：

1. 从本机 Codex Desktop 安装目录复制官方 `app.asar`。
2. 给 pet overlay manager 注入一个小的运行时补丁。
3. 编译 X11 input shape helper。
4. 在 `bin/` 下生成可搬迁启动套件。

## 运行

构建完成后执行：

```bash
./bin/codex-desktop-pets-fix
```

生成的 `bin/` 可以作为本机可搬迁运行套件使用。复制到其他目录后，只要目标机器的 Codex Desktop 和 Electron 安装路径兼容，也可以直接运行。

## 配置

默认会在宠物本体周围保留一点额外可抓取边距。可以通过环境变量调整：

```bash
CODEX_AVATAR_INPUT_PADDING=4 ./bin/codex-desktop-pets-fix
```

如果希望点击区域尽量贴合宠物本体，可以设为 `0`：

```bash
CODEX_AVATAR_INPUT_PADDING=0 ./bin/codex-desktop-pets-fix
```

## 生成文件说明

构建后，`bin/` 下会生成运行时文件，其中包括从本机 Codex Desktop 复制并 patch 出来的 `app.asar`。

不要把这些生成出来的 Codex Desktop 运行时文件发布到公开仓库。公开仓库里建议只提交构建脚本、启动脚本和 X11 helper 源码。

## 工作原理

Codex Desktop 会把宠物浮窗位置写入全局状态文件。watcher 会读取当前宠物和托盘矩形，找到对应的 X11 overlay 窗口，然后用 X11 `ShapeInput` 设置真实可接收鼠标事件的区域。

托盘隐藏时，只开放宠物本体区域；托盘显示时，临时追加托盘区域。

## 限制

- 这是非官方 workaround。
- 它依赖当前 Codex Desktop main bundle 的压缩代码结构。
- Codex Desktop 更新后，可能需要重新构建，或者调整 patch 匹配字符串。
- 它不会修改或替换系统安装的 Codex Desktop。
- 它不提供、也不重新分发 Codex Desktop 本体。

## 协议

见 [LICENSE](./LICENSE)。

## 免责声明

本项目与 OpenAI 无关联，也不代表 OpenAI 官方支持或认可。`Codex` 及相关产品名称归其对应权利方所有。
