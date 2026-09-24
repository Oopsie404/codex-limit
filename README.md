# Codex Limit

一个独立的 macOS 菜单栏应用，只显示 Codex 额度。

菜单栏常驻显示例如：

```text
5h 72% · 2h18m    7d 41% · 3d6h
```

数据通过本机 Codex CLI 的 `app-server` 获取，不读取浏览器 Cookie，也不依赖 Claude Code。菜单提供四个独立显示开关、手动刷新、开机自启和退出。

## 构建

```sh
./Scripts/build-app.sh
```

将生成的 `dist/Codex Limit.app` 拖入“应用程序”。
