import SwiftUI
import HealthKit
import Charts

struct ListenRange { let start: Date; let end: Date; let name: String }
struct DayTotal: Identifiable { let date: Date; let seconds: Double; var id: Date { date } }
struct DeviceTotal: Identifiable { let name: String; let seconds: Double; var id: String { name } }
struct Report {
    var total = 0.0, today = 0.0
    var days = 0, excluded = 0
    var week: [DayTotal] = []
    var devices: [DeviceTotal] = []
    var history: [DayTotal] = []
    var first: Date?, last: Date?
}
enum Calculator {
    static func merge(_ items: [ListenRange]) -> [(Date, Date)] {
        var output: [(Date, Date)] = []
        for item in items.filter({ $0.end > $0.start }).sorted(by: { $0.start < $1.start }) {
            if let last = output.last, item.start <= last.1 {
                output[output.count - 1].1 = max(last.1, item.end)
            } else { output.append((item.start, item.end)) }
        }
        return output
    }
    static func duration(_ items: [(Date, Date)]) -> Double {
        items.reduce(0) { $0 + $1.1.timeIntervalSince($1.0) }
    }
    static func calculate(_ items: [ListenRange], excluded: Int, now: Date = Date(), calendar: Calendar = .current) -> Report {
        let ranges = merge(items)
        var daily: [Date: Double] = [:]
        for (start, end) in ranges {
            var cursor = start
            while cursor < end {
                let day = calendar.startOfDay(for: cursor)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > cursor else { break }
                let stop = min(next, end)
                daily[day, default: 0] += stop.timeIntervalSince(cursor)
                cursor = stop
            }
        }
        let today = calendar.startOfDay(for: now)
        var report = Report()
        report.total = duration(ranges); report.today = daily[today, default: 0]
        report.days = daily.count; report.first = ranges.first?.0; report.last = ranges.last?.1
        report.excluded = excluded
        report.history = daily.map { DayTotal(date: $0.key, seconds: $0.value) }.sorted { $0.date < $1.date }
        report.week = (-6...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return DayTotal(date: date, seconds: daily[date, default: 0])
        }
        report.devices = Dictionary(grouping: items, by: { $0.name }).map {
            DeviceTotal(name: $0.key, seconds: duration(merge($0.value)))
        }.sorted { $0.seconds > $1.seconds }
        return report
    }
}
final class HealthReader: ObservableObject {
    @Published var report = Report()
    @Published var busy = false
    @Published var loaded = false
    @Published var message = "请连接 Apple 健康，读取耳机音频音量记录。"
    @Published var refreshed: Date?
    private let store = HKHealthStore()
    private let type = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure)!
    private var observer: HKObserverQuery?
    private var pending = false
    func connect() {
        guard HKHealthStore.isHealthDataAvailable() else { message = "设备不支持健康数据。"; return }
        guard !busy else { return }; busy = true
        store.requestAuthorization(toShare: [], read: [type]) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }; self.busy = false
                if let error = error { self.message = error.localizedDescription; return }
                self.observe(); self.refresh()
            }
        }
    }
    private func observe() {
        guard observer == nil else { return }
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
            completion()
            if error == nil { DispatchQueue.main.async { self?.refresh() } }
        }
        observer = query; store.execute(query)
    }
    func refresh() {
        guard observer != nil else { return }
        guard !busy else { pending = true; return }; busy = true
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async { self.busy = false; self.pending = false; self.message = "读取失败：\(error.localizedDescription)" }; return
            }
            let now = Date()
            var excluded = 0
            let ranges: [ListenRange] = (samples ?? []).compactMap { sample in
                guard let name = sample.device?.name, name.localizedCaseInsensitiveContains("AirPods") else { excluded += 1; return nil }
                let end = min(sample.endDate, now)
                guard end > sample.startDate else { return nil }
                return ListenRange(start: sample.startDate, end: end, name: name)
            }
            let result = Calculator.calculate(ranges, excluded: excluded, now: now)
            DispatchQueue.main.async {
                self.report = result; self.loaded = true; self.busy = false; self.refreshed = Date()
                self.message = ranges.isEmpty ? "未读取到 AirPods 记录。请检查健康权限和耳机音频音量数据；iOS 不允许应用区分未授权与没有数据。" : ""
                if self.pending { self.pending = false; self.refresh() }
            }
        }
        store.execute(query)
    }
    deinit { if let observer = observer { store.stop(observer) } }
}
