import Foundation

// Hardware identifiers verified against DeviceKit, Source/Device.generated.swift.
// https://github.com/devicekit/DeviceKit/blob/master/Source/Device.generated.swift
enum WatchModel {
    static func name(for identifier: String?) -> String? {
        guard let identifier = identifier else { return nil }
        switch identifier {
        case "Watch1,1": return "Apple Watch 1st generation 38 mm"
        case "Watch1,2": return "Apple Watch 1st generation 42 mm"
        case "Watch2,6": return "Apple Watch Series 1 · 38 mm"
        case "Watch2,7": return "Apple Watch Series 1 · 42 mm"
        case "Watch2,3": return "Apple Watch Series 2 · 38 mm"
        case "Watch2,4": return "Apple Watch Series 2 · 42 mm"
        case "Watch3,1", "Watch3,3": return "Apple Watch Series 3 · 38 mm"
        case "Watch3,2", "Watch3,4": return "Apple Watch Series 3 · 42 mm"
        case "Watch4,1", "Watch4,3": return "Apple Watch Series 4 · 40 mm"
        case "Watch4,2", "Watch4,4": return "Apple Watch Series 4 · 44 mm"
        case "Watch5,1", "Watch5,3": return "Apple Watch Series 5 · 40 mm"
        case "Watch5,2", "Watch5,4": return "Apple Watch Series 5 · 44 mm"
        case "Watch6,1", "Watch6,3": return "Apple Watch Series 6 · 40 mm"
        case "Watch6,2", "Watch6,4": return "Apple Watch Series 6 · 44 mm"
        case "Watch5,9", "Watch5,11": return "Apple Watch SE 1 · 40 mm"
        case "Watch5,10", "Watch5,12": return "Apple Watch SE 1 · 44 mm"
        case "Watch6,6", "Watch6,8": return "Apple Watch Series 7 · 41 mm"
        case "Watch6,7", "Watch6,9": return "Apple Watch Series 7 · 45 mm"
        case "Watch6,14", "Watch6,16": return "Apple Watch Series 8 · 41 mm"
        case "Watch6,15", "Watch6,17": return "Apple Watch Series 8 · 45 mm"
        case "Watch6,10", "Watch6,12": return "Apple Watch SE 2 · 40 mm"
        case "Watch6,11", "Watch6,13": return "Apple Watch SE 2 · 44 mm"
        case "Watch6,18": return "Apple Watch Ultra · 49 mm"
        case "Watch7,1", "Watch7,3": return "Apple Watch Series 9 · 41 mm"
        case "Watch7,2", "Watch7,4": return "Apple Watch Series 9 · 45 mm"
        case "Watch7,5": return "Apple Watch Ultra 2 · 49 mm"
        case "Watch7,13", "Watch7,14": return "Apple Watch SE 3 · 40 mm"
        case "Watch7,15", "Watch7,16": return "Apple Watch SE 3 · 44 mm"
        case "Watch7,8", "Watch7,10": return "Apple Watch Series 10 · 42 mm"
        case "Watch7,9", "Watch7,11": return "Apple Watch Series 10 · 46 mm"
        case "Watch7,12": return "Apple Watch Ultra 3 · 49 mm"
        case "Watch7,17", "Watch7,19": return "Apple Watch Series 11 · 42 mm"
        case "Watch7,18", "Watch7,20": return "Apple Watch Series 11 · 46 mm"
        case "Watch8,2", "Watch8,4": return "Apple Watch Series 12 · 42 mm"
        case "Watch8,3", "Watch8,5": return "Apple Watch Series 12 · 46 mm"
        case "Watch8,1": return "Apple Watch Ultra 4 · 49 mm"
        default: return nil
        }
    }
    static let choices: [String] = [
        "Apple Watch Ultra 4 · 49 mm",
        "Apple Watch Series 12 · 46 mm",
        "Apple Watch Series 12 · 42 mm",
        "Apple Watch Series 11 · 46 mm",
        "Apple Watch Series 11 · 42 mm",
        "Apple Watch Ultra 3 · 49 mm",
        "Apple Watch Series 10 · 46 mm",
        "Apple Watch Series 10 · 42 mm",
        "Apple Watch SE 3 · 44 mm",
        "Apple Watch SE 3 · 40 mm",
        "Apple Watch Ultra 2 · 49 mm",
        "Apple Watch Series 9 · 45 mm",
        "Apple Watch Series 9 · 41 mm",
        "Apple Watch Ultra · 49 mm",
        "Apple Watch SE 2 · 44 mm",
        "Apple Watch SE 2 · 40 mm",
        "Apple Watch Series 8 · 45 mm",
        "Apple Watch Series 8 · 41 mm",
        "Apple Watch Series 7 · 45 mm",
        "Apple Watch Series 7 · 41 mm",
        "Apple Watch SE 1 · 44 mm",
        "Apple Watch SE 1 · 40 mm",
        "Apple Watch Series 6 · 44 mm",
        "Apple Watch Series 6 · 40 mm",
        "Apple Watch Series 5 · 44 mm",
        "Apple Watch Series 5 · 40 mm",
        "Apple Watch Series 4 · 44 mm",
        "Apple Watch Series 4 · 40 mm",
        "Apple Watch Series 3 · 42 mm",
        "Apple Watch Series 3 · 38 mm",
        "Apple Watch Series 2 · 42 mm",
        "Apple Watch Series 2 · 38 mm",
        "Apple Watch Series 1 · 42 mm",
        "Apple Watch Series 1 · 38 mm",
        "Apple Watch 1st generation 42 mm",
        "Apple Watch 1st generation 38 mm"
    ]
}
