import SpriteKit
import UIKit

// MARK: - Flow state
enum GameFlowState { case ready, playing, gameOver }

// MARK: - Scene events forwarded to SwiftUI
protocol CosmicGameSceneDelegate: AnyObject {
    func sceneDidScore(_ score: Int)
    func sceneDidEnd(score: Int, best: Int, isNewBest: Bool)
    func sceneDidShowGust(upward: Bool)
    func sceneDidHideGust()
}

// MARK: - Scene
final class CosmicGameScene: SKScene, SKPhysicsContactDelegate {

    weak var gameDelegate: CosmicGameSceneDelegate?

    // Nodes
    private let player          = SKSpriteNode()
    private var bgLayers: [SKNode] = []

    // State
    private let difficulty      = DifficultyManager()
    private var flow: GameFlowState = .ready
    private var score: Int = 0
    private var lastUpdateTime: TimeInterval = 0
    private var activeWindForce: CGFloat = 0
    private var windPushUp = true

    private let spawnKey  = "obstacleSpawn"
    private let windKey   = "windCycle"

    // MARK: - didMove
    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: GameConfig.gravity)
        physicsWorld.contactDelegate = self
        physicsWorld.speed = 1.0
        backgroundColor = .clear

        setupParallaxBg()
        setupWorldBounds()
        setupPlayer()
        addReadyHint()
    }

    // MARK: - Parallax background stars
    private func setupParallaxBg() {
        let speeds: [CGFloat] = [18, 34, 55]
        let alphas: [CGFloat] = [0.35, 0.55, 0.80]
        let counts = [30, 20, 12]

        for layer in 0..<3 {
            let node = SKNode()
            node.name = "bgLayer\(layer)"
            for _ in 0..<counts[layer] {
                let dot = SKShapeNode(circleOfRadius: CGFloat(layer) * 0.5 + 0.6)
                dot.fillColor = .white
                dot.strokeColor = .clear
                dot.alpha = alphas[layer]
                dot.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                       y: CGFloat.random(in: 0...size.height))
                node.addChild(dot)
            }
            addChild(node)
            bgLayers.append(node)

            // infinite scroll
            let moveLeft = SKAction.moveBy(x: -speeds[layer], y: 0, duration: 1)
            let wrap = SKAction.customAction(withDuration: 0) { [weak self] _, _ in
                guard let self else { return }
                for child in node.children {
                    if child.position.x < 0 {
                        child.position.x += self.size.width
                    }
                }
            }
            node.run(.repeatForever(.sequence([moveLeft, wrap])))
        }
    }

    // MARK: - World bounds
    private func setupWorldBounds() {
        func boundNode(y: CGFloat) -> SKNode {
            let n = SKNode()
            n.position = CGPoint(x: size.width / 2, y: y)
            let body = SKPhysicsBody(rectangleOf: CGSize(width: size.width, height: GameConfig.groundHeight))
            body.isDynamic = false
            body.categoryBitMask    = PhysicsCategory.world
            body.contactTestBitMask = PhysicsCategory.player
            body.collisionBitMask   = PhysicsCategory.player
            n.physicsBody = body
            return n
        }
        addChild(boundNode(y: GameConfig.groundHeight / 2))
        addChild(boundNode(y: size.height - GameConfig.groundHeight / 2))
    }

    // MARK: - Player
    private func setupPlayer() {
        let tex = makeAstronautTexture(size: CGSize(width: 88, height: 88))
        player.texture = tex
        player.size    = CGSize(width: 72, height: 72)
        player.position = CGPoint(x: size.width * 0.28, y: size.height * 0.5)

        let body = SKPhysicsBody(circleOfRadius: GameConfig.playerRadius)
        body.allowsRotation  = false         // physics won't spin the node
        body.mass            = GameConfig.playerMass
        body.linearDamping   = 0.0           // no air drag — pure gravity + impulse
        body.restitution     = 0.0           // no bounce on wall hits
        body.friction        = 0.0
        body.categoryBitMask    = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.world | PhysicsCategory.scoreGate
        body.collisionBitMask   = PhysicsCategory.obstacle | PhysicsCategory.world
        player.physicsBody = body

        // Idle hint float — only runs in .ready state; removed on first tap
        let up   = SKAction.moveBy(x: 0, y: 6,  duration: 1.1)
        up.timingMode = .easeInEaseOut
        let dn   = SKAction.moveBy(x: 0, y: -6, duration: 1.1)
        dn.timingMode = .easeInEaseOut
        player.run(.repeatForever(.sequence([up, dn])), withKey: "idleFloat")

        addChild(player)
    }

    private func addReadyHint() {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.name = "hint"
        label.text = "Tap to launch"
        label.fontSize = 22
        label.fontColor = SKColor(red: 0.36, green: 0.90, blue: 1.00, alpha: 1)
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        addChild(label)

        let blink = SKAction.sequence([
            .fadeAlpha(to: 0.35, duration: 0.6),
            .fadeAlpha(to: 1.0,  duration: 0.6)
        ])
        label.run(.repeatForever(blink))
    }

    // MARK: - Touch
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch flow {
        case .ready:
            flow = .playing
            childNode(withName: "hint")?.removeFromParent()
            // Stop idle float and reset position offset before handing off to physics
            player.removeAction(forKey: "idleFloat")
            player.position.y = size.height * 0.5   // re-centre after float drift
            player.zRotation  = 0
            startLoops()
            flap()
        case .playing:
            flap()
        case .gameOver:
            break
        }
    }

    private func flap() {
        guard let body = player.physicsBody else { return }
        // Zero out vertical velocity first so each tap gives a consistent arc
        body.velocity = CGVector(dx: 0, dy: 0)
        body.applyImpulse(CGVector(dx: 0, dy: GameConfig.flapImpulse))
        HapticsManager.shared.impactLight()
        AudioManager.shared.playFlap()
        spawnThrusterParticles()
        // Snap tilt upward immediately so the astronaut looks like it's thrusting
        player.zRotation = 0.28
    }

    // MARK: - Loops
    private func startLoops() {
        let spawn = SKAction.run { [weak self] in self?.spawnObstaclePair() }
        let wait  = SKAction.wait(forDuration: GameConfig.obstacleSpawnInterval)
        run(.repeatForever(.sequence([spawn, wait])), withKey: spawnKey)
        scheduleWind()
    }

    private func scheduleWind() {
        let delay = TimeInterval.random(in: GameConfig.windIntervalMin...GameConfig.windIntervalMax)
        run(.sequence([.wait(forDuration: delay), .run { [weak self] in self?.triggerWind() }]),
            withKey: windKey)
    }

    private func triggerWind() {
        guard flow == .playing else { return }
        let upward = windPushUp
        windPushUp.toggle()
        activeWindForce = (upward ? 1 : -1) * GameConfig.windForceMagnitude

        gameDelegate?.sceneDidShowGust(upward: upward)

        run(.sequence([
            .wait(forDuration: GameConfig.windDuration),
            .run { [weak self] in
                self?.activeWindForce = 0
                self?.gameDelegate?.sceneDidHideGust()
                self?.scheduleWind()
            }
        ]))
    }

    // MARK: - Obstacle spawn
    private func spawnObstaclePair() {
        guard flow == .playing else { return }

        let snap        = difficulty.snapshot(forScore: score)
        let gapH        = snap.currentGapHeight
        let scrollSpeed = GameConfig.baseScrollSpeed * snap.scrollMultiplier

        let safeTop    = size.height - GameConfig.groundHeight - gapH * 0.5 - 30
        let safeBottom = GameConfig.groundHeight + gapH * 0.5 + 30
        guard safeBottom < safeTop else { return }  // layout not ready yet
        let gapCenterY = CGFloat.random(in: safeBottom...safeTop)

        let bottomH = gapCenterY - gapH / 2
        let topY    = gapCenterY + gapH / 2
        let topH    = size.height - GameConfig.groundHeight - topY
        let spawnX  = size.width + GameConfig.obstacleWidth

        let bottom = makeAsteroid(height: bottomH)
        bottom.position = CGPoint(x: spawnX, y: GameConfig.groundHeight + bottomH / 2)
        addChild(bottom)

        let top = makeAsteroid(height: topH)
        top.position = CGPoint(x: spawnX, y: topY + topH / 2)
        addChild(top)

        // Invisible score gate
        let gate = SKNode()
        gate.position = CGPoint(x: spawnX + GameConfig.obstacleWidth / 2, y: size.height / 2)
        let gb = SKPhysicsBody(rectangleOf: CGSize(width: 4, height: size.height))
        gb.isDynamic = false
        gb.categoryBitMask    = PhysicsCategory.scoreGate
        gb.contactTestBitMask = PhysicsCategory.player
        gb.collisionBitMask   = PhysicsCategory.none
        gate.physicsBody = gb
        addChild(gate)

        let dist     = size.width + GameConfig.obstacleWidth * 2
        let duration = TimeInterval(dist / scrollSpeed)
        let seq      = SKAction.sequence([.moveBy(x: -dist, y: 0, duration: duration), .removeFromParent()])

        bottom.run(seq); top.run(seq); gate.run(seq)
    }

    // MARK: - Asteroid texture
    private func makeAsteroid(height: CGFloat) -> SKShapeNode {
        let w = GameConfig.obstacleWidth
        let node = SKShapeNode(rectOf: CGSize(width: w, height: height), cornerRadius: 10)

        // Neon teal gradient look — use fill + overlay dots for rocky feel
        node.fillColor   = SKColor(red: 0.14, green: 0.55, blue: 0.65, alpha: 1)
        node.strokeColor = SKColor(red: 0.36, green: 0.90, blue: 1.00, alpha: 0.6)
        node.lineWidth   = 1.5

        let body = SKPhysicsBody(rectangleOf: CGSize(width: w, height: height))
        body.isDynamic = false
        body.categoryBitMask    = PhysicsCategory.obstacle
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask   = PhysicsCategory.player
        node.physicsBody = body
        return node
    }

    // MARK: - Astronaut texture (UIKit draw → SKTexture)
    private func makeAstronautTexture(size s: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: s)
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let w = s.width, h = s.height

            // Backpack
            cg.setFillColor(UIColor(red: 0.67, green: 0.73, blue: 0.84, alpha: 1).cgColor)
            fillRounded(cg, rect: CGRect(x: w*0.16, y: h*0.36, width: w*0.20, height: h*0.38), r: 8)

            // Helmet
            cg.setFillColor(UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: w*0.26, y: h*0.12, width: w*0.56, height: h*0.54))
            cg.setStrokeColor(UIColor(red: 0.76, green: 0.81, blue: 0.9, alpha: 1).cgColor)
            cg.setLineWidth(2.5)
            cg.strokeEllipse(in: CGRect(x: w*0.26, y: h*0.12, width: w*0.56, height: h*0.54))

            // Visor
            cg.setFillColor(UIColor(red: 0.30, green: 0.82, blue: 1.0, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: w*0.36, y: h*0.22, width: w*0.32, height: h*0.22))

            // Visor highlight
            cg.setFillColor(UIColor.white.withAlphaComponent(0.6).cgColor)
            cg.fillEllipse(in: CGRect(x: w*0.38, y: h*0.24, width: w*0.10, height: h*0.07))

            // Body
            cg.setFillColor(UIColor(red: 0.90, green: 0.93, blue: 0.98, alpha: 1).cgColor)
            fillRounded(cg, rect: CGRect(x: w*0.37, y: h*0.60, width: w*0.34, height: h*0.26), r: 10)

            // Arms
            cg.setFillColor(UIColor(red: 0.83, green: 0.87, blue: 0.93, alpha: 1).cgColor)
            fillRounded(cg, rect: CGRect(x: w*0.22, y: h*0.63, width: w*0.15, height: h*0.09), r: 5)
            fillRounded(cg, rect: CGRect(x: w*0.71, y: h*0.63, width: w*0.15, height: h*0.09), r: 5)

            // Chest panel
            cg.setFillColor(UIColor(red: 0.36, green: 0.90, blue: 1.00, alpha: 0.9).cgColor)
            fillRounded(cg, rect: CGRect(x: w*0.44, y: h*0.67, width: w*0.20, height: h*0.08), r: 4)

            // Thruster flame
            let flameTop = CGPoint(x: w*0.54, y: h*0.86)
            cg.setFillColor(UIColor(red: 0.97, green: 0.64, blue: 0.23, alpha: 0.9).cgColor)
            cg.beginPath()
            cg.move(to: flameTop)
            cg.addLine(to: CGPoint(x: w*0.46, y: h*0.98))
            cg.addLine(to: CGPoint(x: w*0.62, y: h*0.98))
            cg.closePath()
            cg.fillPath()

            // Antenna
            cg.setFillColor(UIColor.white.cgColor)
            fillRounded(cg, rect: CGRect(x: w*0.51, y: h*0.02, width: w*0.04, height: h*0.12), r: 2)
            cg.setFillColor(UIColor(red: 1.0, green: 0.86, blue: 0.45, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: w*0.47, y: h*0.00, width: w*0.12, height: w*0.12))
        }
        return SKTexture(image: img)
    }

    private func fillRounded(_ ctx: CGContext, rect: CGRect, r: CGFloat) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: r)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
    }

    // MARK: - Thruster particles
    private func spawnThrusterParticles() {
        for _ in 0..<5 {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            let hot = Bool.random()
            dot.fillColor = hot
                ? SKColor(red: 0.97, green: 0.64, blue: 0.23, alpha: 1)
                : SKColor(red: 1.00, green: 0.92, blue: 0.60, alpha: 1)
            dot.strokeColor = .clear
            dot.position = CGPoint(x: player.position.x - 4,
                                   y: player.position.y - player.size.height * 0.42)
            addChild(dot)
            let dx = CGFloat.random(in: -10...10)
            let dy = CGFloat.random(in: -30 ... -8)
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.28)
            let fade = SKAction.fadeOut(withDuration: 0.18)
            dot.run(.sequence([.group([move, fade]), .removeFromParent()]))
        }
    }

    // MARK: - Score particles
    private func spawnScoreParticles() {
        for _ in 0..<8 {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...3.5))
            dot.fillColor = SKColor(red: 1.0, green: 0.86, blue: 0.45, alpha: 1)
            dot.strokeColor = .clear
            dot.position = player.position
            addChild(dot)
            let dx = CGFloat.random(in: -28...28)
            let dy = CGFloat.random(in: 10...38)
            let seq = SKAction.sequence([
                .group([.moveBy(x: dx, y: dy, duration: 0.28),
                        .fadeOut(withDuration: 0.28)]),
                .removeFromParent()
            ])
            dot.run(seq)
        }
    }

    // MARK: - Update loop
    override func update(_ currentTime: TimeInterval) {
        guard flow == .playing else { return }

        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = min(currentTime - lastUpdateTime, 1.0 / 30.0)
        lastUpdateTime = currentTime

        guard let body = player.physicsBody else { return }

        // Apply wind force
        if activeWindForce != 0 {
            body.velocity.dy += activeWindForce * CGFloat(dt)
        }

        // Clamp vertical speed to prevent tunnelling and ceiling shots
        let clampedDy = max(GameConfig.maxFallSpeed,
                            min(GameConfig.maxRiseSpeed, body.velocity.dy))
        if body.velocity.dy != clampedDy {
            body.velocity = CGVector(dx: body.velocity.dx, dy: clampedDy)
        }

        // Smooth tilt: nose up on rise, nose down on fall — stays upright at zero
        // Range: +0.30 rad (nose up) → -0.55 rad (nose down, more dramatic)
        let dy = body.velocity.dy
        let targetRotation: CGFloat
        if dy >= 0 {
            // Rising: tilt up proportionally (0 → +0.30)
            targetRotation = (dy / GameConfig.maxRiseSpeed) * 0.30
        } else {
            // Falling: tilt nose down more aggressively (-0.55 at max fall)
            targetRotation = (dy / GameConfig.maxFallSpeed) * 0.55
        }
        // Lerp current rotation towards target for smooth feel (not a snap)
        let lerpFactor: CGFloat = 1.0 - pow(0.04, CGFloat(dt))
        player.zRotation = player.zRotation + (targetRotation - player.zRotation) * lerpFactor
    }

    // MARK: - Physics contact
    func didBegin(_ contact: SKPhysicsContact) {
        // Never process contacts once game is over
        guard flow != .gameOver else { return }

        let masks = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if masks == (PhysicsCategory.player | PhysicsCategory.scoreGate) {
            // Only score while actively playing
            guard flow == .playing else { return }
            score += 1
            gameDelegate?.sceneDidScore(score)
            spawnScoreParticles()
            AudioManager.shared.playScore()
            HapticsManager.shared.impactMedium()
            // Remove gate so it never triggers again
            if contact.bodyA.categoryBitMask == PhysicsCategory.scoreGate {
                contact.bodyA.node?.removeFromParent()
            } else {
                contact.bodyB.node?.removeFromParent()
            }
            return
        }

        let hitsPlayer   = masks & PhysicsCategory.player   != 0
        let hitsObstacle = masks & PhysicsCategory.obstacle != 0
        let hitsWorld    = masks & PhysicsCategory.world    != 0
        if hitsPlayer && (hitsObstacle || hitsWorld) {
            triggerGameOver()
        }
    }

    // MARK: - Game over
    private func triggerGameOver() {
        guard flow != .gameOver else { return }
        flow = .gameOver

        // Stop all game loops immediately
        removeAction(forKey: spawnKey)
        removeAction(forKey: windKey)
        activeWindForce = 0

        // Freeze physics but keep node visible
        player.physicsBody?.velocity = .zero
        player.physicsBody?.isDynamic = false
        player.removeAllActions()

        // Stop all moving obstacle / gate nodes so nothing keeps scrolling
        enumerateChildNodes(withName: "//*") { node, _ in
            node.removeAllActions()
        }

        HapticsManager.shared.impactHeavy()
        HapticsManager.shared.notification(.error)
        AudioManager.shared.playCrash()

        // Screen flash
        let flash = SKSpriteNode(color: .white, size: size)
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.alpha = 0.55
        flash.zPosition = 100
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))

        // Persist best score — read BEFORE updating so isNew is accurate
        let previousBest = UserDefaults.standard.integer(forKey: "cd.bestScore")
        let isNew = score > previousBest
        if isNew {
            UserDefaults.standard.set(score, forKey: "cd.bestScore")
        }
        let finalBest = isNew ? score : previousBest

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.gameDelegate?.sceneDidEnd(score: self.score,
                                           best: finalBest,
                                           isNewBest: isNew)
        }
    }
}
