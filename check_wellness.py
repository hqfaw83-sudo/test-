from pathlib import Path
import subprocess
import tempfile

source = Path('Sources/WellnessMath.swift').read_text()
tests = r'''
func date(_ hour: Double) -> Date { Date(timeIntervalSince1970: hour * 3600) }
assert(WellnessMath.duration([(date(0), date(2)), (date(1), date(3)), (date(0), date(2))]) == 10800)
func piece(_ start: Double, _ end: Double, _ stage: Int, _ source: String = "watch", _ watch: Bool = true) -> SleepPiece {
    SleepPiece(start: date(start), end: date(end), stage: stage, source: source, watch: watch)
}
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let episodes = WellnessMath.primarySleep([piece(0, 1, 3), piece(0, 1, 3), piece(1, 1.5, 2), piece(1.5, 2.5, 4), piece(0, 4, 0), piece(0, 5, 1, "phone", false)], calendar: calendar)
assert(episodes.count == 1 && episodes[0].seconds == 7200 && episodes[0].watch)
assert(episodes[0].spans.contains { $0.stage == 2 })
assert(!episodes[0].spans.contains { $0.stage == 0 })
assert(WellnessMath.primarySleep([piece(0, 1, 0)]).isEmpty)
assert(WellnessMath.companionDays(from: date(50), to: date(20), calendar: calendar) == 0)
calendar.timeZone = TimeZone(identifier: "America/New_York")!
let formatter = ISO8601DateFormatter()
let before = formatter.date(from: "2026-03-07T17:00:00Z")!
let after = formatter.date(from: "2026-03-09T16:00:00Z")!
assert(WellnessMath.companionDays(from: before, to: after, calendar: calendar) == 2)
print("Sleep deduplication, source selection, awake exclusion and companion dates passed")
'''
with tempfile.TemporaryDirectory() as temp:
    script = Path(temp) / 'check.swift'
    script.write_text(source + tests)
    subprocess.run(['swift', str(script)], check=True)
