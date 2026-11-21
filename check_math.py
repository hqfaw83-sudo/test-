from pathlib import Path
import subprocess

source = Path('Sources/ListeningApp.swift').read_text()
math = source[source.index('struct ListenRange'):source.index('final class HealthReader')]
checks = r'''
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let day = Date(timeIntervalSince1970: 1_700_006_400)
let midnight = calendar.startOfDay(for: day)
let now = midnight.addingTimeInterval(3600)
let records = [
    ListenRange(start: midnight.addingTimeInterval(-600), end: midnight.addingTimeInterval(600), name: "A"),
    ListenRange(start: midnight, end: midnight.addingTimeInterval(1200), name: "A"),
    ListenRange(start: midnight.addingTimeInterval(300), end: midnight.addingTimeInterval(900), name: "B")
]
let result = Calculator.calculate(records, excluded: 2, now: now, calendar: calendar)
assert(result.total == 1800, "overlap union")
assert(result.today == 1200, "split at midnight")
assert(result.days == 2, "active days")
assert(result.week.count == 7, "seven calendar days")
assert(result.week.reduce(0) { $0 + $1.seconds } == 1800, "weekly clipping")
assert(result.devices.first { $0.name == "A" }!.seconds == 1800, "device union")
assert(result.devices.first { $0.name == "B" }!.seconds == 600, "device independent")
assert(result.excluded == 2)
assert(result.todayDevices.first { $0.name == "A" }!.seconds == 1200, "today device clipped at midnight")
assert(result.todayDevices.first { $0.name == "B" }!.seconds == 600, "today device overlap")
let empty = Calculator.calculate([], excluded: 0, now: now, calendar: calendar)
assert(empty.total == 0 && empty.days == 0 && empty.week.count == 7)
var dst = Calendar(identifier: .gregorian)
dst.timeZone = TimeZone(identifier: "America/New_York")!
let start = ISO8601DateFormatter().date(from: "2026-03-08T05:00:00Z")!
let end = ISO8601DateFormatter().date(from: "2026-03-09T04:00:00Z")!
let spring = Calculator.calculate([ListenRange(start: start, end: end, name: "A")], excluded: 0, now: end, calendar: dst)
assert(spring.total == 23 * 3600 && spring.days == 1, "DST local day")
print("Listening calculation checks passed")
'''
Path('/tmp/ListeningMathCheck.swift').write_text('import Foundation\n' + math + checks)
subprocess.run(['swift', '/tmp/ListeningMathCheck.swift'], check=True)

model = Path('Sources/PodModel.swift').read_text()
icon_checks = r'''
assert(PodModel.detect("AirPods 4") == .fourth)
assert(PodModel.detect("AirPods 5 (Wireless Charging)") == .fifth)
assert(PodModel.detect("AirPods Pro 2") == .pro2)
assert(PodModel.detect("AirPods Pro (2nd generation)") == .pro2)
assert(PodModel.detect("AirPods Pro 第三代") == .pro3)
assert(PodModel.detect("AirPods Max 2") == .max2)
assert(PodModel.detect("AirPods 2") == .classic)
assert(PodModel.detect("AirPods 2024") == .airpods)
assert(PodModel.detect("AirPods") == .airpods)
assert(PodModel.detect("我的耳机") == .airpods)
print("Headphone icon matching checks passed")
'''
Path('/tmp/PodModelCheck.swift').write_text(model + icon_checks)
subprocess.run(['swift', '/tmp/PodModelCheck.swift'], check=True)
