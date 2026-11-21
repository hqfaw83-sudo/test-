import SwiftUI
import MediaPlayer
import MusicKit

@MainActor final class MusicReader: ObservableObject {
    @Published var authorized = MPMediaLibrary.authorizationStatus() == .authorized
    @Published var title = "尚未读取到歌曲"
    @Published var artist = "在 Apple Music 中播放后返回这里"
    @Published var album = ""
    @Published var artwork: UIImage?
    @Published var hasItem = false
    @Published var playing = false
    @Published var elapsed = 0.0
    @Published var duration = 0.0
    @Published var busy = false
    @Published var searching = false
    @Published var message = ""
    @Published var searchMessage = ""
    @Published var library: [MPMediaItem] = []
    @Published var songs: [Song] = []
    @Published var canPlayCatalog: Bool?
    private var player: MPMusicPlayerController?
    private var timer: Timer?
    private var tokens: [NSObjectProtocol] = []
    private var visible = false
    private var artworkKey = ""
    private var searchTask: Task<Void, Never>?
    private var searchID = UUID()

    func connect() {
        guard !busy else { return }; busy = true
        MPMediaLibrary.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self = self else { return }; self.busy = false
                self.authorized = status == .authorized
                self.message = self.authorized ? "" : "未获音乐访问权限。可在系统设置中允许媒体与 Apple Music 访问。"
                if self.authorized && self.visible { self.attach() }
            }
        }
    }
    func setVisible(_ value: Bool) {
        visible = value
        authorized = MPMediaLibrary.authorizationStatus() == .authorized
        if value && authorized { attach() } else { detach() }
    }
    private func attach() {
        guard authorized, !ProcessInfo.processInfo.arguments.contains("--ui-preview") else { return }
        if player == nil {
            let controller = MPMusicPlayerController.systemMusicPlayer; player = controller
            controller.beginGeneratingPlaybackNotifications()
            for name in [Notification.Name.MPMusicPlayerControllerNowPlayingItemDidChange, Notification.Name.MPMusicPlayerControllerPlaybackStateDidChange] {
                tokens.append(NotificationCenter.default.addObserver(forName: name, object: controller, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.refresh() }
                })
            }
            let tick = Timer(timeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.refresh() } }
            RunLoop.main.add(tick, forMode: .common); timer = tick
        }
        refresh()
    }
    private func detach() {
        timer?.invalidate(); timer = nil
        for token in tokens { NotificationCenter.default.removeObserver(token) }; tokens = []
        player?.endGeneratingPlaybackNotifications(); player = nil
    }
    func refresh() {
        guard authorized, let player = player else { return }
        let item = player.nowPlayingItem
        hasItem = item != nil; playing = player.playbackState == .playing
        title = item?.title ?? "尚未读取到歌曲"
        artist = item?.artist ?? "在 Apple Music 中播放后返回这里"
        album = item?.albumTitle ?? ""
        let length = item?.playbackDuration ?? 0
        duration = length.isFinite ? max(0, length) : 0
        let time = player.currentPlaybackTime
        elapsed = time.isFinite ? min(duration, max(0, time)) : 0
        let key = "\(item?.persistentID ?? 0):\(title):\(album)"
        if artworkKey != key || artwork == nil {
            artworkKey = key; artwork = item?.artwork?.image(at: CGSize(width: 600, height: 600))
        }
    }
    func toggle() { guard hasItem, let player = player else { return }; if playing { player.pause() } else { player.play() }; refresh() }
    func next() { guard hasItem else { return }; player?.skipToNextItem(); refresh() }
    func previous() { guard hasItem else { return }; player?.skipToPreviousItem(); refresh() }
    func seek(_ time: Double) { guard hasItem, time.isFinite, duration > 0 else { return }; player?.currentPlaybackTime = min(duration, max(0, time)); refresh() }
    func search(_ text: String, catalog: Bool) {
        guard authorized else { message = "请先连接 Apple Music。"; return }
        let term = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !catalog || !term.isEmpty else { searchMessage = "输入歌曲或歌手后搜索。"; return }
        searchTask?.cancel(); searchID = UUID(); let requestID = searchID
        searching = true; searchMessage = ""; songs = []; library = []
        searchTask = Task {
            if catalog {
                do {
                    var request = MusicCatalogSearchRequest(term: term, types: [Song.self]); request.limit = 20
                    let response = try await request.response()
                    guard !Task.isCancelled, searchID == requestID else { return }
                    songs = Array(response.songs)
                    searchMessage = songs.isEmpty ? "没有找到匹配歌曲。" : ""
                    if let subscription = try? await MusicSubscription.current { canPlayCatalog = subscription.canPlayCatalogContent }
                } catch {
                    guard !Task.isCancelled, searchID == requestID else { return }
                    searchMessage = "暂时无法访问 Apple Music 曲库。可用下方入口前往 Apple Music 搜索；此安装可能尚未开通音乐服务。"
                }
            } else {
                let items = await Task.detached(priority: .userInitiated) {
                    let query = MPMediaQuery.songs()
                    if !term.isEmpty { query.addFilterPredicate(MPMediaPropertyPredicate(value: term, forProperty: MPMediaItemPropertyTitle, comparisonType: .contains)) }
                    return Array((query.items ?? []).prefix(50))
                }.value
                guard !Task.isCancelled, searchID == requestID else { return }
                library = items
                searchMessage = items.isEmpty ? "资料库暂无匹配歌曲；可尝试 Apple Music 曲库搜索。" : "显示前 \(items.count) 首歌曲"
            }
            if searchID == requestID { searching = false }
        }
    }
    func clearSearch() { searchTask?.cancel(); searchID = UUID(); searching = false; songs = []; library = []; searchMessage = "" }
    func playLibrary(_ item: MPMediaItem) {
        guard authorized, !busy else { return }; attach(); guard let player = player else { return }
        player.setQueue(with: MPMediaItemCollection(items: [item])); prepare(player)
    }
    func playCatalog(_ song: Song) {
        guard authorized, !busy else { return }
        guard canPlayCatalog != false else { message = "完整播放需要可用的 Apple Music 订阅；也可前往 Apple Music 查看。"; return }
        attach(); guard let player = player else { return }
        player.setQueue(with: [song.id.rawValue]); prepare(player)
    }
    private func prepare(_ player: MPMusicPlayerController) {
        busy = true; message = ""
        player.prepareToPlay { [weak self] error in
            Task { @MainActor in
                guard let self = self else { return }; self.busy = false
                if let error = error { self.message = "无法播放：\(error.localizedDescription)" }
                else { player.play(); self.refresh() }
            }
        }
    }
    deinit { timer?.invalidate(); searchTask?.cancel(); for token in tokens { NotificationCenter.default.removeObserver(token) } }
}
