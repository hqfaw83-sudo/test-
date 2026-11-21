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
private let blue = Color(red: 0.48, green: 0.68, blue: 1)
private let muted = Color(red: 0.62, green: 0.69, blue: 0.82)
func timeText(_ seconds: Double, exact: Bool = false) -> String {
    let s = max(0, Int(seconds))
    return "\(s / 3600) 小时 \(s % 3600 / 60) 分" + (exact ? " \(s % 60) 秒" : "")
}
@main struct ListeningApp: App {
    var body: some Scene { WindowGroup { Dashboard() } }
}
struct Dashboard: View {
    @StateObject private var health = HealthReader()
    @Environment(\.scenePhase) private var phase
    @State private var selected: Date?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LISTENING JOURNAL").font(.system(size: 10, weight: .semibold)).tracking(3).foregroundColor(blue)
                        Text("你的聆听宇宙").font(.system(size: 28, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Button { health.loaded ? health.refresh() : health.connect() } label: {
                        Image(systemName: "arrow.clockwise").foregroundColor(blue).font(.title3)
                    }.disabled(health.busy).accessibilityLabel("刷新健康数据")
                }.padding(.top, 12)
                hero
                HStack(spacing: 12) {
                    metric("近 7 天", timeText(health.report.week.reduce(0) { $0 + $1.seconds }), "waveform")
                    metric("有记录天数", "\(health.report.days) 天", "calendar")
                }
                weekly
                devices
                status
                Text("依据 Apple 健康的耳机音频音量记录，合并重叠区间，跨日按手机本地日期拆分。只戴耳机或只开降噪可能不计入，健康记录写入可能延迟。数据只在手机上处理。")
                    .font(.caption).foregroundColor(muted).lineSpacing(4)
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.background(Color(red: 0.025, green: 0.045, blue: 0.10).ignoresSafeArea())
            .foregroundColor(.white).preferredColorScheme(.dark)
            .task { health.connect() }
            .refreshable { health.refresh() }
            .onChange(of: phase) { value in if value == .active { health.refresh() } }
    }
    private var hero: some View {
        VStack(spacing: 14) {
            HStack { Label("AirPods", systemImage: "headphones").font(.headline); Spacer(); Text("历史累计").font(.caption).foregroundColor(muted) }
            ZStack {
                StarRing()
                VStack(spacing: 8) {
                    Text("总聆听时长").font(.caption).foregroundColor(muted)
                    Text("\(Int(health.report.total / 3600))").font(.system(size: 54, weight: .light, design: .rounded)).lineLimit(1).minimumScaleFactor(0.5)
                    Text("小时  \(Int(health.report.total) % 3600 / 60) 分  \(Int(health.report.total) % 60) 秒").font(.system(size: 12, design: .monospaced)).foregroundColor(blue)
                }.padding(40)
            }.frame(height: 270).accessibilityElement(children: .ignore).accessibilityLabel("累计 \(timeText(health.report.total, exact: true))")
            HStack { Text("今日聆听").foregroundColor(muted); Spacer(); Text(timeText(health.report.today, exact: true)).monospacedDigit() }.font(.subheadline)
        }.padding(20).card()
    }
    private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.caption).foregroundColor(muted)
            Text(value).font(.system(size: 18, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).card()
    }
    private var weekly: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("近 7 天").font(.headline); Spacer(); Text("含今天 · 小时").font(.caption).foregroundColor(muted) }
            Chart(health.report.week) { day in
                BarMark(x: .value("日期", day.date, unit: .day), y: .value("小时", day.seconds / 3600))
                    .foregroundStyle(selected == day.date ? Color.white : blue).cornerRadius(5)
                    .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue(timeText(day.seconds, exact: true))
            }
            .chartYScale(domain: 0...max(1, (health.report.week.map { $0.seconds / 3600 }.max() ?? 0) * 1.15))
            .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.month().day()) } }
            .frame(height: 170)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle()).onTapGesture { point in
                        let x = point.x - geometry[proxy.plotAreaFrame].origin.x
                        if let date: Date = proxy.value(atX: x) { selected = Calendar.current.startOfDay(for: date) }
                    }
                }
            }
            if let day = health.report.week.first(where: { $0.date == selected }) {
                Text("\(day.date.formatted(.dateTime.month().day())) · \(timeText(day.seconds, exact: true))").font(.caption).foregroundColor(blue)
            } else { Text("点击柱状图查看当天精确时长").font(.caption).foregroundColor(muted) }
        }.padding(20).card()
    }
    private var devices: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("一起听过的耳机").font(.headline)
            if health.report.devices.isEmpty { Text("读取后显示可识别的 AirPods。").font(.caption).foregroundColor(muted) }
            ForEach(health.report.devices) { device in
                VStack(alignment: .leading, spacing: 10) {
                    Label(device.name, systemImage: "headphones").font(.subheadline)
                    Text(timeText(device.seconds, exact: true)).font(.caption).foregroundColor(muted)
                    GeometryReader { geo in
                        Capsule().fill(Color.white.opacity(0.07))
                        Capsule().fill(blue).frame(width: geo.size.width * min(1, device.seconds / max(1, health.report.total)))
                    }.frame(height: 4)
                }
            }
            Text("按记录中的设备名称归类，同名耳机会合并。各设备分别去重，总计跨设备去重，分项之和可能大于总计。").font(.caption2).foregroundColor(muted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).card()
    }
    private var status: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Circle().fill(health.loaded ? Color.green : blue).frame(width: 6, height: 6); Text(health.busy ? "正在读取健康记录…" : "数据状态").font(.subheadline); if health.busy { ProgressView() } }
            if !health.message.isEmpty { Text(health.message).font(.caption).foregroundColor(muted) }
            if let last = health.report.last { Text("最新记录：\(last.formatted(date: .abbreviated, time: .standard))").font(.caption).foregroundColor(muted) }
            if let first = health.report.first { Text("最早记录：\(first.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundColor(muted) }
            if let date = health.refreshed { Text("读取于 \(date.formatted(date: .omitted, time: .standard)) · 前台随新记录刷新").font(.caption2).foregroundColor(muted) }
            if health.report.excluded > 0 { Text("排除其他耳机或无法识别设备的记录：\(health.report.excluded) 条").font(.caption2).foregroundColor(muted) }
            Button(health.loaded ? "重新请求健康授权" : "连接 Apple 健康") { health.connect() }.buttonStyle(.borderedProminent).tint(blue).foregroundColor(.black).disabled(health.busy)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).card()
    }
}
struct StarRing: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(blue.opacity(0.07)).blur(radius: 18).padding(30)
                Circle().stroke(blue.opacity(0.18), lineWidth: 1).padding(16)
                Circle().stroke(blue.opacity(0.08), lineWidth: 1).padding(30)
                Circle().trim(from: 0.05, to: 0.78).stroke(AngularGradient(colors: [.clear, blue.opacity(0.25), blue], center: .center), style: StrokeStyle(lineWidth: 2, lineCap: .round)).padding(16).rotationEffect(.degrees(-100))
                ForEach(0..<64) { index in
                    let angle = Double(index) * 2.3999632297
                    let radius = side * (0.39 + Double(index % 7) * 0.011)
                    Circle().fill(index % 4 == 0 ? Color.white : blue)
                        .frame(width: index % 5 == 0 ? 3 : 1.5, height: index % 5 == 0 ? 3 : 1.5)
                        .opacity(0.3 + Double(index % 4) * 0.2)
                        .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                }
            }.frame(width: side, height: side).frame(maxWidth: .infinity, maxHeight: .infinity)
        }.accessibilityHidden(true)
    }
}
extension View {
    func card() -> some View {
        self.background(LinearGradient(colors: [Color(red: 0.075, green: 0.12, blue: 0.23), Color(red: 0.045, green: 0.075, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.065), lineWidth: 1))
    }
}
