import SwiftUI
import Charts

private let teal = Color(red: 0.08, green: 0.64, blue: 0.59)
private let sky = Color(red: 0.18, green: 0.55, blue: 0.90)
private let violet = Color(red: 0.54, green: 0.43, blue: 0.87)
private let amber = Color(red: 0.88, green: 0.58, blue: 0.17)
func timeText(_ seconds: Double, exact: Bool = false) -> String {
    let s = max(0, Int(seconds))
    return "\(s / 3600) 小时 \(s % 3600 / 60) 分" + (exact ? " \(s % 60) 秒" : "")
}
@main struct ListeningApp: App {
    var body: some Scene { WindowGroup { PulseDashboard() } }
}
struct PulseDashboard: View {
    @StateObject private var health = HealthReader()
    @Environment(\.scenePhase) private var phase
    @AppStorage("appearance") private var appearance = 0
    var body: some View {
        TabView {
            Overview(health: health).tabItem { Label("今日", systemImage: "square.grid.2x2.fill") }
            Trends(health: health).tabItem { Label("趋势", systemImage: "chart.xyaxis.line") }
            DevicePage(health: health).tabItem { Label("设备", systemImage: "headphones") }
            SettingsPage(health: health, appearance: $appearance).tabItem { Label("设置", systemImage: "slider.horizontal.3") }
        }.tint(teal)
            .preferredColorScheme(appearance == 0 ? nil : appearance == 1 ? .light : .dark)
            .task { if !ProcessInfo.processInfo.arguments.contains("--ui-preview") { health.connect() } }
            .onChange(of: phase) { value in if value == .active { health.refresh() } }
    }
}
struct Page<Content: View>: View {
    let title: String
    @ObservedObject var health: HealthReader
    let content: Content
    init(_ title: String, health: HealthReader, @ViewBuilder content: () -> Content) {
        self.title = title; self.health = health; self.content = content()
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) { content }
                    .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 28)
                    .frame(maxWidth: 640).frame(maxWidth: .infinity)
            }.background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { health.loaded ? health.refresh() : health.connect() } label: {
                            if health.busy { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                        }.disabled(health.busy).accessibilityLabel("刷新健康数据")
                    }
                }.refreshable { health.refresh() }
        }
    }
}
struct Overview: View {
    @ObservedObject var health: HealthReader
    private var week: Double { health.report.week.reduce(0) { $0 + $1.seconds } }
    private var active: Int { health.report.week.filter { $0.seconds > 0 }.count }
    var body: some View {
        Page("聆听时光", health: health) {
            HStack {
                Text(Date().formatted(.dateTime.month(.wide).day().weekday(.wide))).font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Label("本机统计", systemImage: "checkmark.shield.fill").font(.caption2.weight(.medium)).foregroundColor(teal)
            }
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("今日聆听", systemImage: "waveform").font(.headline).foregroundColor(teal)
                    Spacer(); Text("AirPods").font(.caption).foregroundColor(.secondary)
                }
                HStack(spacing: 20) {
                    TodayRing(seconds: health.report.today)
                    VStack(alignment: .leading, spacing: 15) {
                        mini("近 7 天", timeText(week), sky)
                        mini("本周有记录", "\(active) / 7 天", violet)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                Text(health.loaded ? (health.report.today > 0 ? "今天的声音，正在成为你的日常。" : "今天还没有可读取的聆听记录。") : "连接 Apple 健康，开启你的聆听记录。")
                    .font(.subheadline).foregroundColor(.secondary)
            }.padding(20).pulseCard()
            if !health.message.isEmpty { Notice(health: health) }
            HStack { Text("聆听概览").font(.title3.bold()); Spacer() }.padding(.top, 4)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                MetricTile(title: "累计聆听", value: "\(Int(health.report.total / 3600))", unit: "小时", detail: "另 \(Int(health.report.total) % 3600 / 60) 分钟", icon: "headphones", color: teal)
                MetricTile(title: "相伴日子", value: "\(health.report.days)", unit: "天", detail: "有聆听记录的日期", icon: "calendar", color: sky)
                MetricTile(title: "近 7 天日均", value: "\(Int(week / 7 / 60))", unit: "分钟", detail: "按 7 个自然日计算", icon: "chart.bar.fill", color: violet)
                MetricTile(title: "耳机记录", value: "\(health.report.devices.count)", unit: "组", detail: "按设备名称归类", icon: "earbuds", color: amber)
            }
            WeekPreview(days: health.report.week)
            if let last = health.report.last {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "clock").foregroundColor(teal)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("最新聆听记录").font(.subheadline.weight(.medium))
                        Text(last.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundColor(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(18).pulseCard()
            }
            Text("聆听时长来自耳机音频音量记录，可能延迟更新。仅戴耳机或只开降噪的时间可能不计入。").font(.caption).foregroundColor(.secondary).lineSpacing(3)
        }
    }
    private func mini(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(color).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}
struct TodayRing: View {
    let seconds: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Circle().stroke(teal.opacity(0.09), lineWidth: 11)
            Circle().trim(from: 0, to: min(1, max(0, seconds / 86400)))
                .stroke(AngularGradient(colors: [teal, sky, violet], center: .center), style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90)).animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: seconds)
            VStack(spacing: 3) {
                Text("\(Int(seconds / 3600))").font(.system(size: 40, weight: .bold, design: .rounded))
                Text("小时 \(Int(seconds) % 3600 / 60) 分").font(.caption).foregroundColor(.secondary)
                Text("占全天 \(Int(seconds / 86400 * 100))%") .font(.system(size: 9)).foregroundColor(.secondary).padding(.top, 4)
            }
        }.frame(width: 142, height: 142).padding(6)
            .accessibilityElement(children: .ignore).accessibilityLabel("今日 \(timeText(seconds, exact: true))，圆环表示占全天24小时的比例")
    }
}
struct MetricTile: View {
    let title: String, value: String, unit: String, detail: String, icon: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.caption.weight(.medium)).foregroundColor(color)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 30, weight: .semibold, design: .rounded)).minimumScaleFactor(0.5)
                Text(unit).font(.caption).foregroundColor(.secondary)
            }.lineLimit(1)
            Text(detail).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(2)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).pulseCard()
    }
}
struct WeekPreview: View {
    let days: [DayTotal]
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Label("这一周的声音", systemImage: "chart.bar.xaxis").font(.headline); Spacer(); Text("小时").font(.caption).foregroundColor(.secondary) }
            ListeningChart(days: days, selected: .constant(nil), color: teal).frame(height: 145)
        }.padding(20).pulseCard()
    }
}
struct ListeningChart: View {
    let days: [DayTotal]
    @Binding var selected: Date?
    let color: Color
    var body: some View {
        Chart(days) { day in
            BarMark(x: .value("日期", day.date, unit: .day), y: .value("小时", day.seconds / 3600))
                .foregroundStyle(selected == day.date ? sky : color.opacity(0.8)).cornerRadius(4)
                .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue(timeText(day.seconds, exact: true))
        }
        .chartYScale(domain: 0...max(1, (days.map { $0.seconds / 3600 }.max() ?? 0) * 1.15))
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: days.count > 7 ? 7 : 1)) { _ in AxisValueLabel(format: .dateTime.day()) } }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle()).onTapGesture { point in
                    let x = point.x - geo[proxy.plotAreaFrame].origin.x
                    if let date: Date = proxy.value(atX: x) { selected = Calendar.current.startOfDay(for: date) }
                }
            }
        }
    }
}
struct Trends: View {
    @ObservedObject var health: HealthReader
    @State private var count = 7
    @State private var selected: Date?
    private var days: [DayTotal] {
        let calendar = Calendar.current, today = calendar.startOfDay(for: Date())
        let values = Dictionary(uniqueKeysWithValues: health.report.history.map { ($0.date, $0.seconds) })
        return (-(count - 1)...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return DayTotal(date: date, seconds: values[date, default: 0])
        }
    }
    var body: some View {
        Page("聆听趋势", health: health) {
            Picker("统计范围", selection: $count) { Text("近 7 天").tag(7); Text("近 30 天").tag(30) }.pickerStyle(.segmented)
            VStack(alignment: .leading, spacing: 20) {
                Text("这段时间，听见了多少").font(.subheadline).foregroundColor(.secondary)
                Text(timeText(days.reduce(0) { $0 + $1.seconds })).font(.system(size: 28, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                ListeningChart(days: days, selected: $selected, color: teal).frame(height: 210)
                if let day = days.first(where: { $0.date == selected }) {
                    Text("\(day.date.formatted(.dateTime.month().day())) · \(timeText(day.seconds, exact: true))").font(.caption).foregroundColor(teal)
                } else { Text("点击柱状图查看精确时长 · 单位：小时").font(.caption).foregroundColor(.secondary) }
            }.padding(20).pulseCard()
            HStack(spacing: 12) {
                MetricTile(title: "每天平均", value: "\(Int(days.reduce(0) { $0 + $1.seconds } / Double(count) / 60))", unit: "分钟", detail: "含没有记录的日期", icon: "chart.line.uptrend.xyaxis", color: sky)
                MetricTile(title: "有记录", value: "\(days.filter { $0.seconds > 0 }.count)", unit: "天", detail: "最近 \(count) 个自然日", icon: "calendar", color: violet)
            }
            Text("每日记录").font(.title3.bold()).padding(.top, 4)
            VStack(spacing: 0) {
                ForEach(Array(days.reversed())) { day in
                    HStack {
                        Text(day.date.formatted(.dateTime.month().day().weekday(.abbreviated))).font(.subheadline)
                        Spacer(); Text(timeText(day.seconds)).font(.subheadline.monospacedDigit()).foregroundColor(.secondary)
                    }.padding(.vertical, 14)
                    if day.id != days.first?.id { Divider() }
                }
            }.padding(.horizontal, 18).pulseCard()
        }.onChange(of: count) { _ in selected = nil }
    }
}
struct DevicePage: View {
    @ObservedObject var health: HealthReader
    var body: some View {
        Page("我的耳机", health: health) {
            Text("每一副耳机，都陪你听过一段时光。").font(.subheadline).foregroundColor(.secondary)
            if health.report.devices.isEmpty { Notice(health: health) }
            ForEach(health.report.devices) { device in
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image(systemName: "headphones").font(.title2).foregroundColor(teal).frame(width: 52, height: 52).background(teal.opacity(0.09)).clipShape(RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(device.name).font(.headline)
                            Text("健康记录中的设备名称").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Text(timeText(device.seconds, exact: true)).font(.system(size: 23, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                    ProgressView(value: min(1, device.seconds / max(1, health.report.total))).tint(teal)
                }.padding(20).pulseCard()
            }
            Text("按设备名称合并，同名耳机归为一组。每组各自去重，总累计跨设备去重，因此分项之和可能大于总计。此处不代表蓝牙实时连接状态。").font(.caption).foregroundColor(.secondary).lineSpacing(4)
        }
    }
}
struct Notice: View {
    @ObservedObject var health: HealthReader
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(health.busy ? "正在整理聆听记录" : "连接你的聆听时光", systemImage: "heart.text.square").font(.headline).foregroundColor(teal)
            if !health.message.isEmpty { Text(health.message).font(.subheadline).foregroundColor(.secondary) }
            Button("连接 Apple 健康") { health.connect() }.buttonStyle(.borderedProminent).disabled(health.busy)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).pulseCard()
    }
}
struct SettingsPage: View {
    @ObservedObject var health: HealthReader
    @Binding var appearance: Int
    var body: some View {
        Page("设置", health: health) {
            VStack(alignment: .leading, spacing: 16) {
                Label("外观", systemImage: "circle.lefthalf.filled").font(.headline)
                Picker("外观", selection: $appearance) { Text("跟随系统").tag(0); Text("浅色").tag(1); Text("深色").tag(2) }.pickerStyle(.segmented)
            }.padding(20).pulseCard()
            VStack(alignment: .leading, spacing: 14) {
                Label("健康与同步", systemImage: "heart.fill").font(.headline).foregroundColor(teal)
                if let date = health.refreshed { Text("上次读取：\(date.formatted(date: .abbreviated, time: .standard))").font(.caption).foregroundColor(.secondary) }
                if let date = health.report.last { Text("最新记录：\(date.formatted(date: .abbreviated, time: .standard))").font(.caption).foregroundColor(.secondary) }
                if let date = health.report.first { Text("最早记录：\(date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundColor(.secondary) }
                Button("重新请求健康授权") { health.connect() }.disabled(health.busy)
                Text("打开 App 以及前台健康数据变化时重新读取，后台不持续运行。读取权限可在 Apple 健康中管理。").font(.caption).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20).pulseCard()
            VStack(alignment: .leading, spacing: 14) {
                Label("统计方式", systemImage: "info.circle").font(.headline)
                Text("仅计入名称含 AirPods 的耳机音频音量记录。合并重叠时间，按手机本地日历拆分跨日记录。时间反映有音频记录的区间。").font(.subheadline).foregroundColor(.secondary)
                Text("已排除其他耳机或无法识别设备的记录：\(health.report.excluded) 条").font(.caption).foregroundColor(.secondary)
                Text("你的健康数据只在本机计算，不上传。").font(.caption).foregroundColor(teal)
            }.padding(20).pulseCard()
            Text("聆听时光 · 1.2.0").font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.top, 8)
        }
    }
}
extension View {
    func pulseCard() -> some View {
        self.background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.025), radius: 12, x: 0, y: 4)
    }
}
