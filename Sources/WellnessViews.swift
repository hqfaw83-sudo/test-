import SwiftUI
import Charts

struct WellnessHub: View {
    @EnvironmentObject private var health: WellnessReader
    @State private var page = ProcessInfo.processInfo.arguments.contains("--preview-analysis") ? 1 : ProcessInfo.processInfo.arguments.contains("--preview-metrics") ? 2 : 0
    @State private var days = 7
    @State private var search = ""
    @State private var selected: HealthMetric?
    @State private var editing = false
    @AppStorage("wellnessCards") private var cards = "sleep,activity,heart,hrv,oxygen"
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("健康页面", selection: $page) { Text("今日").tag(0); Text("分析").tag(1); Text("指标").tag(2) }.pickerStyle(.segmented)
            if !health.requested || !health.message.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("你的健康概览", systemImage: "heart.text.square").font(.headline)
                    Text(health.message).font(.caption).foregroundColor(.white.opacity(0.6))
                    Button(health.requested ? "检查健康授权" : "连接健康指标") { health.connect() }.buttonStyle(.borderedProminent).tint(ice).foregroundColor(.black).disabled(health.busy)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20).glass(radius: 25)
            }
            if health.busy { HStack { ProgressView(); Text("正在整理健康记录…").font(.caption).foregroundColor(.secondary) } }
            if page == 0 {
                ForEach(cards.split(separator: ",").map(String.init), id: \.self) { id in
                    if id == "sleep" { SleepSummaryCard() }
                    else if id == "activity" { ActivitySummaryCard() }
                    else if let metric = health.metrics.first(where: { $0.id == id }) {
                        Button { selected = metric } label: { MetricSummaryCard(metric: metric, reading: health.readings[id]) }.buttonStyle(.plain)
                    }
                }
                Button { editing = true } label: { Label("编辑首页卡片", systemImage: "square.grid.2x2").font(.caption).frame(maxWidth: .infinity).padding(10) }.tint(ice)
            } else if page == 1 { analysis }
            else {
                HStack { Image(systemName: "magnifyingglass"); TextField("搜索健康指标", text: $search).font(.subheadline) }.padding(14).glass(radius: 22)
                ForEach(health.metrics.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.unitLabel.localizedCaseInsensitiveContains(search) }) { metric in
                    Button { selected = metric } label: { MetricSummaryCard(metric: metric, reading: health.readings[metric.id], compact: true) }.buttonStyle(.plain)
                }
            }
            if let date = health.updated { Text("读取于 \(date.formatted(date: .omitted, time: .standard)) · 新记录可能延迟同步").font(.system(size: 10)).foregroundColor(.white.opacity(0.4)) }
        }
        .sheet(item: $selected) { MetricDetail(metric: $0) }
        .sheet(isPresented: $editing) { CardEditor(cards: $cards) }
    }
    private var analysis: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("分析范围", selection: $days) { Text("近 7 天").tag(7); Text("近 30 天").tag(30); Text("近 90 天").tag(90) }.pickerStyle(.segmented)
            Text("健康趋势").font(.title3.bold())
            Text("按实际可读记录展示，不生成综合健康分或压力评分。").font(.caption).foregroundColor(.secondary)
            let cutoff = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: Date()))!
            let sleeps = health.sleepHistory.filter { $0.date >= cutoff }
            VStack(alignment: .leading, spacing: 12) {
                Label("主要睡眠 · 日均", systemImage: "moon.zzz.fill").font(.headline).foregroundColor(.purple)
                Text(sleeps.isEmpty ? "—" : timeText(sleeps.reduce(0) { $0 + $1.value } / Double(sleeps.count) * 3600)).font(.title2.bold())
                if !sleeps.isEmpty { Chart(sleeps) { point in BarMark(x: .value("日期", point.date), y: .value("小时", point.value)).foregroundStyle(.purple.opacity(0.8)).cornerRadius(4) }.frame(height: 100) }
                Text("\(sleeps.count) 个有记录的日期").font(.caption).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20).glass(radius: 25)
            ForEach(health.metrics.filter { ["steps", "energy", "heart", "hrv", "oxygen", "breathing"].contains($0.id) }) { metric in
                let points = (health.readings[metric.id]?.points ?? []).filter { $0.date >= cutoff }
                Button { selected = metric } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Label(metric.title, systemImage: metric.symbol).foregroundColor(metric.color); Spacer(); Image(systemName: "chevron.right").foregroundColor(.secondary) }.font(.subheadline.weight(.semibold))
                        Text(metric.text(points.isEmpty ? nil : points.reduce(0) { $0 + $1.value } / Double(points.count)) + " " + metric.unitLabel).font(.title2.bold())
                        if !points.isEmpty { HealthTrendChart(metric: metric, points: points).frame(height: 95) }
                        Text("有记录日期的日均 · \(points.count) 天").font(.caption).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(20).glass(radius: 25)
                }.buttonStyle(.plain)
            }
        }
    }
}
struct MetricSummaryCard: View {
    let metric: HealthMetric
    let reading: MetricReading?
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label(metric.title, systemImage: metric.symbol).font(.subheadline.weight(.semibold)).foregroundColor(metric.color)
                Spacer(); Text(metric.cumulative ? "今日" : "最新").font(.system(size: 10)).foregroundColor(.secondary)
                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(metric.text(reading?.value)).font(.system(size: compact ? 26 : 34, weight: .bold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
                Text(metric.unitLabel).font(.caption).foregroundColor(.secondary)
                Spacer()
            }
            if let date = reading?.date { Text(date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 10)).foregroundColor(.secondary) }
            else { Text(reading?.error == nil ? "暂无可读数据" : "暂时无法读取").font(.caption).foregroundColor(.secondary) }
            if !compact, let points = reading?.points, !points.isEmpty {
                HealthTrendChart(metric: metric, points: Array(points.suffix(7))).frame(height: 65)
            }
        }.padding(18).glass(radius: 25)
    }
}
struct HealthTrendChart: View {
    let metric: HealthMetric
    let points: [MetricPoint]
    var body: some View {
        Chart(points) { point in
            if metric.cumulative {
                BarMark(x: .value("日期", point.date, unit: .day), y: .value(metric.unitLabel, point.value)).foregroundStyle(metric.color.opacity(0.75)).cornerRadius(4)
            } else {
                LineMark(x: .value("日期", point.date), y: .value(metric.unitLabel, point.value)).foregroundStyle(metric.color)
                PointMark(x: .value("日期", point.date), y: .value(metric.unitLabel, point.value)).foregroundStyle(metric.color).symbolSize(13)
            }
        }
    }
}
struct MetricDetail: View {
    let metric: HealthMetric
    @EnvironmentObject private var health: WellnessReader
    @State private var days = 7
    @Environment(\.dismiss) private var dismiss
    private var points: [MetricPoint] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: Date()))!
        return (health.readings[metric.id]?.points ?? []).filter { $0.date >= cutoff }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    MetricSummaryCard(metric: metric, reading: health.readings[metric.id], compact: true)
                    Picker("范围", selection: $days) { Text("7 天").tag(7); Text("30 天").tag(30); Text("90 天").tag(90) }.pickerStyle(.segmented)
                    if points.isEmpty { Text("这段时间暂无可读记录。").foregroundColor(.secondary).frame(maxWidth: .infinity).padding(30) }
                    else {
                        HealthTrendChart(metric: metric, points: points).frame(height: 220)
                        Text(metric.cumulative ? "图表为每日累计值。" : "图表为每日平均值；上方显示最新一条记录。").font(.caption).foregroundColor(.secondary)
                        ForEach(Array(points.reversed())) { point in
                            HStack { Text(point.date.formatted(date: .abbreviated, time: .omitted)); Spacer(); Text(metric.text(point.value) + " " + metric.unitLabel).monospacedDigit() }.font(.subheadline)
                            Divider()
                        }
                    }
                }.padding(20)
            }.navigationTitle(metric.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
}
struct ActivitySummaryCard: View {
    @EnvironmentObject private var health: WellnessReader
    @AppStorage("personalStepGoal") private var goal = 10000
    @State private var edit = false
    private var steps: Double? { health.readings["steps"]?.value }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Label("今日活动", systemImage: "figure.walk").font(.headline).foregroundColor(.orange); Spacer(); Button("目标") { edit = true }.font(.caption).tint(.orange) }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) { Text(steps.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "—").font(.system(size: 36, weight: .bold, design: .rounded)); Text("步").font(.caption).foregroundColor(.secondary) }
                Spacer()
                VStack(alignment: .leading, spacing: 12) {
                    Text("活动能量  \(health.metrics.first { $0.id == "energy" }!.text(health.readings["energy"]?.value)) 千卡")
                    Text("锻炼时间  \(health.metrics.first { $0.id == "exercise" }!.text(health.readings["exercise"]?.value)) 分钟")
                }.font(.caption).foregroundColor(.secondary)
            }
            ProgressView(value: min(1, max(0, (steps ?? 0) / Double(goal)))).tint(.orange)
            Text("个人目标 \(goal) 步" + (steps == nil ? " · 暂无可读步数" : " · \(Int((steps ?? 0) / Double(goal) * 100))%" )).font(.caption).foregroundColor(.secondary)
        }.padding(20).glass(radius: 25)
            .sheet(isPresented: $edit) { VStack(spacing: 25) { Text("个人步数目标").font(.headline); Stepper("\(goal) 步", value: $goal, in: 1000...50000, step: 500); Text("这是你设置的个人目标。").font(.caption).foregroundColor(.secondary) }.padding(30).presentationDetents([.medium]).preferredColorScheme(.dark) }
    }
}
func sleepStageName(_ value: Int) -> String {
    switch value { case 2: return "清醒"; case 3: return "核心"; case 4: return "深睡"; case 5: return "快速眼动"; default: return "未分期" }
}
func sleepStageColor(_ value: Int) -> Color {
    switch value { case 2: return .orange; case 3: return .cyan; case 4: return .blue; case 5: return .purple; default: return .gray }
}
struct SleepSummaryCard: View {
    @EnvironmentObject private var health: WellnessReader
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("最近主要睡眠", systemImage: "moon.zzz.fill").font(.headline).foregroundColor(.purple)
            if let sleep = health.sleep {
                Text(timeText(sleep.seconds)).font(.system(size: 28, weight: .bold, design: .rounded))
                Text("\(sleep.start.formatted(date: .abbreviated, time: .shortened)) — \(sleep.end.formatted(date: .abbreviated, time: .shortened))").font(.system(size: 10)).foregroundColor(.secondary)
                Chart(sleep.spans) { span in
                    BarMark(xStart: .value("开始", span.start), xEnd: .value("结束", span.end), y: .value("阶段", sleepStageName(span.stage)))
                        .foregroundStyle(sleepStageColor(span.stage)).cornerRadius(4)
                }.frame(height: 125)
                Button(expanded ? "收起详情" : "展开详情") { expanded.toggle() }.font(.caption).tint(ice)
                if expanded {
                    ForEach([2, 5, 3, 4, 1], id: \.self) { stage in
                        let duration = WellnessMath.duration(sleep.spans.filter { $0.stage == stage }.map { ($0.start, $0.end) })
                        if duration > 0 { HStack { Circle().fill(sleepStageColor(stage)).frame(width: 6, height: 6); Text(sleepStageName(stage)); Spacer(); Text(timeText(duration)) }.font(.caption) }
                    }
                    Text("来源：\(sleep.source.components(separatedBy: " · ").first ?? sleep.source)").font(.caption2).foregroundColor(.secondary)
                    Text("展示每个日期结束的最长睡眠段，优先使用手表来源；清醒不计入睡眠时长。").font(.caption2).foregroundColor(.secondary)
                    ForEach(health.metrics.filter { ["heart", "hrv"].contains($0.id) }) { metric in
                        NightMetricChart(metric: metric, points: health.nightReadings[metric.id] ?? [])
                    }
                }
            } else { Text("暂无可读睡眠记录").font(.subheadline).foregroundColor(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).glass(radius: 25)
    }
}
struct NightMetricChart: View {
    let metric: HealthMetric
    let points: [MetricPoint]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("睡眠时段 · " + metric.title, systemImage: metric.symbol).font(.caption.weight(.semibold)).foregroundColor(metric.color)
            if points.isEmpty { Text("暂无该时段可读采样").font(.caption2).foregroundColor(.secondary) }
            else {
                let values = points.map { $0.value }
                Text("均值 \(metric.text(values.reduce(0, +) / Double(values.count))) · 最低 \(metric.text(values.min())) · 最高 \(metric.text(values.max())) \(metric.unitLabel)").font(.system(size: 10)).foregroundColor(.secondary)
                HealthTrendChart(metric: metric, points: points).frame(height: 110)
                Text("按该睡眠起止时段内采样计算，可能包含清醒阶段；优先使用手表数据。").font(.system(size: 9)).foregroundColor(.secondary)
            }
        }.padding(.top, 8)
    }
}
struct CardEditor: View {
    @Binding var cards: String
    @EnvironmentObject private var health: WellnessReader
    @Environment(\.dismiss) private var dismiss
    private var ids: [String] { cards.split(separator: ",").map(String.init) }
    private var options: [(String, String)] { [("sleep", "主要睡眠"), ("activity", "今日活动")] + health.metrics.map { ($0.id, $0.title) } }
    var body: some View {
        NavigationStack {
            List {
                Section("显示与隐藏") {
                    ForEach(options, id: \.0) { option in
                        Toggle(option.1, isOn: Binding(get: { ids.contains(option.0) }, set: { enabled in var updated = ids; if enabled { if !updated.contains(option.0) { updated.append(option.0) } } else { updated.removeAll { $0 == option.0 } }; cards = updated.joined(separator: ",") }))
                    }
                }
                Section("拖动调整顺序") {
                    ForEach(ids, id: \.self) { id in Text(options.first { $0.0 == id }?.1 ?? id) }
                        .onMove { source, destination in var updated = ids; updated.move(fromOffsets: source, toOffset: destination); cards = updated.joined(separator: ",") }
                }
            }.environment(\.editMode, .constant(.active)).navigationTitle("首页卡片").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
}
struct WatchCompanionCard: View {
    @EnvironmentObject private var health: WellnessReader
    @EnvironmentObject private var connection: ConnectionMonitor
    @AppStorage("watchCompanionStart") private var override = 0.0
    @AppStorage("watchModelOverride") private var modelOverride = ""
    @State private var modelEditing = false
    @State private var modelDraft = ""
    @State private var editing = false
    @State private var selection = Date()
    private var start: Date? { override > 0 ? Date(timeIntervalSince1970: override) : health.firstWatchRecord }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Apple Watch", systemImage: "applewatch").font(.headline)
                Spacer()
                Text(connection.watchPaired.map { $0 ? "已配对" : "未配对" } ?? (health.firstWatchRecord == nil ? "配对状态未确认" : "有历史记录")).font(.caption).foregroundColor(connection.watchPaired == true ? .green : .secondary)
            }
            Text(modelOverride.isEmpty ? (health.latestWatchModel ?? "型号待确认") : modelOverride)
                .font(.system(size: 19, weight: .semibold, design: .rounded)).foregroundColor(ice)
            if modelOverride.isEmpty {
                if let identifier = health.latestWatchIdentifier {
                    Text("最近健康记录识别 · \(identifier)").font(.caption2).foregroundColor(.secondary)
                } else { Text("读取健康记录后识别型号，也可手动选择。").font(.caption2).foregroundColor(.secondary) }
            } else { Text("你设置的手表型号").font(.caption2).foregroundColor(.secondary) }
            Button("选择或更正型号") { modelDraft = modelOverride; modelEditing = true }.font(.caption).tint(ice)
            HStack(spacing: 20) {
                Image(systemName: "applewatch").font(.system(size: 58, weight: .light)).foregroundColor(ice)
                VStack(alignment: .leading, spacing: 8) {
                    Text("已经陪伴你").font(.caption).foregroundColor(.secondary)
                    if let date = start { Text("\(WellnessMath.companionDays(from: date)) 天").font(.system(size: 32, weight: .bold, design: .rounded)); Text("从 \(date.formatted(date: .abbreviated, time: .omitted)) 开始").font(.caption).foregroundColor(.secondary) }
                    else { Text("设置开始日期").font(.title3.bold()) }
                }
            }
            Text(override > 0 ? "按你手动设置的日期计算。" : "按最早可读的 Apple Watch 心率记录估算，不等同购买或首次配对日期，也可能包含旧手表记录。").font(.system(size: 10)).foregroundColor(.secondary)
            HStack {
                Button("设置陪伴日期") { selection = start ?? Date(); editing = true }.font(.caption).tint(ice)
                Spacer()
                if !health.requested { Button("读取手表健康记录") { health.connect() }.font(.caption).tint(ice) }
            }
        }.padding(20).glass(radius: 28)
            .sheet(isPresented: $modelEditing) {
                NavigationStack {
                    Form {
                        Section("手表型号") {
                            Picker("选择型号", selection: $modelDraft) {
                                Text("从最近健康记录识别").tag("")
                                ForEach(WatchModel.choices, id: \.self) { Text($0).tag($0) }
                                if !modelDraft.isEmpty && !WatchModel.choices.contains(modelDraft) { Text(modelDraft).tag(modelDraft) }
                            }
                            TextField("或输入完整型号", text: $modelDraft).autocorrectionDisabled()
                        }
                        Text("健康记录可能来自旧手表。换表后请确认此处型号；手动型号和陪伴日期分别设置。").font(.caption).foregroundColor(.secondary)
                        Link("查看 Apple 官方型号说明", destination: URL(string: "https://support.apple.com/zh-cn/108056")!)
                    }.navigationTitle("Apple Watch 型号").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("保存") { modelOverride = modelDraft.trimmingCharacters(in: .whitespacesAndNewlines); modelEditing = false } } }
                }.preferredColorScheme(.dark)
            }
            .sheet(isPresented: $editing) {
                NavigationStack {
                    Form {
                        DatePicker("开始陪伴日期", selection: $selection, in: ...Date(), displayedComponents: .date)
                        Button("使用最早可读的健康记录") { override = 0; editing = false }
                        Text("可填购买日期或你开始使用这块手表的日期。").font(.caption).foregroundColor(.secondary)
                    }.navigationTitle("陪伴日期").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("保存") { override = selection.timeIntervalSince1970; editing = false } } }
                }.presentationDetents([.medium]).preferredColorScheme(.dark)
            }
    }
}
