import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var timer: Timer?
    private let defaults = UserDefaults.standard
    private var usage: Usage?
    private var isRefreshing = false
    private var refreshPending = false

    private enum Setting {
        static let fiveHourLimit = "show5hLimit"
        static let fiveHourReset = "show5hReset"
        static let sevenDayLimit = "show7dLimit"
        static let sevenDayReset = "show7dReset"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        defaults.register(defaults: [
            Setting.fiveHourLimit: true,
            Setting.fiveHourReset: true,
            Setting.sevenDayLimit: true,
            Setting.sevenDayReset: true
        ])

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "com.codexlimit.app.status"
        statusItem.isVisible = true
        buildMenu()
        updateTitle()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func buildMenu() {
        menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        addToggle("显示 5 小时限额", key: Setting.fiveHourLimit)
        addToggle("显示 5 小时剩余时间", key: Setting.fiveHourReset)
        addToggle("显示 7 天限额", key: Setting.sevenDayLimit)
        addToggle("显示 7 天剩余时间", key: Setting.sevenDayReset)
        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "手动刷新", action: #selector(refreshNow), keyEquivalent: "")
        refresh.target = self
        menu.addItem(refresh)

        let login = NSMenuItem(title: "开机自启", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        menu.addItem(login)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出应用", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        updateMenuChecks()
    }

    private func addToggle(_ title: String, key: String) {
        let item = NSMenuItem(title: title, action: #selector(toggleDisplay(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = key
        menu.addItem(item)
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuChecks()
    }

    @objc private func toggleDisplay(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        defaults.set(!defaults.bool(forKey: key), forKey: key)
        updateMenuChecks()
        updateTitle()
    }

    @objc private func refreshNow() { refresh() }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // Registration may be unavailable until the app is installed in Applications.
        }
        updateMenuChecks()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func updateMenuChecks() {
        for item in menu.items {
            if let key = item.representedObject as? String {
                item.state = defaults.bool(forKey: key) ? .on : .off
            }
        }
        menu.items.first(where: { $0.title == "开机自启" })?.state =
            SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func refresh() {
        if isRefreshing {
            refreshPending = true
            return
        }
        isRefreshing = true
        CodexServer.read { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.usage = result
                self.updateTitle()
                self.isRefreshing = false
                if self.refreshPending {
                    self.refreshPending = false
                    self.refresh()
                }
            }
        }
    }

    private func updateTitle() {
        guard let usage else {
            statusItem.button?.title = "--"
            return
        }
        let options = DisplayOptions(
            fiveHourLimit: defaults.bool(forKey: Setting.fiveHourLimit),
            fiveHourReset: defaults.bool(forKey: Setting.fiveHourReset),
            sevenDayLimit: defaults.bool(forKey: Setting.sevenDayLimit),
            sevenDayReset: defaults.bool(forKey: Setting.sevenDayReset)
        )
        statusItem.button?.title = StatusFormatter.title(usage: usage, options: options)
    }
}

@main
enum CodexLimitApp {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}
