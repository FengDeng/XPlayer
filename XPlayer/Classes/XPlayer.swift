//
//  XPlayer.swift
//  heika
//
//  Created by 邓锋 on 2019/5/13.
//  Copyright © 2019 xiangzhen. All rights reserved.
//

import Foundation
import AVKit

open class XPlayerView : UIView{
    override open class var layerClass: AnyClass {
        get {
            return AVPlayerLayer.self
        }
    }
    
    open var playerLayer : AVPlayerLayer{
        return self.layer as! AVPlayerLayer
    }
}

public typealias XPlayerDelegate = PlayerListener

public class XPlayer{
    
    public var tag = 0
    
    public lazy var playerView : XPlayerView = {
        let v = XPlayerView()
        return v
    }()
    
    open weak var delegate : XPlayerDelegate?
    
    public private(set) var playStatus : PlayerState = .paused
    
    public var isPlaying : Bool{
        if PlayerCenter.default.listen === self{
            return PlayerCenter.default.isPlaying
        }
        return false
    }
    
    let url : URL
    public init(_ url:URL) {
        self.url = url
    }
    public convenience init(urlString:String) {
        var url : URL
        if urlString.starts(with: "http"){
            url = URL.init(string: urlString)!
        }else{
            url = URL.init(fileURLWithPath: urlString)
        }
        self.init(url)
        
    }
    public func play(){
        PlayerCenter.default.load(url: url,playerLayer: self.playerView.playerLayer, listen: self)
    }
    public func pause(){
        if PlayerCenter.default.listen === self{
            PlayerCenter.default.pause()
        }
    }
    public func seek(to time: TimeInterval){
//        if PlayerCenter.default.listen === self{
//            PlayerCenter.default.pause()
//        }
        fatalError()
    }
    deinit {
    }
}

extension XPlayer : PlayerListener{
    public func onPlayTime(_ current: TimeInterval, total: TimeInterval) {
        print("\(self.tag) currentTime:\(current)")
        self.delegate?.onPlayTime(current, total: total)
    }
    
    public func onBufferTime(_ buffer: TimeInterval, total: TimeInterval) {
        print("\(self.tag) bufferTime:\(buffer)")
        self.delegate?.onBufferTime(buffer, total: total)
    }
    
    public func onPlayStatus(_ status: PlayerState) {
        print("\(self.tag):\(status)")
        self.playStatus = status
        self.delegate?.onPlayStatus(status)
    }
    
    
}
