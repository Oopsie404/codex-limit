import Foundation

struct Window {
    let usedPercent: Double?
    let resetAt: Double?
    var hasData: Bool { usedPercent != nil || resetAt != nil }

    init(_ value: Any?) {
        let fields = value as? [String: Any] ?? [:]
        let used = (fields["usedPercent"] as? NSNumber)?.doubleValue
        usedPercent = used.flatMap { $0.isFinite && (0...100).contains($0) ? $0 : nil }
        let reset = (fields["resetsAt"] as? NSNumber)?.doubleValue
        resetAt = reset.flatMap { $0.isFinite && $0 > 0 && $0 < 1_000_000_000_000 ? $0 : nil }
    }
}

struct Usage {
    let fiveHour: Window
    let sevenDay: Window

    init?(response: [String: Any]) {
        guard let result = response["result"] as? [String: Any],
              let limits = result["rateLimits"] as? [String: Any] else { return nil }
        fiveHour = Window(limits["primary"])
        sevenDay = Window(limits["secondary"])
        if !fiveHour.hasData && !sevenDay.hasData { return nil }
    }
}

struct DisplayOptions {
    let fiveHourLimit: Bool
    let fiveHourReset: Bool
    let sevenDayLimit: Bool
    let sevenDayReset: Bool
}

enum StatusFormatter {
    static func title(usage: Usage, options: DisplayOptions, now: Date = Date()) -> String {
        let showFiveHour = options.fiveHourLimit || options.fiveHourReset
        let showSevenDay = options.sevenDayLimit || options.sevenDayReset
        var windows: [String] = []

        if showFiveHour {
            windows.append(format(usage.fiveHour,
                                  showLimit: options.fiveHourLimit, showReset: options.fiveHourReset,
                                  now: now))
        }
        if showSevenDay {
            windows.append(format(usage.sevenDay,
                                  showLimit: options.sevenDayLimit, showReset: options.sevenDayReset,
                                  now: now))
        }
        return windows.isEmpty ? "--" : windows.joined(separator: " · ")
    }

    private static func format(_ window: Window, showLimit: Bool, showReset: Bool,
                               now: Date) -> String {
        var fields: [String] = []
        if showLimit {
            if let used = window.usedPercent {
                fields.append("\(Int((100 - used).rounded()))%")
            } else {
                fields.append("--")
            }
        }
        if showReset {
            fields.append(window.resetAt.map { remaining($0, now: now) } ?? "--")
        }
        return fields.joined(separator: " ")
    }

    private static func remaining(_ resetAt: Double, now: Date) -> String {
        let minutes = max(0, Int(ceil((resetAt - now.timeIntervalSince1970) / 60)))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours < 24 { return mins == 0 ? "\(hours)h" : "\(hours)h\(mins)m" }
        let days = hours / 24
        let rest = hours % 24
        return rest == 0 ? "\(days)d" : "\(days)d\(rest)h"
    }
}
