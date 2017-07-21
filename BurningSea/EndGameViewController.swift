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

class EndGameViewController: UIViewController {

    var score: Int = 0
    
    @IBOutlet weak var scoreLabel: UILabel!
    
    @IBOutlet weak var bestScore: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.scoreLabel.text = "Votre score est de \(self.score)"
        if let bestScore: Int = UserDefaults.standard.integer(forKey: "BestScore") {
            if(bestScore < self.score) {
                UserDefaults.standard.set(self.score, forKey: "BestScore")
                self.scoreLabel.text = "Nouveau Meilleur Score : \(self.score) !"
                self.bestScore.isHidden = true
            } else {
                self.bestScore.text = "Meilleur Score : \(bestScore)"
            }
        }
        
    }
}
