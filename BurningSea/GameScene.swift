import UIKit
import SpriteKit
import GameplayKit

func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

func - (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

func * (point: CGPoint, scalar: CGFloat) -> CGPoint {
    return CGPoint(x: point.x * scalar, y: point.y * scalar)
}

func / (point: CGPoint, scalar: CGFloat) -> CGPoint {
    return CGPoint(x: point.x / scalar, y: point.y / scalar)
}

#if !(arch(x86_64) || arch(arm64))
    func sqrt(a: CGFloat) -> CGFloat {
        return CGFloat(sqrtf(Float(a)))
    }
#endif

extension CGPoint {
    func length() -> CGFloat {
        return sqrt(x*x + y*y)
    }
    
    func normalized() -> CGPoint {
        return self / length()
    }
}

class ProgressBar:SKNode {
    var background:SKSpriteNode?
    var bar:SKSpriteNode?
    var _progress:CGFloat = 0
    var progress:CGFloat {
        get {
            return _progress
        }
        set {
            let value = max(min(newValue,1.0),0.0)
            if let bar = bar {
                bar.xScale = value
                _progress = value
            }
        }
    }
    
    convenience init(color:SKColor, size:CGSize, pos: CGPoint) {
        self.init()
        background = SKSpriteNode(color:SKColor.white,size:size)
        bar = SKSpriteNode(color:color,size:size)
        if let bar = bar, let background = background {
            bar.xScale = 0.0
            bar.zPosition = 2.0
            background.zPosition = 1.0
            bar.position = pos
            background.position = pos
            bar.anchorPoint = CGPoint(x:0.0,y:0.5)
            background.anchorPoint = CGPoint(x:0.0,y:0.5)
            addChild(background)
            addChild(bar)
        }
    }
}

struct PhysicsCategory {
    static let None      : UInt32 = 0
    static let All       : UInt32 = UInt32.max
    static let Monster   : UInt32 = 0b1       // 1
    static let Projectile: UInt32 = 0b10      // 2
    static let MonsterProjectile: UInt32 = 0b1000      // 2
    static let Player    : UInt32 = 0b100
}

class LevelScene: SKScene, SKPhysicsContactDelegate {
    var harborLife = 10
    var playerLife = 10
    let cameraNode:SKCameraNode
    let player:SKSpriteNode
    let rotationOffsetFactorForSpriteImage:CGFloat = -CGFloat.pi / 2
    let rightJS:EEJoyStick
    let leftJS:EEJoyStick
    let scaledFrameSize:CGSize
    var baseX: CGFloat {
        get{ return scaledFrameSize.width / 2 }
    }
    var baseY: CGFloat{
        get{  return scaledFrameSize.height / 2}
    }
    let playerMaxMovementSpeed:CGFloat = CGFloat(2)
    var leftMovementData: [CGFloat]? = nil
    var rightMovementData: [CGFloat]? = nil
    var bg1 = SKSpriteNode()
    var bg2 = SKSpriteNode()
    var looseFunc: (Int)->() = {_ in print("loo")}
    
    var canShoot: Bool = true
    var progressBar: ProgressBar = ProgressBar(color: SKColor.red, size: CGSize(width: 25, height: 5), pos: CGPoint(x: 0, y: 0))
    var playerLifeProgressBar: ProgressBar = ProgressBar(color: SKColor.red, size: CGSize(width: 25, height: 5), pos: CGPoint(x: 0, y: 0))
    var harborLifeProgressBar: ProgressBar = ProgressBar(color: SKColor.red, size: CGSize(width: 100, height: 10), pos: CGPoint(x: 0, y: 0))
    
    var score = 0
    
    init(_ frameSize: CGSize, loosFunc:  @escaping (Int)->()){
        self.looseFunc = loosFunc
        //Declaration matters - at least when using classes that contain multiple nodess
        cameraNode = SKCameraNode()
        rightJS = EEJoyStick()
        leftJS = EEJoyStick()
        player = SKSpriteNode(imageNamed: "GenericActorSprite.png")
        
        progressBar.progress = 1
        //swap size before calling super
        let swapSize = CGSize(width: frameSize.height, height: frameSize.width)
        scaledFrameSize = LevelScene.createLargeFrameSize(startSize: swapSize, increaseFactor: 1)
        
        super.init(size: scaledFrameSize)
        harborLifeProgressBar.position = CGPoint(x: -baseX+10 , y: scaledFrameSize.height / 2)
        harborLifeProgressBar.progress = 1
        addChild(harborLifeProgressBar)
        //Camera Placement
        cameraNode.position = CGPoint(x: baseX/2, y: baseY/2)
        addChild(cameraNode)
        
        //Joy Sticks (note joystick positions are changed in update method)
        //rightJS.position = CGPoint(x: frame.size.width * 0.75 + baseX, y: frame.size.height * 0.1 + baseY)
        //addChild(rightJS)
        //leftJS.position = CGPoint(x: frame.size.width * 0.75 + baseX, y: frame.size.height * 0.1 + baseY)
        addChild(leftJS)
        
        //Actors
        player.position = CGPoint(x: -baseX, y: baseY/2)
        player.zPosition = 0.1
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size) // 1
        player.physicsBody?.isDynamic = true // 2
        player.physicsBody?.categoryBitMask = PhysicsCategory.Player // 3
        player.physicsBody?.contactTestBitMask = PhysicsCategory.Monster // 4
        player.physicsBody?.collisionBitMask = PhysicsCategory.None // 5
        playerLifeProgressBar.progress = 1
        
        playerLifeProgressBar.position = CGPoint(x:-player.frame.width/2 ,y:-player.frame.height/2)
        player.addChild(playerLifeProgressBar)
        addChild(player)
        leftJS.position = CGPoint(x: -baseX+10 ,y: baseY/8 )
        // Create 2 background sprites
        bg1 = SKSpriteNode(imageNamed: "bg1")
        bg1.anchorPoint = CGPoint.zero;
        bg1.position = CGPoint.zero;
        //addChild(bg1)
        
        bg1 = SKSpriteNode(imageNamed: "bg1")
        bg2.anchorPoint = CGPoint.zero;
        bg2.position = CGPoint.zero;
        //addChild(bg2)
        
    }
    
    //MARK: touches
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //test by moving player to click, which should move camera
        //let ftouch = touches.first!
        //let ftloc = ftouch.location(in: self)
        
        //convert view coordinates to scene coordinates
        // ???
        
        //use converted points
        //let touchPt:CGPoint = CGPoint(x: ftloc.x, y: ftloc.y)
        //player.run(SKAction.move(to: touchPt, duration: 2), withKey: "moving player")
    }
    
    
    //this does not save a refernce to the touch (though one could) because I envisioned the user
    //tapping the joy stick (which I belive would invalid any reference to a touch) in order to do an
    //action (such as shoot). So, instead touches are evaluated in terms of proximity to a given joy stick,
    //this way the user could tap the joy stick to do an action (such as shoot, crouch, etc.). There could be a delay
    //instated before a joy stick is reset
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches{
            let touchLoc = touch.location(in: self)
            //let touchID = touch
            
            //get a displacement factor (this is used to convert coordinates to actual screen coordinates in position checks)
            var displace = cameraNode.position //should be in center of screen
            displace.x = displace.x - frame.size.width / 2
            displace.y = displace.y - frame.size.height / 2
            //print("touch x: \(displace.x) LB: \(frame.size.width * 0.33) RB: \(frame.size.width*0.66)")
            
            //CHECK TOUCHES POSITION IN SCREEN
            //if the y is less than 1/4 of the screen down
            if touchLoc.y < frame.size.height * 0.50 + displace.y{
                //if it is in the left 1/3 of screen
                if touchLoc.x <= frame.size.width * 0.33 + displace.x {
                    leftMovementData = leftJS.moveStick(joyStickLocation: leftJS.position, touchLocation: touchLoc, touch: touch)
                }
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches{
            rightJS.signalTouchEnded(touch: touch)
            leftJS.signalTouchEnded(touch: touch)
        }
        // 1 - Choose one of the touches to work with
        guard let touch = touches.first else {
            return
        }
        let touchLocation = touch.location(in: self)
        var displace = cameraNode.position //should be in center of screen
        displace.x = displace.x - frame.size.width / 2
        displace.y = displace.y - frame.size.height / 2
        if touchLocation.y < frame.size.height * 0.50 + displace.y{
            if touchLocation.x <= frame.size.width * 0.33 + displace.x {
                return
            }
        }
        if(self.canShoot && self.progressBar.progress >= 1) {
            self.canShoot = false;
            // 2 - Set up initial location of projectile
            let projectile = SKSpriteNode(imageNamed: "projectile")
            projectile.position = player.position
            
            // 3 - Determine offset of location to projectile
            let offset = touchLocation - projectile.position
            
            // 4 - Bail out if you are shooting down or backwards
            
            // 5 - OK to add now - you've double checked position
            addChild(projectile)
            
            // 6 - Get the direction of where to shoot
            let direction = offset.normalized()
            
            // 7 - Make it shoot far enough to be guaranteed off screen
            let shootAmount = direction * 1000
            
            // 8 - Add the shoot amount to the current position
            let realDest = shootAmount + projectile.position
            
            // 9 - Create the actions
            let actionMove = SKAction.move(to: realDest, duration: 2.0)
            let actionMoveDone = SKAction.removeFromParent()
            projectile.run(SKAction.sequence([actionMove, actionMoveDone]))
            projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectile.size.width/2)
            projectile.physicsBody?.isDynamic = true
            projectile.physicsBody?.categoryBitMask = PhysicsCategory.Projectile
            projectile.physicsBody?.contactTestBitMask = PhysicsCategory.Monster
            projectile.physicsBody?.collisionBitMask = PhysicsCategory.None
            projectile.physicsBody?.usesPreciseCollisionDetection = true
            
            self.progressBar = ProgressBar(color:SKColor.gray
                , size:CGSize(width:25, height:5), pos: CGPoint(x:-player.frame.width/2 ,y: player.frame.height/2))
            run(
                SKAction.sequence([
                    SKAction.customAction(withDuration: 5) { (node, float) in
                        self.progressBar.progress = self.progressBar.progress + 0.005
                        if(self.progressBar.progress == 1) {
                            self.canShoot = true
                            self.progressBar.removeFromParent()
                        }
                    }
                    ])
            )
            //addChild(background)
            //addChild(bar)
            player.addChild(progressBar)
            progressBar.progress = 0.0
            
        } else {
            return 
        }
    }
    
    func random() -> CGFloat {
        return CGFloat(Float(arc4random()) / 0xFFFFFFFF)
    }
    
    func random(min: CGFloat, max: CGFloat) -> CGFloat {
        return random() * (max - min) + min
    }
    
    func addMonster() {
        
        // Create sprite
        let monster = SKSpriteNode(imageNamed: "monster")
     
        // Determine where to spawn the monster along the Y axis
        let actualY = random(min: monster.size.height/2, max: size.height - monster.size.height/2)
        
        // Position the monster slightly off-screen along the right edge,
        // and along a random position along the Y axis as calculated above
        monster.position = CGPoint(x: size.width + monster.size.width/2, y: actualY)
        
        // Add the monster to the scene
        addChild(monster)
        
        // Determine speed of the monster
        let actualDuration = random(min: CGFloat(6.0), max: CGFloat(10.0))
        
        // Create the actions
        let actionMove = SKAction.move(to: CGPoint(x: -self.frame.width/3 , y: actualY), duration: TimeInterval(actualDuration))
        let actionMoveDone = SKAction.customAction(withDuration: 0.0) { (node, float) in
            self.harborLife = self.harborLife - 1
            self.harborLifeProgressBar.progress = self.harborLifeProgressBar.progress - 0.1
        }
        let actionMoveDoneDone = SKAction.removeFromParent()
        monster.run(SKAction.sequence([actionMove, actionMoveDone, actionMoveDoneDone]))
        monster.physicsBody = SKPhysicsBody(rectangleOf: monster.size) // 1
        monster.physicsBody?.isDynamic = true // 2
        monster.physicsBody?.categoryBitMask = PhysicsCategory.Monster // 3
        monster.physicsBody?.contactTestBitMask = PhysicsCategory.Projectile // 4
        monster.physicsBody?.collisionBitMask = PhysicsCategory.None // 5
        let actionwait = SKAction.wait(forDuration: 3.0)
        let actionShoot = SKAction.customAction(withDuration: 0.0) { (node, float) in
            let projectile = SKSpriteNode(imageNamed: "projectile")
            projectile.position = node.position
            let offset = self.player.position - projectile.position
            
            
            self.addChild(projectile)
            
            
            let direction = offset.normalized()
            
            
            let shootAmount = direction * 1000
            
            
            let realDest = shootAmount + projectile.position
            
            // 9 - Create the actions
            let actionMove = SKAction.move(to: realDest, duration: 2.0)
            let actionMoveDone = SKAction.removeFromParent()
            projectile.run(SKAction.sequence([actionMove, actionMoveDone]))
            projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectile.size.width/2)
            projectile.physicsBody?.isDynamic = true
            projectile.physicsBody?.categoryBitMask = PhysicsCategory.MonsterProjectile
            projectile.physicsBody?.contactTestBitMask = PhysicsCategory.Player
            projectile.physicsBody?.collisionBitMask = PhysicsCategory.None
            projectile.physicsBody?.usesPreciseCollisionDetection = true
        }
        monster.run(SKAction.sequence([actionwait,actionShoot]))
        
    }
    
    /*
     movement data should be a [CGFloat] of size 2.
     @param movData.0 = the angle of movement (obtained from arc tan - which means certain caveats)
     @param movData.1 = the strength of the movement.
     */
    func updatePlayerPosition(JoystickData movData: [CGFloat]){
        //shadow param movData with local var so that it can be mutated
        var movData = movData
        
        //return if improper parameter sent
        if movData.count < 2 {
            print("improper array sent to updatePlayerPosition, had less than 2 elements")
            return
        }
        
        //get current player's position (for displacement)
        let playerCurrentPosition = player.position
        
        //calculate the displacement based on the angle (assume speed is 1)
        var xChange = playerMaxMovementSpeed * cos(movData[0])
        var yChange = playerMaxMovementSpeed * sin(movData[0])
        
        //scale the movement based on the strength of pushed joystick
        xChange *= movData[1]
        yChange *= movData[1]
        
        
        if movData[0] > (CGFloat.pi / 2) || movData[0] < -(CGFloat.pi / 2) {
            // yChange *= -1
        }
        
        var x = CGFloat.init(0)
        var y = CGFloat.init(0)
        x = playerCurrentPosition.x + xChange
        y = playerCurrentPosition.y + yChange
        if(playerCurrentPosition.x < -scaledFrameSize.width / 2 && xChange < 0) {
            x = playerCurrentPosition.x
        }
        if (playerCurrentPosition.x > scaledFrameSize.width && xChange > 0) {
            x = playerCurrentPosition.x
        }
        
        if(playerCurrentPosition.y > scaledFrameSize.height / 2 && yChange > 0) {
            y = playerCurrentPosition.y
        }
        if (playerCurrentPosition.y < 0 && yChange < 0) {
            y = playerCurrentPosition.y
        }
        print(player.position.x - player.frame.width/2)
        let position = CGPoint(x: x, y: y)
        player.position = position
        print(player.position.x - player.frame.width/2)
        print(self.player.position)
        print(self.progressBar.position)
    }
    
    /*
     joystick data should be a [CGFloat] of size 2.
     @param movData.0 = the angle of movement (obtained from arc tan - which means certain caveats)
     @param movData.1 = the strength of the movement.
     */
    func updatePlayerRotation(JoystickData joyData: [CGFloat]){
        player.zRotation = joyData[0] + rotationOffsetFactorForSpriteImage
    }
    
    
    //MAKR: CODERS
    
    required init?(coder aDecoder: NSCoder) {
        cameraNode = aDecoder.decodeObject(forKey: "cameraNode") as! SKCameraNode
        scaledFrameSize = aDecoder.decodeObject(forKey: "scaledFrameSize") as! CGSize
        rightJS = aDecoder.decodeObject(forKey: "rightJS") as! EEJoyStick
        leftJS = aDecoder.decodeObject(forKey: "leftJS") as! EEJoyStick
        player = aDecoder.decodeObject(forKey: "player") as! SKSpriteNode
        
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        aCoder.encode(cameraNode, forKey: "cameraNode")
        aCoder.encode(scaledFrameSize, forKey: "scaledFrameSize")
        aCoder.encode(rightJS, forKey: "rightJS")
        aCoder.encode(leftJS, forKey: "leftJS")
        aCoder.encode(player, forKey: "player")
    }
    
    override func didMove(to view:SKView){
        self.camera = cameraNode
        run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.run(addMonster),
                SKAction.wait(forDuration: 2.0)
                ])
        ))
        physicsWorld.gravity = CGVector.zero
        physicsWorld.contactDelegate = self
        let backgroundMusic = SKAudioNode(fileNamed: "music.caf")
        backgroundMusic.autoplayLooped = true
        addChild(backgroundMusic)
    }
    
    //returns the size, multiplied by a factor.
    static func createLargeFrameSize(startSize size:CGSize, increaseFactor factor:Int) -> CGSize {
        var factorMut = CGFloat(factor)
        
        //while size overflows, return the size
        while (size.height * factorMut) > CGFloat.greatestFiniteMagnitude
            || (size.width * factorMut) > CGFloat.greatestFiniteMagnitude {
                factorMut /= 2
        }
        
        let newSize = CGSize(width: size.width * factorMut, height: size.height * factorMut)
        
        return newSize
    }
    
    func clearJoyStickData(){
        if !rightJS.joyStickActive(){
            rightMovementData = nil
        }
        if !leftJS.joyStickActive(){
            leftMovementData = nil
        }
    }
    
    
    override func update(_ currentTime: TimeInterval) {
        //Handle Player Updating Based On Joystick Data
        if rightMovementData != nil && rightJS.joyStickActive(){
            updatePlayerRotation(JoystickData: rightMovementData!)
        }
        if leftMovementData != nil && leftJS.joyStickActive(){
            updatePlayerPosition(JoystickData: leftMovementData!)
        }
        rightJS.joystickUpdateMethod()
        leftJS.joystickUpdateMethod()
        clearJoyStickData()
        harborState()
    }
    
    func harborState() {
        if(self.harborLife <= 0 ) {
            self.looseFunc(self.score)
        }
    }
    
    func projectileDidCollideWithMonster(projectile: SKSpriteNode, monster: SKSpriteNode) {
        var emitter = self.newExplosion()
        emitter.position = monster.position
        emitter.name = "exhaust"
        
        // Send the particles to the scene.
        emitter.targetNode = self;
        self.score = self.score + 1
        addChild(emitter)
        projectile.removeFromParent()
        monster.removeFromParent()
        run(SKAction.playSoundFileNamed("boum.mp3", waitForCompletion: false))
    }
    
    func monsterDidCollideWithPlayer(player: SKSpriteNode, monster: SKSpriteNode) {
        monster.removeFromParent()
        self.playerLife = self.playerLife - 1
        self.playerLifeProgressBar.progress = self.playerLifeProgressBar.progress - 0.1
        if(self.playerLifeProgressBar.progress <= 0) {
            self.looseFunc(self.score)
        }
        var emitter = self.newExplosion()
        emitter.position = self.player.position
        emitter.name = "exhaust"
        
        // Send the particles to the scene.
        emitter.targetNode = self;
        addChild(emitter)
        run(SKAction.playSoundFileNamed("boum.mp3", waitForCompletion: false))
    }
    
    func monsterProjDidCollideWithPlayer(player: SKSpriteNode, monsterProj: SKSpriteNode) {
        monsterProj.removeFromParent()
        self.playerLife = self.playerLife - 1
        self.playerLifeProgressBar.progress = self.playerLifeProgressBar.progress - 0.1
        if(self.playerLifeProgressBar.progress <= 0) {
            self.looseFunc(self.score)
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        
        // 1
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        // 2
        print(firstBody.categoryBitMask)
        print(secondBody.categoryBitMask)
        if ((firstBody.categoryBitMask & PhysicsCategory.Monster != 0) &&
            (secondBody.categoryBitMask & PhysicsCategory.Projectile != 0)) {
            if let monster = firstBody.node as? SKSpriteNode, let
                projectile = secondBody.node as? SKSpriteNode {
                projectileDidCollideWithMonster(projectile: projectile, monster: monster)
            }
        }
        
        if ((firstBody.categoryBitMask & PhysicsCategory.Monster != 0) &&
            (secondBody.categoryBitMask & PhysicsCategory.Player != 0)) {
            if let monster = firstBody.node as? SKSpriteNode, let
                player = secondBody.node as? SKSpriteNode {
                monsterDidCollideWithPlayer(player: player, monster: monster)
            }
        }
        
        if ((firstBody.categoryBitMask & PhysicsCategory.Player != 0) &&
            (secondBody.categoryBitMask & PhysicsCategory.MonsterProjectile != 0)) {
            if let player = firstBody.node as? SKSpriteNode, let
                monsterProj = secondBody.node as? SKSpriteNode {
                monsterDidCollideWithPlayer(player: player, monster: monsterProj)

            }
        }
    }
    private func newExplosion() -> SKEmitterNode {
        
        let explosion = SKEmitterNode()
        
        let image = UIImage(named:"spark.png")!
        explosion.particleTexture = SKTexture(image: image)
        explosion.particleColor = UIColor.brown
        explosion.numParticlesToEmit = 100
        explosion.particleBirthRate = 450
        explosion.particleLifetime = 2
        explosion.emissionAngleRange = 360
        explosion.particleSpeed = 100
        explosion.particleSpeedRange = 50
        explosion.xAcceleration = 0
        explosion.yAcceleration = 0
        explosion.particleAlpha = 0.8
        explosion.particleAlphaRange = 0.2
        explosion.particleAlphaSpeed = -0.5
        explosion.particleScale = 0.75
        explosion.particleScaleRange = 0.4
        explosion.particleScaleSpeed = -0.5
        explosion.particleRotation = 0
        explosion.particleRotationRange = 0
        explosion.particleRotationSpeed = 0
        explosion.particleColorBlendFactor = 1
        explosion.particleColorBlendFactorRange = 0
        explosion.particleColorBlendFactorSpeed = 0
        explosion.particleBlendMode = SKBlendMode.add
        
        return explosion
    }
    func sparkEmitter() -> SKEmitterNode? {
        return SKEmitterNode(fileNamed: "spark.sks")
    }
}
