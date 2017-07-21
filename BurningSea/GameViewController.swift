//
//  GameViewController.swift
//  EnigmaEngineSK
//
//  Created by Matt Stone on 10/14/16.
//  Copyright © 2016 Matt Stone. All rights reserved.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    
    var scene: SKScene?
    
    var score = 0
    var loose : Bool = false
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.scene = LevelScene(view.frame.size, loosFunc:self.loose)
        self.scene?.scaleMode = .resizeFill
        
        //set up view
        let skView = self.view as! SKView
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
        
        self.scene?.backgroundColor = .blue
        skView.presentScene(scene)
        
        //DEFAULT VALUES BELOW
        /*
         if let view = self.view as! SKView? {
         // Load the SKScene from 'GameScene.sks'
         if let scene = SKScene(fileNamed: "GameScene") {
         // Set the scale mode to scale to fit the window
         scene.scaleMode = .aspectFill
         
         // Present the scene
         view.presentScene(scene)
         }
         
         view.ignoresSiblingOrder = true
         
         view.showsFPS = true
         view.showsNodeCount = true
         }
         */
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if(segue.identifier == "LooseSegue") {
            (segue.destination as! EndGameViewController).score = self.score
        }
    }
    
    func loose(score: Int) -> Void {
        if(loose == false) {
            self.loose = true
            self.score = score
            self.performSegue(withIdentifier: "LooseSegue", sender: self)
            self.scene?.removeAllChildren()
            self.scene?.didFinishUpdate()
        }
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return UIInterfaceOrientationMask.landscape
        } else {
            return .all
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
