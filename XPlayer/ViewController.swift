//
//  ViewController.swift
//  XPlayer
//
//  Created by 邓锋 on 2019/5/13.
//  Copyright © 2019 raisechestnut. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    
    var players = [XPlayer]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let p = XPlayer.init(urlString: "https://media.51wakeup.com/Act-ss-mp4-sd%2Fbedbfd9a9623494da721bc48eb1558a3%2F287070537753169920.mp4")
        p.tag = 1
        self.players.append(p)
        p.play()
        
        
        let v = XPlayerView.init()
        v.playerLayer.player = PlayerCenter.default._avplayer
        
        self.view.addSubview(v)
        v.frame = CGRect.init(x: 50, y: 200, width: 300, height: 300)
        
        
        let b = UIButton()
        b.frame = CGRect.init(x: 50, y: 500, width: 50, height: 50)
        b.backgroundColor = UIColor.red
        b.addTarget(self, action: #selector(playorpause), for: UIControl.Event.touchUpInside)
        self.view.addSubview(b)
        
        
//        for i in 0..<10000{
//            let p = XPlayer.init(urlString: "https://media.51wakeup.com/Act-ss-mp4-sd%2Fbedbfd9a9623494da721bc48eb1558a3%2F287070537753169920.mp4")
//            p.tag = i
//            self.players.append(p)
//
//            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(i * 5)) {
//                p.play()
//            }
//        }

    }
    
    @objc func playorpause(){
        let isplayer = self.players.first?.isPlaying ?? false
        isplayer ? self.players.first?.pause() : self.players.first?.play()
    }


}

