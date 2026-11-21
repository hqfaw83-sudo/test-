import SwiftUI
import HealthKit

struct HealthMetric: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let color: Color
    let type: HKQuantityType
    let unit: HKUnit
    let unitLabel: String
    let cumulative: Bool
    var scale = 1.0
    var decimals = 0
    static var all: [HealthMetric] {
        var result: [HealthMetric] = []
        func add(_ id: String, _ title: String, _ symbol: String, _ color: Color, _ identifier: HKQuantityTypeIdentifier, _ unit: HKUnit, _ label: String, _ cumulative: Bool = false, _ scale: Double = 1, _ decimals: Int = 0) {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) { result.append(HealthMetric(id: id, title: title, symbol: symbol, color: color, type: type, unit: unit, unitLabel: label, cumulative: cumulative, scale: scale, decimals: decimals)) }
        }
        add("steps", "步数", "figure.walk", .orange, .stepCount, .count(), "步", true)
        add("energy", "活动能量", "flame.fill", .pink, .activeEnergyBurned, .kilocalorie(), "千卡", true)
        add("exercise", "锻炼时间", "figure.run", .green, .appleExerciseTime, .minute(), "分钟", true)
        add("heart", "心率", "heart.fill", .pink, .heartRate, .count().unitDivided(by: .minute()), "次/分")
        add("resting", "静息心率", "heart", .red, .restingHeartRate, .count().unitDivided(by: .minute()), "次/分")
        add("hrv", "心率变异性 HRV", "waveform.path.ecg", .mint, .heartRateVariabilitySDNN, .secondUnit(with: .milli), "毫秒")
        add("oxygen", "血氧", "drop.fill", .purple, .oxygenSaturation, .percent(), "%", false, 100, 1)
        add("breathing", "呼吸频率", "lungs.fill", .cyan, .respiratoryRate, .count().unitDivided(by: .minute()), "次/分", false, 1, 1)
        add("wrist", "睡眠腕温", "thermometer", .purple, .appleSleepingWristTemperature, .degreeCelsius(), "°C", false, 1, 1)
        add("stand", "站立时间", "figure.stand", .blue, .appleStandTime, .minute(), "分钟", true)
        if #available(iOS 17.0, *) { add("daylight", "日照时间", "sun.max.fill", .yellow, .timeInDaylight, .minute(), "分钟", true) }
        add("sound", "环境音量", "ear.fill", .cyan, .environmentalAudioExposure, .decibelAWeightedSoundPressureLevel(), "dBA", false, 1, 1)
        add("weight", "体重", "scalemass.fill", .teal, .bodyMass, .gramUnit(with: .kilo), "公斤", false, 1, 1)
        add("fat", "体脂率", "drop", .blue, .bodyFatPercentage, .percent(), "%", false, 100, 1)
        add("food", "饮食能量", "fork.knife", .green, .dietaryEnergyConsumed, .kilocalorie(), "千卡", true)
        return result
    }
    func text(_ value: Double?) -> String { guard let value = value, value.isFinite else { return "—" }; return value.formatted(.number.precision(.fractionLength(decimals))) }
}
struct MetricPoint: Identifiable { let date: Date; let value: Double; var id: Date { date } }
struct MetricReading { var value: Double?; var date: Date?; var points: [MetricPoint] = []; var error: String? }
final class WellnessReader: ObservableObject {
    let metrics = HealthMetric.all
    @Published var readings: [String: MetricReading] = [:]
    @Published var sleep: SleepEpisode?
    @Published var sleepHistory: [MetricPoint] = []
    @Published var nightReadings: [String: [MetricPoint]] = [:]
    @Published var firstWatchRecord: Date?
    @Published var watchRecordName: String?
    @Published var latestWatchModel: String?
    @Published var latestWatchIdentifier: String?
    @Published var latestWatchDate: Date?
    @Published var busy = false
    @Published var message = "连接 Apple 健康，查看睡眠、活动与身体指标。"
    @Published var requested = UserDefaults.standard.bool(forKey: "wellnessRequested")
    @Published var updated: Date?
    private let store = HKHealthStore()
    private var observers: [HKObserverQuery] = []
    private var pending = false
    private var completed = 0
    private var expected = 0
    private var reload: DispatchWorkItem?
    func connect() {
        guard HKHealthStore.isHealthDataAvailable(), !busy else { return }
        busy = true
        var types = Set<HKObjectType>(metrics.map { $0.type })
        if let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(type) }
        store.requestAuthorization(toShare: [], read: types) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }; self.busy = false
                if let error = error { self.message = "授权请求失败：\(error.localizedDescription)"; return }
                self.requested = true; UserDefaults.standard.set(true, forKey: "wellnessRequested")
                self.observe(); self.refresh()
            }
        }
    }
    func refreshIfRequested() { if requested { observe(); refresh() } }
    private func observe() {
        guard observers.isEmpty else { return }
        var types: [HKSampleType] = metrics.map { $0.type }
        if let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { types.append(type) }
        for type in types {
            let observer = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                completion(); guard error == nil else { return }
                DispatchQueue.main.async {
                    guard let self = self else { return }; self.reload?.cancel()
                    let task = DispatchWorkItem { [weak self] in self?.refresh() }; self.reload = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
                }
            }
            observers.append(observer); store.execute(observer)
        }
    }
    func refresh() {
        guard requested else { return }
        guard !busy else { pending = true; return }
        busy = true; completed = 0; expected = metrics.reduce(0) { $0 + ($1.cumulative ? 1 : 2) } + 3
        readings = [:]; sleep = nil; sleepHistory = []; nightReadings = [:]; firstWatchRecord = nil; watchRecordName = nil
        let calendar = Calendar.current, now = Date(), today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -89, to: today)!
        for metric in metrics {
            let options: HKStatisticsOptions = metric.cumulative ? .cumulativeSum : .discreteAverage
            let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
            let query = HKStatisticsCollectionQuery(quantityType: metric.type, quantitySamplePredicate: predicate, options: options, anchorDate: today, intervalComponents: DateComponents(day: 1))
            query.initialResultsHandler = { [weak self] _, collection, error in
                var points: [MetricPoint] = []
                collection?.enumerateStatistics(from: start, to: now) { statistics, _ in
                    let quantity = metric.cumulative ? statistics.sumQuantity() : statistics.averageQuantity()
                    if let value = quantity?.doubleValue(for: metric.unit), value.isFinite { points.append(MetricPoint(date: statistics.startDate, value: value * metric.scale)) }
                }
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    var reading = self.readings[metric.id] ?? MetricReading(); reading.points = points
                    if metric.cumulative, let value = points.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) { reading.value = value.value; reading.date = now }
                    if let error = error { reading.error = error.localizedDescription }
                    self.readings[metric.id] = reading; self.finish()
                }
            }
            store.execute(query)
            if !metric.cumulative {
                let latest = HKSampleQuery(sampleType: metric.type, predicate: HKQuery.predicateForSamples(withStart: nil, end: now), limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { [weak self] _, samples, error in
                    let sample = samples?.first as? HKQuantitySample
                    let value = sample?.quantity.doubleValue(for: metric.unit)
                    DispatchQueue.main.async {
                        guard let self = self else { return }; var reading = self.readings[metric.id] ?? MetricReading()
                        reading.value = value.map { $0 * metric.scale }; reading.date = sample?.endDate
                        if let error = error { reading.error = error.localizedDescription }
                        self.readings[metric.id] = reading; self.finish()
                    }
                }
                store.execute(latest)
            }
        }
        readSleep(start: start, now: now); readFirstWatch(now: now)
    }
    private func readSleep(start: Date, now: Date) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { finish(); return }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
            let categories: [HKCategorySample] = samples as? [HKCategorySample] ?? []
            var pieces: [SleepPiece] = []
            for sample in categories {
                let source = sample.sourceRevision.source
                let sourceKey = source.name + " · " + source.bundleIdentifier
                let watchModel = sample.device?.model?.localizedCaseInsensitiveContains("Watch") ?? false
                let watchProduct = sample.sourceRevision.productType?.hasPrefix("Watch") ?? false
                let piece = SleepPiece(start: sample.startDate, end: min(now, sample.endDate), stage: sample.value, source: sourceKey, watch: watchModel || watchProduct)
                pieces.append(piece)
            }
            let episodes = WellnessMath.primarySleep(pieces)
            let recent = episodes.last { $0.end >= now.addingTimeInterval(-36 * 3600) }
            DispatchQueue.main.async {
                guard let self = self else { return }; self.sleep = recent
                self.sleepHistory = episodes.map { MetricPoint(date: Calendar.current.startOfDay(for: $0.end), value: $0.seconds / 3600) }
                if let recent = recent {
                    for metric in self.metrics.filter({ ["heart", "hrv"].contains($0.id) }) {
                        self.expected += 1; self.readNight(metric: metric, episode: recent)
                    }
                }
                self.finish()
            }
        }
        store.execute(query)
    }
    private func readNight(metric: HealthMetric, episode: SleepEpisode) {
        let predicate = HKQuery.predicateForSamples(withStart: episode.start, end: episode.end, options: [.strictStartDate, .strictEndDate])
        let query = HKSampleQuery(sampleType: metric.type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
            let all = samples as? [HKQuantitySample] ?? []
            let watch = all.filter { $0.device?.model?.localizedCaseInsensitiveContains("Watch") == true || $0.sourceRevision.productType?.hasPrefix("Watch") == true }
            let chosen = watch.isEmpty ? all : watch
            let points = Dictionary(grouping: chosen, by: { $0.startDate }).compactMap { date, group -> MetricPoint? in
                let values = group.map { $0.quantity.doubleValue(for: metric.unit) * metric.scale }.filter { $0.isFinite }
                guard !values.isEmpty else { return nil }
                return MetricPoint(date: date, value: values.reduce(0, +) / Double(values.count))
            }.sorted { $0.date < $1.date }
            DispatchQueue.main.async { guard let self = self else { return }; self.nightReadings[metric.id] = points; self.finish() }
        }
        store.execute(query)
    }
    private func readFirstWatch(now: Date) {
        let heart = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let device = HKQuery.predicateForObjects(withDeviceProperty: HKDevicePropertyKeyModel, allowedValues: Set(["Watch", "Apple Watch"]))
        let date = HKQuery.predicateForSamples(withStart: nil, end: now)
        let query = HKSampleQuery(sampleType: heart, predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [device, date]), limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { [weak self] _, samples, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }; self.firstWatchRecord = samples?.first?.startDate; self.watchRecordName = samples?.first?.device?.name
                self.finish()
            }
        }
        store.execute(query)
        let latest = HKSampleQuery(sampleType: heart, predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [device, date]), limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { [weak self] _, samples, _ in
            let sample = samples?.first
            let product = sample?.sourceRevision.productType
            let hardware = sample?.device?.hardwareVersion
            let name = WatchModel.name(for: product) ?? WatchModel.name(for: hardware)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.latestWatchModel = name
                self.latestWatchIdentifier = product ?? hardware
                self.latestWatchDate = sample?.startDate
                self.finish()
            }
        }
        store.execute(latest)
    }
    private func finish() {
        completed += 1
        guard completed >= expected else { return }
        busy = false; updated = Date()
        message = readings.values.contains { $0.value != nil } || sleep != nil ? "" : "暂无可读健康数据。可检查健康权限；未授权与没有记录无法由应用区分。"
        if pending { pending = false; refresh() }
    }
    deinit { reload?.cancel(); for observer in observers { store.stop(observer) } }
}
