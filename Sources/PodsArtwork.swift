import SwiftUI

struct IconGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Apple 官方素材").font(.title2.bold())
                Text("官网产品图 · 首页使用系统图标").font(.caption).foregroundColor(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(PodModel.allCases) { model in
                        VStack(spacing: 5) {
                            PodsArtwork(model: model).frame(height: 105)
                            Text(model.title).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.6)
                        }.padding(7).glass(radius: 18)
                    }
                }
            }.padding(20)
        }.background { GlassBackdrop(theme: 0, photo: Data()) }.foregroundColor(.white).preferredColorScheme(.dark)
    }
}
