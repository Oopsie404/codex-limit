# Codex Limit

独立的 macOS 菜单栏应用，直接在菜单栏显示 Codex 的 5 小时和 7 天额度，以及各自的重置倒计时。使用 AppKit 原生状态项和系统菜单栏外观，无 Dock 图标。默认每 60 秒刷新，也可以在菜单中手动刷新。

默认同时显示两个窗口：

```text
72% 2h18m · 41% 3d6h
```

同一窗口的百分比和时间用空格分隔；只有两个窗口都显示时，才在两组数据之间加入 `·`。只显示一个窗口时，例如 `72% 2h18m`。倒计时使用 `30m`、`2h18m`、`3d6h` 等紧凑格式。菜单中有四个独立保存的显示选项（默认全部开启），以及手动刷新、开机自启和退出。开机自启使用 macOS 的 SMAppService 登录项。

## 系统与登录要求

- macOS 13 或更新版本，Apple Silicon。
- 本机 Codex CLI 必须已登录，并能通过 `app-server` 读取额度。需要登录时可运行 `codex login`。
- 应用优先查找系统 `PATH` 中的 `codex`，找不到时使用 `/Applications/ChatGPT.app/Contents/Resources/codex`。两个位置都不存在，或额度暂时不可用时，菜单栏显示 `--`。

## 安装

1. 打开 `dist/CodexLimit-macos-0.1.3.dmg`。
2. 将 `Codex Limit.app` 拖到“应用程序”文件夹。
3. 首次启动时，在 Finder 中右键点击应用并选择“打开”，然后确认。启动后不会弹出窗口，额度直接出现在屏幕顶部菜单栏。此版本使用本地临时签名，尚未经过 Apple 公证。如果 macOS 阻止打开，可在“系统设置 → 隐私与安全性”中选择“仍要打开”。
4. 如需开机自启，在菜单栏菜单中勾选“开机自启”。

## 数据隐私

应用仅通过本机 Codex CLI 的 `app-server` 请求额度。应用不读取浏览器 Cookie，不访问 chatgpt.com 的网页额度接口，不要求特定代理，也不保存、上传或打印 Cookie、Token、账号信息及本机隐私数据。Codex CLI 获取额度时会按其自身的正常流程连接 OpenAI 服务。

## 本地构建

需要 Xcode 命令行工具或 Xcode，以及 Swift 6。于项目根目录运行：

```sh
swift test --arch arm64
./Scripts/build-app.sh
./Scripts/build-dmg.sh
```

生成的 Apple Silicon 应用位于 `dist/Codex Limit.app`，磁盘映像位于 `dist/CodexLimit-macos-0.1.3.dmg`。构建脚本使用临时签名，分发前若需免除首次启动确认，应另行使用 Developer ID 签名并完成公证。
