import Foundation
import XCTest
@testable import CodexLimit

final class UsageTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func usage(fiveHour: [String: Any], sevenDay: [String: Any]) -> Usage {
        Usage(response: [
            "result": [
                "rateLimits": [
                    "primary": fiveHour,
                    "secondary": sevenDay
                ]
            ]
        ])!
    }

    func testBothWindowsAndCompactTimes() {
        let snapshot = usage(
            fiveHour: ["usedPercent": 28, "resetsAt": now.timeIntervalSince1970 + 138 * 60],
            sevenDay: ["usedPercent": 59, "resetsAt": now.timeIntervalSince1970 + 78 * 60 * 60]
        )
        let options = DisplayOptions(fiveHourLimit: true, fiveHourReset: true,
                                     sevenDayLimit: true, sevenDayReset: true)
        XCTAssertEqual(StatusFormatter.title(usage: snapshot, options: options, now: now),
                       "72% 2h18m · 41% 3d6h")
    }

    func testSingleWindowHasNoSeparatorAndEachSettingIsIndependent() {
        let snapshot = usage(
            fiveHour: ["usedPercent": 28, "resetsAt": now.timeIntervalSince1970 + 30 * 60],
            sevenDay: ["usedPercent": 59, "resetsAt": now.timeIntervalSince1970 + 78 * 60 * 60]
        )
        XCTAssertEqual(StatusFormatter.title(
            usage: snapshot,
            options: DisplayOptions(fiveHourLimit: false, fiveHourReset: true,
                                    sevenDayLimit: false, sevenDayReset: false),
            now: now
        ), "30m")
        XCTAssertEqual(StatusFormatter.title(
            usage: snapshot,
            options: DisplayOptions(fiveHourLimit: false, fiveHourReset: false,
                                    sevenDayLimit: true, sevenDayReset: false),
            now: now
        ), "41%")
        XCTAssertEqual(StatusFormatter.title(
            usage: snapshot,
            options: DisplayOptions(fiveHourLimit: true, fiveHourReset: false,
                                    sevenDayLimit: false, sevenDayReset: true),
            now: now
        ), "72% · 3d6h")
    }

    func testMissingFieldsUsePlaceholder() {
        let snapshot = usage(fiveHour: ["usedPercent": 28], sevenDay: [:])
        let options = DisplayOptions(fiveHourLimit: true, fiveHourReset: true,
                                     sevenDayLimit: true, sevenDayReset: true)
        XCTAssertEqual(StatusFormatter.title(usage: snapshot, options: options, now: now),
                       "72% -- · -- --")
        XCTAssertNil(Usage(response: ["result": [:]]))
        XCTAssertNil(Usage(response: ["result": ["rateLimits": [:]]]))
    }
}
