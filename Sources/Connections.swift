import SwiftUI
import AVFAudio
import WatchConnectivity

final class ConnectionMonitor: NSObject, ObservableObject, WCSessionDelegate {
    @Published var audioName: String?
    @Published var audioUID: String?
    @Published var isAirPods = false
    @Published var watchPaired: Bool?
    private var token: NSObjectProtocol?
    private var knownAirPods: Set<String> { Set(UserDefaults.standard.stringArray(forKey: "confirmedAirPodsRoutes") ?? []) }
    override init() {
        super.init()
        token = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() }
        refresh()
    }
    func refresh() {
        let bluetooth: Set<AVAudioSession.Port> = [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
        let port = AVAudioSession.sharedInstance().currentRoute.outputs.first { bluetooth.contains($0.portType) }
        audioName = port?.portName; audioUID = port?.uid
        isAirPods = port.map { $0.portName.localizedCaseInsensitiveContains("AirPods") || knownAirPods.contains($0.uid) } ?? false
    }
    func confirmAirPods() {
        guard let uid = audioUID else { return }
        var values = knownAirPods; values.insert(uid)
        UserDefaults.standard.set(Array(values), forKey: "confirmedAirPodsRoutes"); refresh()
    }
    func forgetConfirmation() {
        guard let uid = audioUID else { return }
        var values = knownAirPods; values.remove(uid)
        UserDefaults.standard.set(Array(values), forKey: "confirmedAirPodsRoutes"); refresh()
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.watchPaired = activationState == .activated && error == nil ? session.isPaired : nil }
    }
    func sessionWatchStateDidChange(_ session: WCSession) { DispatchQueue.main.async { self.watchPaired = session.activationState == .activated ? session.isPaired : nil } }
    func sessionDidBecomeInactive(_ session: WCSession) { DispatchQueue.main.async { self.watchPaired = nil } }
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    deinit { if let token = token { NotificationCenter.default.removeObserver(token) } }
}
struct AudioConnectionCard: View {
    @EnvironmentObject private var connection: ConnectionMonitor
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: connection.isAirPods ? "airpodspro" : "antenna.radiowaves.left.and.right").font(.title3).foregroundColor(connection.isAirPods ? .green : ice)
            VStack(alignment: .leading, spacing: 5) {
                Text(connection.isAirPods ? "AirPods 已连接" : connection.audioName == nil ? "未检测到 AirPods 音频连接" : "当前蓝牙音频输出").font(.system(size: 12, weight: .semibold))
                Text(connection.audioName ?? "连接并选作音频输出后更新").font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            Circle().fill(connection.isAirPods ? Color.green : .gray).frame(width: 7, height: 7)
        }.padding(16).glass(radius: 22)
    }
}
