import SwiftUI
import SpriteKit
import CoreMotion

final class ToyScene: SKScene {
    private let motion = CMMotionManager()
    private var held: SKNode?
    private var emojiNode: SKLabelNode?
    private var headset: SKSpriteNode?
    var enabled = false
    override func didMove(to view: SKView) {
        backgroundColor = .clear; scaleMode = .resizeFill
        physicsWorld.gravity = .zero
        updateBounds()
    }
    override func didChangeSize(_ oldSize: CGSize) { updateBounds() }
    private func updateBounds() {
        guard size.width > 20, size.height > 20 else { return }
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: 6, y: 6, width: size.width - 12, height: size.height - 12))
        physicsBody?.friction = 0.2
    }
    func configure(mood: String, symbol: String, moving: Bool) {
        if emojiNode == nil {
            let label = SKLabelNode(text: mood); label.fontSize = 55; label.verticalAlignmentMode = .center
            label.position = CGPoint(x: size.width * 0.67, y: size.height * 0.5)
            label.physicsBody = SKPhysicsBody(circleOfRadius: 30); addChild(label); emojiNode = label
            let sprite = SKSpriteNode(); sprite.size = CGSize(width: 95, height: 105)
            sprite.position = CGPoint(x: size.width * 0.34, y: size.height * 0.5)
            sprite.physicsBody = SKPhysicsBody(circleOfRadius: 44); addChild(sprite); headset = sprite
            for node in [label as SKNode, sprite as SKNode] {
                node.physicsBody?.restitution = 0.75; node.physicsBody?.linearDamping = 0.65; node.physicsBody?.angularDamping = 0.8
                node.physicsBody?.allowsRotation = true
            }
        }
        emojiNode?.text = mood
        if let image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 110, weight: .regular))?.withTintColor(.white, renderingMode: .alwaysOriginal) {
            headset?.texture = SKTexture(image: image)
        }
        enabled = moving
        if moving && motion.isDeviceMotionAvailable { motion.deviceMotionUpdateInterval = 1.0 / 30; if !motion.isDeviceMotionActive { motion.startDeviceMotionUpdates() } }
        else { motion.stopDeviceMotionUpdates() }
        for node in children { node.physicsBody?.isDynamic = moving }
        if !moving || !motion.isDeviceMotionAvailable {
            headset?.position = CGPoint(x: size.width * 0.33, y: size.height * 0.5)
            emojiNode?.position = CGPoint(x: size.width * 0.69, y: size.height * 0.5)
        }
    }
    override func update(_ currentTime: TimeInterval) {
        guard enabled else { return }
        if let g = motion.deviceMotion?.gravity { physicsWorld.gravity = CGVector(dx: g.x * 12, dy: g.y * 12) }
        else { physicsWorld.gravity = .zero }
    }
    func stop() { motion.stopDeviceMotionUpdates(); enabled = false; physicsWorld.gravity = .zero }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard enabled, let point = touches.first?.location(in: self) else { return }
        held = nodes(at: point).first(where: { $0 === emojiNode || $0 === headset })
        held?.physicsBody?.isDynamic = false
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), let held = held else { return }
        held.position = CGPoint(x: max(50, min(size.width - 50, point.x)), y: max(50, min(size.height - 50, point.y)))
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { held?.physicsBody?.isDynamic = enabled; held = nil }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { held?.physicsBody?.isDynamic = enabled; held = nil }
    deinit { motion.stopDeviceMotionUpdates() }
}
struct GravityToy: View {
    let mood: String, symbol: String
    let enabled: Bool
    @State private var scene = ToyScene(size: CGSize(width: 300, height: 245))
    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 30, options: [.allowsTransparency])
            .onAppear { scene.configure(mood: mood, symbol: symbol, moving: enabled) }
            .onChange(of: mood) { _ in scene.configure(mood: mood, symbol: symbol, moving: enabled) }
            .onChange(of: symbol) { _ in scene.configure(mood: mood, symbol: symbol, moving: enabled) }
            .onChange(of: enabled) { _ in scene.configure(mood: mood, symbol: symbol, moving: enabled) }
            .onDisappear { scene.stop() }
            .accessibilityElement(children: .ignore).accessibilityLabel("耳机与心情 \(mood)，可随手机倾斜移动")
    }
}
