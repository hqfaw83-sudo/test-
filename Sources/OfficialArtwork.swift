import SwiftUI
import UIKit

enum AppleArtwork {
    private static let cache = NSCache<NSString, UIImage>()
    static func resource(for model: PodModel, name: String) -> String {
        switch model {
        case .airpods, .classic: return "apple-airpods2"
        case .third: return "apple-airpods3"
        case .fourth: return "apple-airpods4"
        case .fifth: return name.localizedCaseInsensitiveContains("wireless") || name.contains("无线") ? "apple-airpods5-wireless" : "apple-airpods5"
        case .pro: return "apple-pro1"
        case .pro2: return "apple-pro2"
        case .pro3: return "apple-pro3"
        case .max, .max2: return "apple-max"
        }
    }
    static func image(for model: PodModel, name: String) -> UIImage? {
        let key = resource(for: model, name: name)
        if let image = cache.object(forKey: key as NSString) { return image }
        guard let path = Bundle.main.path(forResource: key, ofType: "png"), let image = UIImage(contentsOfFile: path) else { return nil }
        cache.setObject(image, forKey: key as NSString)
        return image
    }
    static func symbol(for model: PodModel) -> UIImage {
        let candidates: [String]
        if model.isMax { candidates = ["airpodsmax", "headphones"] }
        else if model.isPro { candidates = [model == .pro3 ? "airpodspro.gen3" : model == .pro2 ? "airpodspro.gen2" : "airpodspro", "airpodspro", "earbuds"] }
        else if model.longStem { candidates = ["airpods", "earbuds"] }
        else { candidates = ["airpods.gen3", "airpods", "earbuds"] }
        return candidates.compactMap { UIImage(systemName: $0) }.first ?? UIImage(systemName: "headphones")!
    }
}
struct PodsArtwork: View {
    var name: String = "AirPods"
    var model: PodModel? = nil
    var showsCase = true
    private var kind: PodModel { model ?? PodModel.detect(name) }
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if showsCase, let image = AppleArtwork.image(for: kind, name: name) {
                Image(uiImage: image).resizable().renderingMode(.original).scaledToFit()
                    .padding(4).shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 6)
            } else {
                Image(uiImage: AppleArtwork.symbol(for: kind)).resizable().renderingMode(.template).scaledToFit()
                    .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(showsCase ? 12 : 2)
            }
            if showsCase, let badge = kind.badge {
                Text(badge).font(.system(size: 8, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 7).padding(.vertical, 3).background(.ultraThinMaterial, in: Capsule())
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(kind.title)，Apple 官方图片")
    }
}
