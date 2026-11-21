import SwiftUI
import HealthKit

@main
struct HealthProbeApp: App {
    var body: some Scene { WindowGroup { ProbeView() } }
}

struct ProbeView: View {
    @State private var message = "请先授权，再读取记录。"
    @State private var busy = false
    private let store = HKHealthStore()
    private let sampleType = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure)!

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.055, blue: 0.14).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Text("AirPods 健康读取测试").font(.title.bold())
                Text("本测试仅读取耳机音频音量，不上传数据。记录可能包含其他耳机。")
                Button("1 · 请求健康授权") { authorize() }
                Button("2 · 读取最近一条记录") { readLatest() }
                if busy { ProgressView() }
                ScrollView { Text(message).frame(maxWidth: .infinity, alignment: .leading) }
            }
            .padding(24).foregroundStyle(.white)
            .buttonStyle(.borderedProminent).disabled(busy)
        }
    }

    private func authorize() {
        guard HKHealthStore.isHealthDataAvailable() else {
            message = "当前设备不支持健康数据。"; return
        }
        busy = true
        store.requestAuthorization(toShare: [], read: [sampleType]) { completed, error in
            DispatchQueue.main.async {
                busy = false
                if let error = error { message = "授权请求失败：\(error.localizedDescription)" }
                else { message = completed ? "授权流程结束，请读取记录。此状态不代表已获读取权限。" : "授权流程未完成。" }
            }
        }
    }

    private func readLatest() {
        busy = true
        let query = HKSampleQuery(sampleType: sampleType, predicate: nil, limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            DispatchQueue.main.async {
                busy = false
                if let error = error { message = "读取失败：\(error.localizedDescription)"; return }
                guard let record = samples?.first as? HKQuantitySample else {
                    message = "未读取到记录。可能尚无数据，也可能未授予读取权限；iOS 不允许应用区分这两种情况。"; return
                }
                let start = record.startDate.formatted(date: .abbreviated, time: .standard)
                let end = record.endDate.formatted(date: .abbreviated, time: .standard)
                message = "读取成功\n开始：\(start)\n结束：\(end)\n区间：\(Int(record.endDate.timeIntervalSince(record.startDate))) 秒\n来源：\(record.sourceRevision.source.name)\n设备：\(record.device?.name ?? "未标注")\n型号：\(record.device?.model ?? "未标注")\n\n单条记录区间不等于全天聆听时长。"
            }
        }
        store.execute(query)
    }
}
