import SwiftUI
import Charts
import PhotosUI

let ice = Color(red: 0.60, green: 0.80, blue: 1)
let gold = Color(red: 0.94, green: 0.79, blue: 0.45)
let moodOptions = ["😌", "😊", "🥰", "🤩", "😎", "🥳", "🥺", "😴", "😢", "😤", "🤯", "🫠"]
func timeText(_ seconds: Double, exact: Bool = false) -> String {
    let s = max(0, Int(seconds))
    return "\(s / 3600) 小时 \(s % 3600 / 60) 分" + (exact ? " \(s % 60) 秒" : "")
}
func dayKey(_ date: Date) -> String {
    let d = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return "\(d.year ?? 0)-\(d.month ?? 0)-\(d.day ?? 0)"
}
final class PersonalStyle: ObservableObject {
    @Published var moods: [String: String] = UserDefaults.standard.dictionary(forKey: "dailyMoods") as? [String: String] ?? [:]
    @Published var colors: [String: Int] = UserDefaults.standard.dictionary(forKey: "deviceColors") as? [String: Int] ?? [:]
    @Published var icons: [String: String] = UserDefaults.standard.dictionary(forKey: "deviceIcons") as? [String: String] ?? [:]
    var todayMood: String { moods[dayKey(Date())] ?? "😌" }
    func setMood(_ mood: String, on date: Date = Date()) { moods[dayKey(date)] = mood; UserDefaults.standard.set(moods, forKey: "dailyMoods") }
    func setColor(_ color: Int, for name: String) { colors[name] = color; UserDefaults.standard.set(colors, forKey: "deviceColors") }
    func icon(for name: String) -> PodModel { icons[name].flatMap(PodModel.init(rawValue:)) ?? PodModel.detect(name) }
    func setIcon(_ model: PodModel?, for name: String) { icons[name] = model?.rawValue; UserDefaults.standard.set(icons, forKey: "deviceIcons") }
}
@main struct ListeningApp: App {
    var body: some Scene { WindowGroup { if ProcessInfo.processInfo.arguments.contains("--preview-icons") { IconGallery() } else { GlassDashboard() } } }
}
struct GlassDashboard: View {
    @StateObject private var health = HealthReader()
    @StateObject private var style = PersonalStyle()
    @StateObject private var wellness = WellnessReader()
    @StateObject private var connection = ConnectionMonitor()
    @StateObject private var music = MusicReader()
    @State private var tab = ProcessInfo.processInfo.arguments.contains("--preview-music") ? 4 : ProcessInfo.processInfo.arguments.contains("--preview-health") ? 3 : ProcessInfo.processInfo.arguments.contains("--preview-stats") ? 1 : ProcessInfo.processInfo.arguments.contains("--preview-devices") ? 2 : 0
    @State private var settings = false
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("glassTheme") private var theme = 0
    @AppStorage("motionEnabled") private var motion = true
    @AppStorage("customBackdrop") private var photoData = Data()
    var body: some View {
        ZStack {
            GlassBackdrop(theme: theme, photo: photoData)
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Text(["今天", "统计", "设备", "健康", "音乐"][tab]).font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Button { settings = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 38, height: 38).glass(radius: 19) }.accessibilityLabel("外观和设置")
                    }.padding(.horizontal, 4)
                    if tab == 0 { GlassToday(health: health, style: style, animate: motion && !reduceMotion && phase == .active) }
                    if tab == 1 { GlassStats(health: health, animate: motion && !reduceMotion) }
                    if tab == 4 { MusicPage() }
                    if tab == 3 { WellnessHub() }
                    if tab == 2 { GlassDevices(health: health, style: style, animate: motion && !reduceMotion) }
                }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20)
                    .frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.refreshable { health.refresh(); wellness.refreshIfRequested(); connection.refresh() }
        }
        .safeAreaInset(edge: .bottom) { navigation.padding(.bottom, 8) }
        .foregroundColor(.white).preferredColorScheme(.dark)
        .sheet(isPresented: $settings) { GlassSettings(health: health, theme: $theme, motion: $motion, photoData: $photoData) }
        .environmentObject(wellness).environmentObject(connection).environmentObject(music)
        .task { if !ProcessInfo.processInfo.arguments.contains("--ui-preview") { health.connect(); wellness.refreshIfRequested() }; connection.refresh() }
        .onChange(of: phase) { value in if value == .active && !ProcessInfo.processInfo.arguments.contains("--ui-preview") { health.refresh(); wellness.refreshIfRequested(); connection.refresh() } }
    }
    private var navigation: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) { tab = index }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: ["square.grid.2x2", "chart.bar.fill", "airpodspro", "heart.text.square", "music.note"][index]).font(.system(size: 20, weight: .medium))
                        Text(["今天", "统计", "设备", "健康", "音乐"][index]).font(.system(size: 10, weight: .semibold))
                    }.frame(maxWidth: .infinity).frame(height: 57)
                        .foregroundColor(tab == index ? ice : .white.opacity(0.5))
                        .background { if tab == index { Capsule().fill(Color.white.opacity(0.10)).overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1)) } }
                }.buttonStyle(.plain).accessibilityAddTraits(tab == index ? .isSelected : [])
            }
        }.padding(5).frame(maxWidth: 420).glass(radius: 40).padding(.horizontal, 20)
    }
}
struct GlassBackdrop: View {
    let theme: Int
    let photo: Data
    var colors: [Color] {
        switch theme {
        case 1: return [Color(red: 0.24, green: 0.18, blue: 0.48), Color(red: 0.08, green: 0.07, blue: 0.18), .black]
        case 2: return [Color(red: 0.46, green: 0.36, blue: 0.14), Color(red: 0.13, green: 0.13, blue: 0.10), .black]
        default: return [Color(red: 0.09, green: 0.30, blue: 0.46), Color(red: 0.045, green: 0.10, blue: 0.14), Color(red: 0.018, green: 0.03, blue: 0.045)]
        }
    }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                if theme == 3, let image = UIImage(data: photo) {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped()
                    Color.black.opacity(0.5)
                }
                Ellipse().fill(colors[0].opacity(0.65)).frame(width: geo.size.width * 1.4, height: 280).blur(radius: 70).offset(x: 80, y: -geo.size.height * 0.36)
                Canvas { context, size in
                    var grid = Path()
                    for x in stride(from: 0.0, through: size.width, by: 23) { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height)) }
                    for y in stride(from: 0.0, through: size.height, by: 23) { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y)) }
                    context.stroke(grid, with: .color(.white.opacity(0.035)), lineWidth: 0.5)
                }
            }
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}
struct GlassToday: View {
    @ObservedObject var health: HealthReader
    @ObservedObject var style: PersonalStyle
    let animate: Bool
    @State private var moodSheet = ProcessInfo.processInfo.arguments.contains("--preview-mood")
    @State private var calendarSheet = false
    var body: some View {
        VStack(spacing: 16) {
            AudioConnectionCard()
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(Date().formatted(.dateTime.month().day().weekday(.wide))).font(.system(size: 11)).foregroundColor(.white.opacity(0.58))
                        HStack(spacing: 10) {
                            Text("今天").font(.system(size: 32, weight: .bold, design: .rounded))
                            if health.busy { ProgressView().scaleEffect(0.65) }
                        }
                    }
                    Spacer()
                    Button { health.loaded ? health.refresh() : health.connect() } label: { Image(systemName: "arrow.clockwise").frame(width: 38, height: 38).background(.white.opacity(0.07), in: Circle()) }.disabled(health.busy).accessibilityLabel("刷新聆听记录")
                }
                GravityToy(mood: style.todayMood, model: style.icon(for: health.report.todayDevices.first?.name ?? health.report.devices.first?.name ?? "AirPods"), enabled: animate)
                    .frame(height: 245).padding(.top, 4)
                HStack {
                    Button { moodSheet = true } label: { Label("记录心情", systemImage: "face.smiling").font(.system(size: 11)).foregroundColor(.white.opacity(0.65)) }
                    Spacer()
                    Text(animate ? "耳机居中，表情跟着你动" : "静静听，也很好").font(.system(size: 9)).foregroundColor(.white.opacity(0.35))
                }.padding(.bottom, 24)
                Text("今日佩戴时长 · 音频记录").font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(health.report.today / 3600))").font(.system(size: 58, weight: .bold, design: .rounded))
                    Text("小时").font(.system(size: 12)).foregroundColor(.white.opacity(0.55))
                    Text("\(Int(health.report.today) % 3600 / 60)").font(.system(size: 58, weight: .bold, design: .rounded)).padding(.leading, 9)
                    Text("分钟").font(.system(size: 12)).foregroundColor(.white.opacity(0.55))
                }.minimumScaleFactor(0.6).lineLimit(1)
                Divider().overlay(.white.opacity(0.05)).padding(.vertical, 18)
                HStack(spacing: 12) {
                    PodsArtwork(model: style.icon(for: health.report.todayDevices.first?.name ?? "AirPods"), showsCase: false).frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今天用得最多").font(.system(size: 9)).foregroundColor(.white.opacity(0.45))
                        Text(health.report.todayDevices.first?.name ?? "等待今日的聆听记录").font(.system(size: 12, weight: .semibold))
                    }
                    Spacer()
                }
            }.padding(22).glass(radius: 32)
            HStack(spacing: 12) {
                Button { calendarSheet = true } label: {
                    HStack { Text(style.todayMood).font(.title2); VStack(alignment: .leading, spacing: 4) { Text("心情日历").font(.system(size: 12, weight: .medium)); Text("收好每天的情绪").font(.system(size: 9)).foregroundColor(.white.opacity(0.45)) }; Spacer(); Image(systemName: "chevron.right").font(.caption2).opacity(0.5) }.padding(16).glass(radius: 23)
                }.buttonStyle(.plain)
            }
            if !health.message.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(health.message).font(.caption).foregroundColor(.white.opacity(0.65))
                    Button("连接 Apple 健康") { health.connect() }.buttonStyle(.bordered).tint(ice).disabled(health.busy)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(18).glass(radius: 23)
            }
            Text("数据来自耳机音频记录，健康写入可能延迟；仅佩戴或开启降噪可能不计入。").font(.system(size: 10)).foregroundColor(.white.opacity(0.38)).padding(.horizontal, 8)
        }
        .sheet(isPresented: $moodSheet) { MoodPicker(style: style) }
        .sheet(isPresented: $calendarSheet) { MoodCalendar(style: style) }
    }
}
func symbolFor(_ name: String) -> String { name.localizedCaseInsensitiveContains("Max") ? "airpodsmax" : name.localizedCaseInsensitiveContains("Pro") ? "airpodspro" : "airpods" }
struct GlassStats: View {
    @ObservedObject var health: HealthReader
    let animate: Bool
    @State private var range = 7
    @State private var selected: Date?
    var days: [DayTotal] {
        let calendar = Calendar.current, today = calendar.startOfDay(for: Date())
        let values = Dictionary(uniqueKeysWithValues: health.report.history.map { ($0.date, $0.seconds) })
        return (-(range - 1)...0).compactMap { i in calendar.date(byAdding: .day, value: i, to: today).map { DayTotal(date: $0, seconds: values[$0, default: 0]) } }
    }
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                ParticleHalo(animate: animate).frame(height: 290)
                VStack(spacing: 8) {
                    Text("\(Int(health.report.total / 3600))").font(.system(size: 53, weight: .bold, design: .rounded))
                    Text("小时 \(Int(health.report.total) % 3600 / 60) 分钟").font(.system(size: 13)).foregroundColor(gold)
                    Text("历史累计聆听").font(.system(size: 10)).foregroundColor(.white.opacity(0.45))
                }
            }
            HStack(spacing: 12) {
                glassMetric("有记录的日子", "\(health.report.days)", "天")
                glassMetric("近 7 天", "\(Int(health.report.week.reduce(0) { $0 + $1.seconds } / 60))", "分钟")
            }
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("聆听趋势").font(.headline); Spacer()
                    Picker("范围", selection: $range) { Text("近 7 天").tag(7); Text("近 30 天").tag(30) }.pickerStyle(.menu).tint(ice)
                }
                Text(timeText(days.reduce(0) { $0 + $1.seconds })).font(.system(size: 26, weight: .semibold, design: .rounded))
                Chart(days) { day in
                    BarMark(x: .value("日期", day.date, unit: .day), y: .value("小时", day.seconds / 3600))
                        .foregroundStyle(LinearGradient(colors: [ice, ice.opacity(0.18)], startPoint: .top, endPoint: .bottom)).cornerRadius(4)
                        .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted)).accessibilityValue(timeText(day.seconds, exact: true))
                    if selected == day.date { RuleMark(x: .value("选择日期", day.date, unit: .day)).foregroundStyle(.white.opacity(0.3)) }
                }
                .chartYScale(domain: 0...max(1, (days.map { $0.seconds / 3600 }.max() ?? 0) * 1.15))
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: range > 7 ? 7 : 1)) { _ in AxisValueLabel(format: .dateTime.day()) } }
                .frame(height: 160)
                .chartOverlay { proxy in GeometryReader { g in Rectangle().fill(.clear).contentShape(Rectangle()).onTapGesture { point in
                    if let date: Date = proxy.value(atX: point.x - g[proxy.plotAreaFrame].origin.x) { selected = Calendar.current.startOfDay(for: date) }
                } } }
                if let day = days.first(where: { $0.date == selected }) {
                    Text("\(day.date.formatted(.dateTime.month().day())) · \(timeText(day.seconds, exact: true))").font(.caption).foregroundColor(ice)
                } else { Text("点选柱形查看当天时长 · 单位：小时").font(.system(size: 10)).foregroundColor(.white.opacity(0.4)) }
            }.padding(20).glass(radius: 28)
        }.onChange(of: range) { _ in selected = nil }
    }
    private func glassMetric(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
            HStack(alignment: .firstTextBaseline, spacing: 4) { Text(value).font(.system(size: 29, weight: .bold, design: .rounded)); Text(unit).font(.system(size: 10)).foregroundColor(.white.opacity(0.5)) }.lineLimit(1).minimumScaleFactor(0.5)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).glass(radius: 24)
    }
}
struct ParticleHalo: View {
    let animate: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 25, paused: !animate)) { timeline in
            Canvas { context, size in
                let t = animate ? timeline.date.timeIntervalSinceReferenceDate * 0.04 : 0
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0..<270 {
                    let seed = Double(i), angle = seed * 2.399963 + t
                    let radius = min(size.width, size.height) * (0.32 + Double(i % 23) / 190)
                    let x = center.x + cos(angle) * radius, y = center.y + sin(angle) * radius * 0.86
                    let dot = i % 11 == 0 ? 2.1 : 0.9
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)), with: .color(gold.opacity(0.18 + Double(i % 7) / 10)))
                }
            }
        }.background { Circle().fill(gold.opacity(0.055)).blur(radius: 38).padding(50) }.accessibilityHidden(true)
    }
}
let cardColors: [Color] = [Color(red: 0.66, green: 0.60, blue: 0.40), Color(red: 0.43, green: 0.65, blue: 0.67), Color(red: 0.58, green: 0.52, blue: 0.75), Color(red: 0.76, green: 0.47, blue: 0.54), Color(red: 0.40, green: 0.59, blue: 0.78), Color(red: 0.55, green: 0.67, blue: 0.47)]
struct GlassDevices: View {
    @ObservedObject var health: HealthReader
    @ObservedObject var style: PersonalStyle
    let animate: Bool
    @State private var index = 0
    @State private var editColor = false
    @State private var editIcon = false
    var devices: [DeviceTotal] { health.report.devices }
    var body: some View {
        VStack(spacing: 14) {
            AudioConnectionCard()
            WatchCompanionCard()
            ZStack {
                ParticleHalo(animate: animate).frame(height: 220)
                VStack(spacing: 7) {
                    Text(timeText(health.report.total)).font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("所有 AirPods 的聆听时光").font(.system(size: 10)).foregroundColor(.white.opacity(0.45))
                }
            }
            if devices.isEmpty {
                VStack(spacing: 20) { PodsArtwork(name: "AirPods").frame(height: 120); Text("连接健康后，耳机会出现在这里").font(.caption).foregroundColor(.white.opacity(0.6)); Button("连接 Apple 健康") { health.connect() }.buttonStyle(.bordered).disabled(health.busy) }.frame(maxWidth: .infinity).padding(30).glass(radius: 30)
            } else {
                TabView(selection: $index) {
                    ForEach(Array(devices.enumerated()), id: \.element.id) { i, device in
                        VStack(alignment: .leading, spacing: 18) {
                            HStack { Text(device.name).font(.system(size: 14, weight: .semibold)); Spacer(); Button { editIcon = true } label: { Image(systemName: "earbuds").font(.caption) }.accessibilityLabel("选择耳机图标"); Button { editColor = true } label: { Image(systemName: "paintpalette").font(.caption) }.accessibilityLabel("更改卡片颜色") }
                            PodsArtwork(name: device.name, model: style.icon(for: device.name)).frame(height: 140).frame(maxWidth: .infinity)
                            Text(timeText(device.seconds)).font(.system(size: 29, weight: .bold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
                            Text("\(Int(device.seconds / max(1, health.report.total) * 100))% 的累计聆听时间").font(.system(size: 10)).foregroundColor(.white.opacity(0.6))
                        }.padding(24).background(cardColors[max(0, min(cardColors.count - 1, style.colors[device.name] ?? i % cardColors.count))].opacity(0.25)).glass(radius: 30).padding(.horizontal, 8).tag(i)
                    }
                }.tabViewStyle(.page(indexDisplayMode: .always)).frame(height: 430)
                Text("左右切换耳机 · 点击耳机按钮选图标").font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
            }
            Text("按健康记录中的设备名称归类。同名耳机会合并；各设备分别去重，总计跨设备去重，因此分项之和可能大于总计。").font(.system(size: 10)).foregroundColor(.white.opacity(0.35)).padding(.horizontal, 12)
        }
        .sheet(isPresented: $editColor) {
            VStack(spacing: 25) {
                Text("卡片颜色").font(.title3.bold())
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                    ForEach(0..<cardColors.count) { color in
                        Button { if devices.indices.contains(index) { style.setColor(color, for: devices[index].name) }; editColor = false } label: { RoundedRectangle(cornerRadius: 16).fill(cardColors[color]).frame(height: 65) }.accessibilityLabel("配色 \(color + 1)")
                    }
                }
            }.padding(30).presentationDetents([.medium]).preferredColorScheme(.dark)
        }
        .sheet(isPresented: $editIcon) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        Text("健康记录可能使用通用名称。可为这组记录选择对应外观，不会更改聆听数据。").font(.caption).foregroundColor(.secondary)
                        Button("恢复自动识别") { if devices.indices.contains(index) { style.setIcon(nil, for: devices[index].name) }; editIcon = false }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            ForEach(PodModel.allCases) { model in
                                Button { if devices.indices.contains(index) { style.setIcon(model, for: devices[index].name) }; editIcon = false } label: {
                                    VStack { PodsArtwork(model: model).frame(height: 95); Text(model.title).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.6) }.padding(6).glass(radius: 16)
                                }.buttonStyle(.plain)
                            }
                        }
                    }.padding(20)
                }.navigationTitle("选择耳机图标").navigationBarTitleDisplayMode(.inline)
            }.preferredColorScheme(.dark)
        }
    }
}
struct MoodPicker: View {
    @ObservedObject var style: PersonalStyle
    @Environment(\.dismiss) private var dismiss
    @AppStorage("customMoodImage") private var customImage = Data()
    @AppStorage("useCustomMoodImage") private var useCustom = false
    @State private var photo: PhotosPickerItem?
    @State private var loading = false
    @State private var error = ""
    var body: some View {
        ScrollView { VStack(spacing: 24) {
            Text("今天，心情是什么颜色？").font(.title3.bold())
            Text("选一个表情，或上传自己的图片，只保存在手机里。").font(.caption).foregroundColor(.secondary)
            if let image = UIImage(data: customImage) {
                HStack(spacing: 16) {
                    Image(uiImage: image).resizable().scaledToFit().frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(useCustom ? "正在使用自定义表情" : "已保存的自定义表情").font(.caption)
                        Button("使用这张表情") { useCustom = true; dismiss() }.font(.caption)
                        Button("移除图片", role: .destructive) { customImage = Data(); useCustom = false }.font(.caption)
                    }
                }.frame(maxWidth: .infinity).padding(14).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
            }
            PhotosPicker(selection: $photo, matching: .images) {
                Label(loading ? "正在处理图片…" : "从相册上传自定义表情", systemImage: "photo.badge.plus").font(.subheadline).frame(maxWidth: .infinity).padding(14)
            }.buttonStyle(.bordered).tint(ice).disabled(loading)
            Text("支持透明图片；上传的图片会随倾斜移动，也可拖动。动图使用第一帧。").font(.caption2).foregroundColor(.secondary)
            if !error.isEmpty { Text(error).font(.caption).foregroundColor(.orange) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 18) {
                ForEach(moodOptions, id: \.self) { mood in Button { useCustom = false; style.setMood(mood); dismiss() } label: { Text(mood).font(.system(size: 36)).frame(width: 58, height: 58).background(.white.opacity(!useCustom && style.todayMood == mood ? 0.14 : 0.035), in: RoundedRectangle(cornerRadius: 18)) } }
            }
        }.padding(25) }.presentationDetents([.large]).preferredColorScheme(.dark)
            .onChange(of: photo) { item in
                Task { @MainActor in
                    guard let item = item else { return }; loading = true; error = ""
                    defer { loading = false }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else { error = "无法读取图片，请重新选择。"; return }
                        let prepared = await Task.detached(priority: .userInitiated) { StickerImage.prepare(data) }.value
                        guard let prepared = prepared else { error = "不支持这张图片，请换一张。"; return }
                        customImage = prepared; useCustom = true; dismiss()
                    } catch { self.error = "图片读取失败，请重试。" }
                }
            }
    }
}
struct MoodCalendar: View {
    @ObservedObject var style: PersonalStyle
    @State private var month = Date()
    private var start: Date { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: month))! }
    private var offset: Int { (Calendar.current.component(.weekday, from: start) - Calendar.current.firstWeekday + 7) % 7 }
    private var count: Int { Calendar.current.range(of: .day, in: .month, for: start)!.count }
    var body: some View {
        VStack(spacing: 24) {
            HStack { Button { move(-1) } label: { Image(systemName: "chevron.left") }; Spacer(); Text(month.formatted(.dateTime.year().month(.wide))).font(.headline); Spacer(); Button { move(1) } label: { Image(systemName: "chevron.right") } }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 17) {
                ForEach(0..<(offset + count), id: \.self) { cell in
                    if cell < offset { Color.clear.frame(height: 40) }
                    else {
                        let date = Calendar.current.date(byAdding: .day, value: cell - offset, to: start)!
                        VStack(spacing: 5) { Text(style.moods[dayKey(date)] ?? "·").font(.system(size: 23)); Text("\(cell - offset + 1)").font(.system(size: 9)).foregroundColor(.secondary) }.frame(height: 40)
                    }
                }
            }
            Text("每格显示当天保存的心情。今日心情可在首页修改。").font(.caption).foregroundColor(.secondary)
        }.padding(25).presentationDetents([.medium, .large]).preferredColorScheme(.dark)
    }
    private func move(_ n: Int) { if let date = Calendar.current.date(byAdding: .month, value: n, to: month) { month = date } }
}
struct GlassSettings: View {
    @EnvironmentObject private var wellness: WellnessReader
    @EnvironmentObject private var connection: ConnectionMonitor
    @ObservedObject var health: HealthReader
    @Binding var theme: Int
    @Binding var motion: Bool
    @Binding var photoData: Data
    @State private var photo: PhotosPickerItem?
    @State private var photoError = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("外观") {
                    Picker("背景", selection: $theme) { Text("深蓝网格").tag(0); Text("紫色星夜").tag(1); Text("金色余晖").tag(2); if !photoData.isEmpty { Text("我的照片").tag(3) } }
                    PhotosPicker(selection: $photo, matching: .images) { Label("选择照片背景", systemImage: "photo") }
                    if !photoError.isEmpty { Text(photoError).font(.caption).foregroundColor(.orange) }
                    Toggle("重力与粒子动效", isOn: $motion)
                    Text("耳机固定在中央；表情随倾斜移动，可拖动并与耳机碰撞。系统开启“减弱动态效果”时停止自动移动。").font(.caption).foregroundColor(.secondary)
                }
                Section("耳机连接") {
                    Text(connection.audioName ?? "未检测到蓝牙音频输出")
                    Button("刷新连接状态") { connection.refresh() }
                    if connection.audioName != nil && !connection.isAirPods { Button("这是我的 AirPods") { connection.confirmAirPods() } }
                    if connection.isAirPods { Button("取消手动识别") { connection.forgetConfirmation() } }
                    Text("以当前音频输出判断连接；闲置但已配对的耳机可能无法检测。改名后的耳机可手动确认。").font(.caption).foregroundColor(.secondary)
                }
                Section("睡眠与身体指标") {
                    Button("连接或调整健康授权") { wellness.connect() }.disabled(wellness.busy)
                    Button("刷新健康指标") { wellness.refreshIfRequested() }.disabled(wellness.busy)
                    Text("只读取你允许的项目。没有授权或没有记录的指标显示为空；陪伴日期可在设备页调整。").font(.caption).foregroundColor(.secondary)
                }
                Section("健康数据") {
                    Button("刷新聆听记录") { health.loaded ? health.refresh() : health.connect() }.disabled(health.busy)
                    Button("重新请求健康授权") { health.connect() }.disabled(health.busy)
                    if let date = health.report.last { Text("最新记录：\(date.formatted(date: .abbreviated, time: .standard))").font(.caption) }
                    if let date = health.refreshed { Text("上次读取：\(date.formatted(date: .omitted, time: .standard))").font(.caption) }
                    Text("打开 App 和前台记录变化时更新；后台不持续运行。").font(.caption).foregroundColor(.secondary)
                }
                Section("关于统计") {
                    Text("仅计入可识别为 AirPods 的耳机音频记录，合并重叠时间，跨日按本地日历拆分。佩戴但没有音频的时间可能无法记录。").font(.caption)
                    Text("排除其他耳机或无法识别设备的记录：\(health.report.excluded) 条").font(.caption)
                    Text("健康记录、照片、心情均在本机处理，不上传。").font(.caption).foregroundColor(ice)
                    Link("Apple 官方产品图片来源", destination: URL(string: "https://www.apple.com/airpods/compare/")!).font(.caption)
                    Text("聆听时光 1.5.0 · 音乐与心情").font(.caption).foregroundColor(.secondary)
                }
            }.navigationTitle("外观与设置").navigationBarTitleDisplayMode(.inline)
        }.preferredColorScheme(.dark)
            .onChange(of: photo) { item in
                Task {
                    guard let item = item else { return }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { photoError = "无法读取照片，请换一张重试。"; return }
                        let scale = min(1, 1600 / max(image.size.width, image.size.height))
                        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                        let renderer = UIGraphicsImageRenderer(size: targetSize)
                        let smaller = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
                        if let jpeg = smaller.jpegData(compressionQuality: 0.8) { photoData = jpeg; theme = 3; photoError = "" }
                    } catch { photoError = "照片读取失败，请重试。" }
                }
            }
    }
}
extension View {
    func glass(radius: CGFloat) -> some View {
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(LinearGradient(colors: [.white.opacity(0.30), .white.opacity(0.05), .white.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8).allowsHitTesting(false) }
            .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 12)
    }
}
