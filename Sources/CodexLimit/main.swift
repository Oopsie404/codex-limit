import AppKit
import Foundation
import ServiceManagement

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var timer: Timer!
    private let defaults = UserDefaults.standard
    private var usage = Usage()

    private let keys = ["show5hLimit", "show5hReset", "show7dLimit", "show7dReset"]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = NSFont.menuBarFont(ofSize: 0)
        buildMenu()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func buildMenu() {
        menu = NSMenu()
        menu.autoenablesItems = false
        addToggle("显示 5 小时限额", key: "show5hLimit")
        addToggle("显示 5 小时剩余时间", key: "show5hReset")
        addToggle("显示 7 天限额", key: "show7dLimit")
        addToggle("显示 7 天剩余时间", key: "show7dReset")
        menu.addItem(.separator())
        let refresh = NSMenuItem(title: "手动刷新", action: #selector(refreshNow), keyEquivalent: "")
        refresh.target = self; menu.addItem(refresh)
        let login = NSMenuItem(title: "开机自启", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self; menu.addItem(login)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出应用", action: #selector(quit), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
        statusItem.menu = menu
        updateMenuChecks()
    }

    private func addToggle(_ title: String, key: String) {
        let item = NSMenuItem(title: title, action: #selector(toggleDisplay(_:)), keyEquivalent: "")
        item.target = self; item.representedObject = key; menu.addItem(item)
    }

    @objc private func toggleDisplay(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        defaults.set(!defaults.bool(forKey: key), forKey: key)
        updateMenuChecks(); updateTitle()
    }

    @objc private func refreshNow() { refresh() }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { NSLog("CodexLimit login item: %@", String(describing: error)) }
        updateMenuChecks()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func updateMenuChecks() {
        for item in menu.items {
            if let key = item.representedObject as? String { item.state = defaults.bool(forKey: key) ? .on : .off }
        }
        if let login = menu.items.first(where: { $0.title == "开机自启" }) {
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }

    private func refresh() {
        CodexServer.read { [weak self] result in
            DispatchQueue.main.async {
                self?.usage = Usage(result ?? [:]); self?.updateTitle()
            }
        }
    }

    private func updateTitle() {
        let active = [(defaults.bool(forKey: "show5hLimit") || defaults.bool(forKey: "show5hReset")),
                      (defaults.bool(forKey: "show7dLimit") || defaults.bool(forKey: "show7dReset"))]
        let labels = active.filter { $0 }.count > 1
        var parts: [String] = []
        if active[0] { parts.append(format(window: usage.fiveHour, label: "5h", showLabel: labels, limitKey: "show5hLimit", resetKey: "show5hReset")) }
        if active[1] { parts.append(format(window: usage.sevenDay, label: "7d", showLabel: labels, limitKey: "show7dLimit", resetKey: "show7dReset")) }
        statusItem.button?.title = parts.isEmpty ? "--" : parts.joined(separator: "    ")
        updateMenuChecks()
    }

    private func format(window: Window?, label: String, showLabel: Bool, limitKey: String, resetKey: String) -> String {
        guard let window else { return showLabel ? "\(label) --" : "--" }
        var fields: [String] = []
        if defaults.bool(forKey: limitKey) { fields.append("\(Int((100 - window.usedPercent).rounded()))%") }
        if defaults.bool(forKey: resetKey) { fields.append(remaining(window.resetAt)) }
        return (showLabel ? "\(label) " : "") + fields.joined(separator: " · ")
    }

    private func remaining(_ epoch: Double?) -> String {
        guard let epoch else { return "?" }
        let minutes = max(0, Int((epoch - Date().timeIntervalSince1970 + 59) / 60))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60, mins = minutes % 60
        if hours < 24 { return mins == 0 ? "\(hours)h" : "\(hours)h\(mins)m" }
        let days = hours / 24, rest = hours % 24
        return rest == 0 ? "\(days)d" : "\(days)d\(rest)h"
    }
}

struct Window { var usedPercent: Double; var resetAt: Double? }
struct Usage {
    var fiveHour: Window?; var sevenDay: Window?
    init(_ data: [String: Any] = [:]) {
        func parse(_ key: String) -> Window? {
            guard let w = data[key] as? [String: Any], let used = (w["usedPercent"] as? NSNumber)?.doubleValue else { return nil }
            return Window(usedPercent: used, resetAt: (w["resetsAt"] as? NSNumber)?.doubleValue)
        }
        fiveHour = parse("primary"); sevenDay = parse("secondary")
    }
}

enum CodexServer {
    static func read(completion: @escaping ([String: Any]?) -> Void) {
        let task = Process(); task.executableURL = URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex")
        let port = 37841; task.arguments = ["app-server", "--listen", "ws://127.0.0.1:\(port)"]
        task.standardOutput = Pipe(); task.standardError = Pipe()
        do { try task.run() } catch { completion(nil); return }
        DispatchQueue.global().async {
            defer { task.terminate() }
            for _ in 0..<100 {
                let ws = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)")!)
                ws.resume()
                let initialize = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"clientInfo\":{\"name\":\"codex-limit\",\"version\":\"0.1.0\"},\"capabilities\":{}}}"
                let request = "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"account/rateLimits/read\",\"params\":{}}"
                let sem = DispatchSemaphore(value: 0)
                var result: [String: Any]?
                ws.send(.string(initialize)) { _ in
                    ws.send(.string(request)) { _ in
                        ws.receive { response in
                            if case .success(.string(let text)) = response,
                               let data = text.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let payload = json["result"] as? [String: Any],
                               let limits = payload["rateLimits"] as? [String: Any] { result = limits }
                            sem.signal()
                        }
                    }
                }
                _ = sem.wait(timeout: .now() + 2)
                ws.cancel(with: .normalClosure, reason: nil)
                if let result { completion(result); return }
                usleep(100_000)
            }
            completion(nil)
        }
    }
}

// Minimal WebSocket client for Codex app-server is added in the next source file.
