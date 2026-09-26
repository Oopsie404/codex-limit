# Codex Limit

一款 macOS 菜单栏应用，用于常驻显示 Codex 的额度信息：

- 5 小时额度及剩余时间
- 7 天额度及剩余时间
- 每 60 秒自动刷新
- 支持手动刷新
- 支持开机自启
- 支持分别选择显示额度和剩余时间

## 使用与修改

本项目允许个人和组织自由使用、修改和再发布。使用本项目源码发布修改版时，请保留原项目的版权和许可说明，并在项目说明中注明来源：

```text
基于 Codex Limit 修改
原项目：https://github.com/你的用户名/codex-limit（发布前替换为实际仓库地址）
```

如果你发布了修改版，也欢迎在 GitHub Issues 中留下链接。

详细授权条款见 [LICENSE](LICENSE)。

## 系统要求

- macOS 13 或更新版本
- Apple Silicon Mac
- 本机已登录 Codex App

## 数据来源与隐私

应用读取本机 Codex App 提供的额度信息，并在菜单栏中显示。应用不读取浏览器 Cookie，不访问网页额度接口，也不会保存或上传 Cookie、Token、账号信息及其他本机隐私数据。

## 问题反馈

如果遇到额度无法显示、刷新失败或其他问题，请在 GitHub 仓库的 **Issues** 中反馈，并尽量附上：

- macOS 版本
- Mac 芯片型号
- 应用版本
- 菜单栏显示的错误信息


## 本地构建

需要 Xcode 命令行工具或 Xcode，以及 Swift 6：

```sh
swift test --arch arm64
./Scripts/build-app.sh
./Scripts/build-dmg.sh
```
