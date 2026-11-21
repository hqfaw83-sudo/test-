import Foundation

enum PodModel: String, CaseIterable, Identifiable {
    case airpods, classic, third, fourth, fifth, pro, pro2, pro3, max, max2
    var id: String { rawValue }
    var title: String {
        switch self {
        case .airpods: return "AirPods · 通用"
        case .classic: return "AirPods 1 / 2"
        case .third: return "AirPods 3"
        case .fourth: return "AirPods 4"
        case .fifth: return "AirPods 5"
        case .pro: return "AirPods Pro"
        case .pro2: return "AirPods Pro 2"
        case .pro3: return "AirPods Pro 3"
        case .max: return "AirPods Max"
        case .max2: return "AirPods Max 2"
        }
    }
    var isMax: Bool { self == .max || self == .max2 }
    var isPro: Bool { self == .pro || self == .pro2 || self == .pro3 }
    var longStem: Bool { self == .classic || self == .airpods }
    var badge: String? {
        switch self {
        case .classic: return "1 / 2"
        case .third: return "3"
        case .fourth: return "4"
        case .fifth: return "5"
        case .pro: return "PRO"
        case .pro2: return "PRO 2"
        case .pro3: return "PRO 3"
        case .max: return "MAX"
        case .max2: return "MAX 2"
        default: return nil
        }
    }
    static func detect(_ name: String) -> PodModel {
        let n = name.lowercased()
        func matches(_ pattern: String) -> Bool { n.range(of: pattern, options: .regularExpression) != nil }
        func generation(_ number: Int, family: String) -> Bool {
            matches("\\b" + family + "[ -]*" + String(number) + "\\b") ||
            (matches("\\b" + family + "\\b") && (matches("\\b" + String(number) + "(?:nd|rd|th|st) generation\\b") || n.contains("第\(number)代")))
        }
        if n.contains("max") { return generation(2, family: "max") || n.contains("第二代") ? .max2 : .max }
        if n.contains("pro") {
            if generation(3, family: "pro") || n.contains("第三代") { return .pro3 }
            if generation(2, family: "pro") || n.contains("第二代") { return .pro2 }
            return .pro
        }
        if generation(5, family: "airpods") || n.contains("第五代") { return .fifth }
        if generation(4, family: "airpods") || n.contains("第四代") { return .fourth }
        if generation(3, family: "airpods") || n.contains("第三代") { return .third }
        if generation(1, family: "airpods") || generation(2, family: "airpods") || n.contains("第一代") || n.contains("第二代") { return .classic }
        return .airpods
    }
}
