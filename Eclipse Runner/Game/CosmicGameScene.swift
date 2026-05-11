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

    // Active skin — set before didMove(to:)
    var activeSkin: AstronautSkin = SkinCatalog.all[0]

    // Battle seed — when set, obstacles use a deterministic sequence
    var battleSeed: Int = 0

    // Nodes
    private let player          = SKSpriteNode()
    private var bgLayers: [SKNode] = []
    private var thrusterTextures: [SKTexture] = []   // pre-baked — no SKShapeNode at tap time
    private var scoreTextures: [SKTexture]    = []
    private var sceneInitialised = false   // guard against didChangeSize before didMove

    // State
    private let difficulty      = DifficultyManager()
    private var flow: GameFlowState = .ready
    private var score: Int = 0
    private var lastUpdateTime: TimeInterval = 0
    private var activeWindForce: CGFloat = 0
    private var windPushUp = true
    private var lastGapCenterY: CGFloat = -1   // tracks previous gap for reachability

    private let spawnKey  = "obstacleSpawn"
    private let windKey   = "windCycle"

    // MARK: - didMove
    override func didMove(to view: SKView) {
        // Apply SKView performance flags now that the view is fully laid out
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder      = true
        view.isAsynchronous           = true

        physicsWorld.gravity = CGVector(dx: 0, dy: GameConfig.gravity)
        physicsWorld.contactDelegate = self
        physicsWorld.speed = 1.0
        backgroundColor = SKColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 1)  // deep space black

        sceneInitialised = true
        setupParallaxBg()
        setupWorldBounds()
        setupPlayer()
        buildParticleTextures()
        addReadyHint()
    }

    // Called by SpriteKit whenever the SKView resizes the scene (e.g. first layout pass)
    override func didChangeSize(_ oldSize: CGSize) {
        guard sceneInitialised, size.width > 0, size.height > 0 else { return }
        // Only act if size actually changed from non-zero to new value
        guard oldSize != size else { return }
        // Reposition player to vertical center with new size
        if flow == .ready {
            player.position = CGPoint(x: size.width * 0.28, y: size.height * 0.5)
        }
        // Reposition hint label
        if let hint = childNode(withName: "hint") {
            hint.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        }
    }

    // MARK: - Parallax background stars
    private func setupParallaxBg() {
        let alphas: [CGFloat] = [0.35, 0.55, 0.80]
        let counts = [30, 20, 12]

        for layer in 0..<3 {
            let node = SKNode()
            node.name = "bgLayer\(layer)"
            node.zPosition = CGFloat(layer) + 1   // layers 1,2,3
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
        let tex = makeAstronautTexture(size: CGSize(width: 88, height: 88), skin: activeSkin)
        player.texture = tex
        player.size    = CGSize(width: 72, height: 72)
        player.position = CGPoint(x: size.width * 0.28, y: size.height * 0.5)

        let body = SKPhysicsBody(circleOfRadius: GameConfig.playerRadius)
        body.allowsRotation  = false
        body.mass            = GameConfig.playerMass
        body.linearDamping   = 0.15
        body.restitution     = 0.0
        body.friction        = 0.0
        body.isDynamic       = false             // paused until first tap
        body.categoryBitMask    = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.world | PhysicsCategory.scoreGate
        body.collisionBitMask   = PhysicsCategory.world
        player.physicsBody = body

        // Gentle idle float using SKAction (no physics conflict — physics paused)
        let up   = SKAction.moveBy(x: 0, y: 6,  duration: 1.1)
        up.timingMode = .easeInEaseOut
        let dn   = SKAction.moveBy(x: 0, y: -6, duration: 1.1)
        dn.timingMode = .easeInEaseOut
        player.run(.repeatForever(.sequence([up, dn])), withKey: "idleFloat")
        player.zPosition = 50   // well above all background layers (1-3) and obstacles (5)

        addChild(player)
    }

    private func addReadyHint() {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.name = "hint"
        label.text = "Tap to launch"
        label.fontSize = 22
        label.fontColor = SKColor(red: 0.36, green: 0.90, blue: 1.00, alpha: 1)
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        label.zPosition = 60   // above player (50)
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
            player.removeAction(forKey: "idleFloat")
            // Snap to exact center to neutralize any idle-float offset
            player.position = CGPoint(x: player.position.x, y: size.height * 0.5)
            player.zRotation = 0
            // Enable physics now that we're playing
            player.physicsBody?.isDynamic = true
            player.physicsBody?.velocity  = .zero
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
        // Blend current vertical velocity (keep 30% momentum) for a smooth acceleration curve
        let blendedVy = body.velocity.dy * 0.3
        body.velocity = CGVector(dx: 0, dy: blendedVy)
        body.applyImpulse(CGVector(dx: 0, dy: GameConfig.flapImpulse))
        HapticsManager.shared.impactFlap()
        AudioManager.shared.playFlap()
        spawnThrusterParticles()
        // Let the rotation lerp in update() handle tilt naturally — no snap here
    }

    // MARK: - Loops
    private func startLoops() {
        // Grace delay before first obstacle, then spawn→wait cycle
        let initialWait = SKAction.wait(forDuration: GameConfig.firstSpawnDelay)
        let spawn = SKAction.run { [weak self] in self?.spawnObstaclePair() }
        let interval = SKAction.wait(forDuration: GameConfig.obstacleSpawnInterval)
        let cycle = SKAction.repeatForever(.sequence([spawn, interval]))
        run(.sequence([initialWait, cycle]), withKey: spawnKey)
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

        // Absolute vertical range (respect screen bounds + gap half-size)
        let hardBottom = GameConfig.groundHeight + gapH * 0.5 + 20
        let hardTop    = size.height - GameConfig.groundHeight - gapH * 0.5 - 20
        guard hardBottom < hardTop else { return }

        // --- Physics-accurate reachability constraint ---
        // Time for obstacle to travel from spawn X to player X (≈28% of width)
        let travelDist  = size.width * 0.72 + GameConfig.obstacleWidth * 0.5
        let travelTime  = CGFloat(travelDist / scrollSpeed)

        // Downward reachability: player falls under gravity from current gap center.
        // y(t) = v0*t + 0.5*g*t²  where v0=0 (worst case: player just tapped)
        // gravity in SpriteKit points/s² — use GameConfig.gravity * 60 (scene uses unit gravity)
        let g           = abs(GameConfig.gravity) * 60.0  // ≈ 588 pts/s²
        let freeFall    = 0.5 * g * travelTime * travelTime
        // Also cap by maxFallSpeed × time
        let maxFall     = min(freeFall, abs(GameConfig.maxFallSpeed) * travelTime) * 0.90

        // Upward reachability: player can tap roughly every 0.55s.
        // Each tap resets vy to flapImpulse/mass then gravity pulls it back.
        // Approximate net upward gain per tap cycle ≈ impulse/mass * tapInterval - 0.5*g*tapInterval²
        // But simpler and safer: use measured net upward speed ≈ 55% of maxRiseSpeed sustained.
        // We allow 3 taps max in travelTime, each tap gives flapImpulse/mass pts/s initial vy,
        // then decays. Conservatively, net upward travel ≈ 55 pts per tap cycle.
        let tapInterval: CGFloat = 0.55
        let tapsAvailable        = max(1.0, floor(Double(travelTime / tapInterval)))
        // Each tap: net upward gain = impulse/mass × tapInterval - 0.5 × g × tapInterval²
        let impulseVy    = GameConfig.flapImpulse / GameConfig.playerMass  // pts/s after tap
        let netPerTap    = min(impulseVy * tapInterval - 0.5 * g * tapInterval * tapInterval,
                               abs(GameConfig.maxRiseSpeed) * tapInterval)
        let maxRise      = CGFloat(tapsAvailable) * max(netPerTap, 30) * 0.70  // 70% conservative

        // Reference center (previous gap center or screen center on first obstacle)
        let refCenter: CGFloat = lastGapCenterY > 0 ? lastGapCenterY : size.height * 0.5

        // Clamp new gap center so it's always reachable from reference
        let reachMin = max(hardBottom, refCenter - maxFall)
        let reachMax = min(hardTop,   refCenter + maxRise)
        let safeMin  = min(reachMin, reachMax)
        let safeMax  = max(reachMin, reachMax)

        let gapCenterY = CGFloat.random(in: safeMin...safeMax)
        lastGapCenterY = gapCenterY

        let bottomH = gapCenterY - gapH / 2
        let topY    = gapCenterY + gapH / 2
        let topH    = size.height - GameConfig.groundHeight - topY
        let spawnX  = size.width + GameConfig.obstacleWidth

        let bottom = makeAsteroid(height: max(bottomH, 1))
        bottom.position = CGPoint(x: spawnX, y: GameConfig.groundHeight + bottomH / 2)
        addChild(bottom)

        let top = makeAsteroid(height: max(topH, 1))
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
        node.zPosition   = 5   // above bg layers (1-3), below player (50)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: w, height: height))
        body.isDynamic = false
        body.categoryBitMask    = PhysicsCategory.obstacle
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask   = PhysicsCategory.none   // contact-only, no physical bounce
        node.physicsBody = body
        return node
    }

    // MARK: - Astronaut texture (UIKit draw → SKTexture)
    private func makeAstronautTexture(size s: CGSize, skin: AstronautSkin) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: s)
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let w = s.width, h = s.height

            // Backpack
            cg.setFillColor(skin.uiAccentColor.cgColor)
            fillRounded(cg, rect: CGRect(x: w*0.16, y: h*0.36, width: w*0.20, height: h*0.38), r: 8)

            // Helmet
            cg.setFillColor(skin.uiSuitColor.cgColor)
            cg.fillEllipse(in: CGRect(x: w*0.26, y: h*0.12, width: w*0.56, height: h*0.54))
            cg.setStrokeColor(skin.uiAccentColor.cgColor)
            cg.setLineWidth(2.5)
            cg.strokeEllipse(in: CGRect(x: w*0.26, y: h*0.12, width: w*0.56, height: h*0.54))

            // Visor
            cg.setFillColor(skin.uiVisorColor.cgColor)
            cg.fillEllipse(in: CGRect(x: w*0.36, y: h*0.22, width: w*0.32, height: h*0.22))

            // Visor highlight
            cg.setFillColor(UIColor.white.withAlphaComponent(0.6).cgColor)
            cg.fillEllipse(in: CGRect(x: w*0.38, y: h*0.24, width: w*0.10, height: h*0.07))

            // Body
            cg.setFillColor(skin.uiSuitColor.cgColor)
            fillRounded(cg, rect: CGRect(x: w*0.37, y: h*0.60, width: w*0.34, height: h*0.26), r: 10)

            // Arms
            cg.setFillColor(skin.uiAccentColor.cgColor)
            fillRounded(cg, rect: CGRect(x: w*0.22, y: h*0.63, width: w*0.15, height: h*0.09), r: 5)
            fillRounded(cg, rect: CGRect(x: w*0.71, y: h*0.63, width: w*0.15, height: h*0.09), r: 5)

            // Chest panel
            cg.setFillColor(skin.uiVisorColor.withAlphaComponent(0.9).cgColor)
            fillRounded(cg, rect: CGRect(x: w*0.44, y: h*0.67, width: w*0.20, height: h*0.08), r: 4)

            // Antenna
            cg.setFillColor(skin.uiSuitColor.cgColor)
            fillRounded(cg, rect: CGRect(x: w*0.51, y: h*0.02, width: w*0.04, height: h*0.12), r: 2)
            cg.setFillColor(skin.uiVisorColor.cgColor)
            cg.fillEllipse(in: CGRect(x: w*0.47, y: h*0.00, width: w*0.12, height: w*0.12))
        }
        return SKTexture(image: img)
    }

    private func fillRounded(_ ctx: CGContext, rect: CGRect, r: CGFloat) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: r)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
    }

    // MARK: - Particle texture cache
    /// Called once in didMove. Pre-bakes dot textures so tap-time cost is zero.
    private func buildParticleTextures() {
        guard let view = self.view else { return }
        thrusterTextures = [2.0, 3.0, 4.0].map { r in
            let shape = SKShapeNode(circleOfRadius: r)
            shape.fillColor   = .white
            shape.strokeColor = .clear
            return view.texture(from: shape) ?? SKTexture()
        }
        scoreTextures = [2.0, 2.8, 3.5].map { r in
            let shape = SKShapeNode(circleOfRadius: r)
            shape.fillColor   = .white
            shape.strokeColor = .clear
            return view.texture(from: shape) ?? SKTexture()
        }
    }

    // MARK: - Thruster particles
    private func spawnThrusterParticles() {
        guard !thrusterTextures.isEmpty else { return }
        for _ in 0..<5 {
            let tex = thrusterTextures[Int.random(in: 0..<thrusterTextures.count)]
            let dot = SKSpriteNode(texture: tex)
            let hot = Bool.random()
            dot.color = hot
                ? UIColor(red: 0.97, green: 0.64, blue: 0.23, alpha: 1)
                : UIColor(red: 1.00, green: 0.92, blue: 0.60, alpha: 1)
            dot.colorBlendFactor = 1.0
            dot.zPosition = 49
            dot.position  = CGPoint(x: player.position.x - 4,
                                    y: player.position.y - player.size.height * 0.42)
            addChild(dot)
            let dx = CGFloat.random(in: -10...10)
            let dy = CGFloat.random(in: -30 ... -8)
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.28)
            let fade = SKAction.fadeOut(withDuration: 0.18)
            move.timingMode = .easeOut
            dot.run(.sequence([.group([move, fade]), .removeFromParent()]))
        }
    }

    // MARK: - Score particles
    private func spawnScoreParticles() {
        guard !scoreTextures.isEmpty else { return }
        for _ in 0..<8 {
            let tex = scoreTextures[Int.random(in: 0..<scoreTextures.count)]
            let dot = SKSpriteNode(texture: tex)
            dot.color            = UIColor(red: 1.0, green: 0.86, blue: 0.45, alpha: 1)
            dot.colorBlendFactor = 1.0
            dot.zPosition = 51
            dot.position  = player.position
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
        // Cap dt at 1/60 (never allow jumps larger than one 60fps frame)
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = min(currentTime - lastUpdateTime, 1.0 / 60.0)
        lastUpdateTime = currentTime

        // Parallax background — precomputed dx per layer, no per-child heap allocs
        let bgSpeed0 = 18 * CGFloat(dt)
        let bgSpeed1 = 34 * CGFloat(dt)
        let bgSpeed2 = 55 * CGFloat(dt)
        let bgOffsets: [CGFloat] = [bgSpeed0, bgSpeed1, bgSpeed2]
        let sceneW = size.width
        for (i, layer) in bgLayers.enumerated() {
            let dx = bgOffsets[i]
            for child in layer.children {
                child.position.x -= dx
                if child.position.x < 0 { child.position.x += sceneW }
            }
        }

        guard flow == .playing else { return }
        guard let body = player.physicsBody else { return }

        // Apply wind force
        if activeWindForce != 0 {
            body.velocity.dy += activeWindForce * CGFloat(dt)
        }

        // Clamp vertical speed
        let clampedDy = max(GameConfig.maxFallSpeed,
                            min(GameConfig.maxRiseSpeed, body.velocity.dy))
        if body.velocity.dy != clampedDy {
            body.velocity = CGVector(dx: body.velocity.dx, dy: clampedDy)
        }

        // Smooth tilt — faster lerp (0.18 base) for responsive feel
        let dy = body.velocity.dy
        let targetRotation: CGFloat = dy >= 0
            ? (dy / GameConfig.maxRiseSpeed) * 0.25
            : (dy / GameConfig.maxFallSpeed) * 0.45
        let lerpFactor: CGFloat = 1.0 - pow(0.06, CGFloat(dt))
        player.zRotation += (targetRotation - player.zRotation) * lerpFactor
    }

    // MARK: - Physics contact
    func didBegin(_ contact: SKPhysicsContact) {
        guard flow != .gameOver else { return }

        let masks = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if masks == (PhysicsCategory.player | PhysicsCategory.scoreGate) {
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
        lastGapCenterY = -1

        // Stop obstacle spawning and wind
        removeAction(forKey: spawnKey)
        removeAction(forKey: windKey)
        activeWindForce = 0

        // Freeze player immediately
        player.physicsBody?.velocity = .zero
        player.physicsBody?.isDynamic = false
        player.removeAllActions()

        // Stop all scrolling nodes
        enumerateChildNodes(withName: "//*") { node, _ in
            node.removeAllActions()
        }

        HapticsManager.shared.impactHeavy()
        HapticsManager.shared.notification(.error)
        AudioManager.shared.playCrash()

        // White flash overlay
        let flash = SKSpriteNode(color: .white, size: size)
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.alpha = 0.60
        flash.zPosition = 100   // topmost — covers everything
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.30), .removeFromParent()]))

        // Death animation: astronaut spins and fades out
        let spin   = SKAction.rotate(byAngle: .pi * 2.5, duration: 0.55)
        spin.timingMode = .easeIn
        let shrink = SKAction.scale(to: 0.25, duration: 0.55)
        shrink.timingMode = .easeIn
        let fade   = SKAction.fadeOut(withDuration: 0.45)
        fade.timingMode = .easeIn
        player.physicsBody?.allowsRotation = true
        player.run(.group([spin, shrink, fade]))

        // Read best from UserDefaults (GameStore will update it via registerRun)
        let previousBest = UserDefaults.standard.integer(forKey: "cd.bestScore")
        let isNew = score > previousBest
        let finalBest = isNew ? score : previousBest

        // Notify SwiftUI after death animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
            guard let self else { return }
            self.gameDelegate?.sceneDidEnd(score: self.score,
                                           best: finalBest,
                                           isNewBest: isNew)
        }
    }
}
