import SwiftUI
import MusicKit
import MediaPlayer

func songTime(_ value: Double) -> String {
    guard value.isFinite else { return "0:00" }
    let seconds = max(0, Int(value)); return String(format: "%d:%02d", seconds / 60, seconds % 60)
}
struct MusicPage: View {
    @EnvironmentObject private var music: MusicReader
    @Environment(\.scenePhase) private var phase
    @State private var text = ""
    @State private var source = 0
    private var searchURL: URL {
        var url = URLComponents(string: "https://music.apple.com/search")!
        url.queryItems = [URLQueryItem(name: "term", value: text)]
        return url.url!
    }
    var body: some View {
        VStack(spacing: 18) {
            AudioConnectionCard()
            if !music.authorized {
                VStack(alignment: .leading, spacing: 14) {
                    Label("连接 Apple Music", systemImage: "music.note").font(.title3.bold())
                    Text("允许访问媒体与 Apple Music，显示当前歌曲、封面和进度，并控制 Apple Music 播放。").font(.caption).foregroundColor(.secondary)
                    Button("授权并连接") { music.connect() }.buttonStyle(.borderedProminent).tint(ice).foregroundColor(.black).disabled(music.busy)
                    if MPMediaLibrary.authorizationStatus() == .denied { Link("前往系统设置", destination: URL(string: UIApplication.openSettingsURLString)!).font(.caption) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(22).glass(radius: 28)
            }
            NowPlayingCard()
            if !music.message.isEmpty { Text(music.message).font(.caption).foregroundColor(.orange).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8) }
            musicSearch
            VStack(alignment: .leading, spacing: 8) {
                Text("关于正在播放").font(.caption.weight(.semibold))
                Text("这里同步 Apple Music 的播放状态。其他播放器的状态栏或控制中心歌曲信息，iOS 没有提供通用读取接口。后台停止轮询，回到本页后重新同步。").font(.system(size: 10)).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(18).glass(radius: 23)
        }
        .onAppear { if !ProcessInfo.processInfo.arguments.contains("--ui-preview") { music.setVisible(true) } }
        .onDisappear { music.setVisible(false) }
        .onChange(of: phase) { value in music.setVisible(value == .active) }
    }
    private var musicSearch: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("发现音乐", systemImage: "magnifyingglass").font(.headline)
            Picker("搜索来源", selection: $source) { Text("我的资料库").tag(0); Text("Apple Music 曲库").tag(1) }.pickerStyle(.segmented)
                .onChange(of: source) { _ in music.clearSearch() }
            HStack {
                TextField(source == 0 ? "搜索资料库歌名" : "搜索歌曲或歌手", text: $text).submitLabel(.search)
                    .onSubmit { music.search(text, catalog: source == 1) }
                Button { music.search(text, catalog: source == 1) } label: { Image(systemName: "arrow.right.circle.fill").font(.title2) }.disabled(!music.authorized || music.searching)
            }.font(.subheadline).padding(13).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            if music.searching { ProgressView("正在搜索…").font(.caption) }
            if !music.searchMessage.isEmpty { Text(music.searchMessage).font(.caption).foregroundColor(.secondary) }
            if source == 0 {
                ForEach(music.library, id: \.persistentID) { item in
                    Button { music.playLibrary(item) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "music.note").frame(width: 36, height: 40).foregroundColor(ice)
                            VStack(alignment: .leading, spacing: 5) { Text(item.title ?? "未命名歌曲").font(.subheadline).lineLimit(1); Text(item.artist ?? "未知歌手").font(.caption).foregroundColor(.secondary).lineLimit(1) }
                            Spacer(); Image(systemName: "play.circle.fill").font(.title2).foregroundColor(ice)
                        }.padding(.vertical, 7)
                    }.buttonStyle(.plain).disabled(music.busy)
                }
            } else {
                ForEach(music.songs) { song in CatalogSongRow(song: song) }
                Text("完整播放需要 Apple Music 订阅，且当前安装具备可用的音乐服务。播放所选歌曲会替换当前队列。").font(.system(size: 10)).foregroundColor(.secondary)
            }
            Link(destination: searchURL) { Label("在 Apple Music 中搜索", systemImage: "arrow.up.right.square").font(.caption) }.tint(ice)
            Link("打开 Apple Music", destination: URL(string: "https://music.apple.com/")!).font(.caption).tint(ice)
        }.padding(20).glass(radius: 28)
    }
}
struct NowPlayingCard: View {
    @EnvironmentObject private var music: MusicReader
    @State private var scrubbing = false
    @State private var draft = 0.0
    var body: some View {
        VStack(spacing: 21) {
            HStack {
                Label("Apple Music", systemImage: "music.note").font(.caption.weight(.semibold)).foregroundColor(ice)
                Spacer()
                HStack(spacing: 5) { Circle().fill(music.playing ? Color.green : .gray).frame(width: 5, height: 5); Text(music.hasItem ? (music.playing ? "正在播放" : "未在播放") : "等待歌曲").font(.system(size: 10)).foregroundColor(.secondary) }
            }
            Group {
                if let image = music.artwork { Image(uiImage: image).resizable().scaledToFit() }
                else { ZStack { LinearGradient(colors: [ice.opacity(0.25), .purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing); Image(systemName: "music.note").font(.system(size: 72, weight: .light)).foregroundColor(ice.opacity(0.8)) } }
            }.frame(maxWidth: 260).aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 25)).shadow(color: ice.opacity(0.12), radius: 25, y: 12)
            VStack(spacing: 7) {
                Text(music.title).font(.system(size: 22, weight: .semibold, design: .rounded)).multilineTextAlignment(.center).lineLimit(2)
                Text(music.artist).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).lineLimit(2)
                if !music.album.isEmpty { Text(music.album).font(.caption2).foregroundColor(.secondary).lineLimit(1) }
            }
            VStack(spacing: 1) {
                Slider(value: Binding(get: { scrubbing ? draft : music.elapsed }, set: { draft = $0 }), in: 0...max(1, music.duration), onEditingChanged: { active in
                    if active { draft = music.elapsed; scrubbing = true }
                    else { music.seek(draft); scrubbing = false }
                }).tint(ice).disabled(!music.hasItem || music.duration <= 0)
                HStack { Text(songTime(scrubbing ? draft : music.elapsed)); Spacer(); Text(songTime(music.duration)) }.font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
            }
            HStack(spacing: 38) {
                Button { music.previous() } label: { Image(systemName: "backward.end.fill").font(.title2).frame(width: 38, height: 44) }.accessibilityLabel("上一首")
                Button { music.toggle() } label: { Image(systemName: music.playing ? "pause.fill" : "play.fill").font(.system(size: 29)).frame(width: 66, height: 66).background(.white.opacity(0.08), in: Circle()) }.accessibilityLabel(music.playing ? "暂停" : "播放")
                Button { music.next() } label: { Image(systemName: "forward.end.fill").font(.title2).frame(width: 38, height: 44) }.accessibilityLabel("下一首")
            }.foregroundColor(ice).disabled(!music.hasItem || music.busy)
            if music.busy { ProgressView() }
            if !music.hasItem { Text("先在 Apple Music 选一首歌。部分共享或无法读取的歌曲可能没有信息。").font(.system(size: 10)).foregroundColor(.secondary).multilineTextAlignment(.center) }
        }.padding(23).glass(radius: 32)
    }
}
struct CatalogSongRow: View {
    let song: Song
    @EnvironmentObject private var music: MusicReader
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: song.artwork?.url(width: 100, height: 100)) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "music.note").foregroundColor(ice) }.frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) {
                Text(song.title).font(.subheadline).lineLimit(1)
                Text(song.artistName).font(.caption).foregroundColor(.secondary).lineLimit(1)
                if let url = song.url { Link("在 Apple Music 查看", destination: url).font(.system(size: 10)).tint(ice) }
            }
            Spacer()
            Button { music.playCatalog(song) } label: { Image(systemName: "play.circle.fill").font(.title2).foregroundColor(ice) }.disabled(music.busy).accessibilityLabel("播放 \(song.title)")
        }.padding(.vertical, 7)
    }
}
