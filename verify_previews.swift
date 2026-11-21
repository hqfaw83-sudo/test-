import AppKit
import Foundation

for name in ["preview-light.png", "preview-dark.png", "preview-stats.png", "preview-devices.png", "preview-icons.png", "preview-health.png", "preview-analysis.png", "preview-metrics.png", "preview-mood.png"] {
    let data = try Data(contentsOf: URL(fileURLWithPath: name))
    guard let bitmap = NSBitmapImageRep(data: data) else { fatalError("Cannot decode \(name)") }
    var luminance = 0.0
    var count = 0
    for row in 2...8 {
        for col in 1...9 {
            let x = bitmap.pixelsWide * col / 10, y = bitmap.pixelsHigh * row / 10
            if let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) {
                luminance += (c.redComponent + c.greenComponent + c.blueComponent) / 3
                count += 1
            }
        }
    }
    guard count > 0 && luminance / Double(count) < 0.92 else { fatalError("Blank launch screen in \(name)") }
    print("Rendered interface verified: \(name)")
}
