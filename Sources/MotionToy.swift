import SwiftUI
import CoreMotion

final class ToyPhysics: ObservableObject {
    @Published var points = [CGPoint(x: 95, y: 120), CGPoint(x: 205, y: 120)]
    @Published var tilt = 0.0
    private var velocities = [CGVector.zero, CGVector.zero]
    private var bounds = CGSize(width: 300, height: 245)
    private var motion: CMMotionManager?
    private var timer: Timer?
    private var held: Int?
    private let radii: [CGFloat] = [52, 34]
    func resize(_ size: CGSize) {
        guard size.width > 100, size.height > 100 else { return }
        bounds = size
        points = [CGPoint(x: size.width * 0.5, y: size.height * 0.5), CGPoint(x: size.width * 0.82, y: size.height * 0.32)]
        velocities = [.zero, .zero]
    }
    func run(_ enabled: Bool) {
        stop()
        guard enabled else { tilt = 0; resize(bounds); return }
        let manager = motion ?? CMMotionManager(); motion = manager
        if manager.isDeviceMotionAvailable { manager.deviceMotionUpdateInterval = 1.0 / 30; manager.startDeviceMotionUpdates() }
        let tick = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.step() }
        RunLoop.main.add(tick, forMode: .common); timer = tick
    }
    func stop() { timer?.invalidate(); timer = nil; motion?.stopDeviceMotionUpdates(); held = nil }
    func drag(_ index: Int, to point: CGPoint) {
        guard index == 1 else { return }
        held = index
        points[index] = CGPoint(x: max(radii[index], min(bounds.width - radii[index], point.x)), y: max(radii[index], min(bounds.height - radii[index], point.y)))
        velocities[index] = .zero
    }
    func release() { held = nil }
    private func step() {
        let gravity = motion?.deviceMotion?.gravity
        let gx = CGFloat(gravity?.x ?? 0) * 650
        let gy = -CGFloat(gravity?.y ?? 0) * 650
        let dt: CGFloat = 1.0 / 30
        var next = points
        next[0] = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        for i in 1..<2 where i != held {
            velocities[i].dx = max(-700, min(700, (velocities[i].dx + gx * dt) * 0.985))
            velocities[i].dy = max(-700, min(700, (velocities[i].dy + gy * dt) * 0.985))
            next[i].x += velocities[i].dx * dt; next[i].y += velocities[i].dy * dt
            if next[i].x < radii[i] { next[i].x = radii[i]; velocities[i].dx = abs(velocities[i].dx) * 0.72 }
            if next[i].x > bounds.width - radii[i] { next[i].x = bounds.width - radii[i]; velocities[i].dx = -abs(velocities[i].dx) * 0.72 }
            if next[i].y < radii[i] { next[i].y = radii[i]; velocities[i].dy = abs(velocities[i].dy) * 0.72 }
            if next[i].y > bounds.height - radii[i] { next[i].y = bounds.height - radii[i]; velocities[i].dy = -abs(velocities[i].dy) * 0.72 }
        }
        let dx = next[1].x - next[0].x, dy = next[1].y - next[0].y
        let distance = max(0.001, hypot(dx, dy)), limit = radii[0] + radii[1]
        if distance < limit && held != 1 {
            let nx: CGFloat = distance < 0.01 ? 1 : dx / distance
            let ny: CGFloat = distance < 0.01 ? 0 : dy / distance
            next[1] = CGPoint(x: next[0].x + nx * limit, y: next[0].y + ny * limit)
            let speed = velocities[1].dx * nx + velocities[1].dy * ny
            if speed < 0 { velocities[1].dx -= 1.7 * speed * nx; velocities[1].dy -= 1.7 * speed * ny }
        }
        points = next
        tilt = Double(gravity?.x ?? 0) * 12
    }
    deinit { timer?.invalidate(); motion?.stopDeviceMotionUpdates() }
}
struct GravityToy: View {
    let mood: String
    let model: PodModel
    let enabled: Bool
    @AppStorage("customMoodImage") private var customImage = Data()
    @AppStorage("useCustomMoodImage") private var useCustom = false
    @StateObject private var physics = ToyPhysics()
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PodsArtwork(model: model, showsCase: false)
                    .frame(width: 112, height: 124)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 9)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                Group {
                    if useCustom, let image = UIImage(data: customImage) { Image(uiImage: image).resizable().scaledToFit().frame(width: 68, height: 68) }
                    else { Text(mood).font(.system(size: 55)) }
                }.shadow(color: .black.opacity(0.2), radius: 6, y: 6)
                    .position(physics.points[1]).gesture(drag(1))
            }.coordinateSpace(name: "gravityToy")
                .onAppear { physics.resize(geometry.size); physics.run(enabled) }
                .onChange(of: geometry.size) { size in physics.resize(size) }
                .onChange(of: enabled) { value in physics.run(value) }
                .onDisappear { physics.stop() }
        }.accessibilityElement(children: .ignore).accessibilityLabel("耳机固定居中，心情表情可拖动并随手机倾斜移动")
    }
    private func drag(_ index: Int) -> some Gesture {
        DragGesture(coordinateSpace: .named("gravityToy"))
            .onChanged { value in physics.drag(index, to: value.location) }
            .onEnded { _ in physics.release() }
    }
}
