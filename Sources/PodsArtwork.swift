import SwiftUI

struct PodsArtwork: View {
    var name: String = "AirPods"
    var model: PodModel? = nil
    var showsCase = true
    private var kind: PodModel { model ?? PodModel.detect(name) }
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 220, geometry.size.height / 220)
            ZStack {
                if kind.isMax { MaxArtwork() }
                else {
                    VStack(spacing: showsCase ? -7 : 0) {
                        HStack(spacing: kind.longStem ? 28 : 20) {
                            BudArtwork(model: kind).rotationEffect(.degrees(kind.longStem ? -5 : -13))
                            BudArtwork(model: kind).scaleEffect(x: -1, y: 1).rotationEffect(.degrees(kind.longStem ? 5 : 13))
                        }.frame(height: kind.longStem ? 113 : 96)
                        if showsCase { chargingCase }
                    }
                }
                if showsCase, let badge = kind.badge {
                    Text(badge).font(.system(size: 11, weight: .semibold, design: .rounded)).tracking(1)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(.white.opacity(0.10), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
                        .offset(x: 67, y: 92)
                }
            }.frame(width: 220, height: 220)
                .scaleEffect(scale).position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(kind.title) 耳机图标")
    }
    private var chargingCase: some View {
        let width: CGFloat = kind.longStem ? 120 : kind.isPro ? 162 : kind == .third ? 150 : 140
        let height: CGFloat = kind.longStem ? 91 : kind.isPro ? 72 : 76
        return RoundedRectangle(cornerRadius: kind.longStem ? 34 : 29, style: .continuous)
            .fill(LinearGradient(stops: [.init(color: .white, location: 0), .init(color: Color(white: 0.87), location: 0.35), .init(color: Color(white: 0.71), location: 0.72), .init(color: Color(white: 0.95), location: 1)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: width, height: height)
            .overlay(alignment: .top) { Capsule().fill(.black.opacity(0.18)).frame(width: width - 15, height: 1).offset(y: 15) }
            .overlay { Circle().fill(Color(red: 0.39, green: 0.85, blue: 0.55)).frame(width: 3, height: 3).offset(y: -3) }
            .overlay(alignment: .bottomTrailing) {
                if kind == .pro2 || kind == .pro3 || kind == .fifth {
                    HStack(spacing: 3) { ForEach(0..<3) { _ in Circle().fill(.black.opacity(0.25)).frame(width: 2, height: 2) } }.padding(12)
                }
            }
            .overlay { RoundedRectangle(cornerRadius: kind.longStem ? 34 : 29).stroke(.white.opacity(0.65), lineWidth: 0.7) }
            .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 10)
    }
}
private struct BudArtwork: View {
    let model: PodModel
    private var compact: Bool { model == .fourth || model == .fifth }
    private var stemHeight: CGFloat { model.longStem ? 81 : compact ? 40 : 48 }
    var body: some View {
        ZStack(alignment: .top) {
            Capsule().fill(LinearGradient(colors: [.white, Color(white: 0.72), .white], startPoint: .leading, endPoint: .trailing))
                .frame(width: model.longStem ? 14 : 19, height: stemHeight).offset(x: 9, y: 26)
            Ellipse().fill(LinearGradient(colors: [.white, Color(white: 0.77)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: model.longStem ? 33 : compact ? 38 : model == .pro3 ? 46 : 43, height: model.longStem ? 42 : compact ? 35 : 38)
            if model.isPro {
                Ellipse().fill(LinearGradient(colors: [Color(white: 0.72), .white], startPoint: .leading, endPoint: .trailing)).frame(width: 24, height: 25).offset(x: -24, y: 7)
                Ellipse().fill(.black.opacity(0.38)).frame(width: 5, height: 15).offset(x: -33, y: 12)
            }
            Capsule().fill(Color(white: 0.12)).frame(width: model.longStem ? 7 : 14, height: model.longStem ? 17 : 9).rotationEffect(.degrees(-17)).offset(x: -6, y: 11)
            Capsule().fill(.black.opacity(0.7)).frame(width: 4, height: 9).offset(x: 13, y: 27)
            Capsule().fill(Color(white: 0.5)).frame(width: model.longStem ? 12 : 16, height: 3).offset(x: 9, y: stemHeight + 23)
        }.frame(width: 62, height: model.longStem ? 113 : 88)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 1, y: 4)
    }
}
private struct MaxArtwork: View {
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 48, y: 132)); p.addLine(to: CGPoint(x: 48, y: 75))
                p.addCurve(to: CGPoint(x: 172, y: 75), control1: CGPoint(x: 48, y: 6), control2: CGPoint(x: 172, y: 6))
                p.addLine(to: CGPoint(x: 172, y: 132))
            }.stroke(LinearGradient(colors: [Color(white: 0.65), .white, Color(white: 0.68)], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 12, lineCap: .round))
            ForEach(0..<2) { i in
                RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [.white, Color(white: 0.64), Color(white: 0.86)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 55, height: 83).overlay(RoundedRectangle(cornerRadius: 23).stroke(Color(white: 0.48), lineWidth: 3).padding(4))
                    .rotationEffect(.degrees(i == 0 ? -9 : 9)).position(x: i == 0 ? 49 : 171, y: 143)
            }
            Capsule().fill(.white.opacity(0.6)).frame(width: 60, height: 7).offset(y: -73)
        }.frame(width: 220, height: 220).shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 9)
    }
}
struct IconGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("耳机图标").font(.title2.bold())
                Text("依型号切换 · 支持手动选择").font(.caption).foregroundColor(.secondary)
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

