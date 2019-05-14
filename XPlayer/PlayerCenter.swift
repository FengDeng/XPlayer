//
//  PlayerCenter.swift
//  heika
//
//  Created by 邓锋 on 2019/5/13.
//  Copyright © 2019 xiangzhen. All rights reserved.
//

import Foundation
import AVKit

/// Item playback states.
public enum PlayerState: CustomStringConvertible,Equatable {
    ///加载中
    case loading
    ///结束
    case ended
    ///播放中
    case playing
    ///暂停
    case paused
    ///失败
    case failed(Error?)
    
    public static func == (lhs: PlayerState, rhs: PlayerState) -> Bool {
        switch (lhs,rhs) {
        case (.loading,.loading):
            return true
        case (.ended,.ended):
            return true
        case (.playing,.playing):
            return true
        case (.paused,.paused):
            return true
        case (.failed,.failed):
            return true
        default:
            return false
        }
    }
    public var description: String {
        get {
            switch self {
            case .ended:
                return "Ended"
            case .playing:
                return "Playing"
            case .failed(let e):
                return "Failed:\(String(describing: e))"
            case .paused:
                return "Paused"
            case .loading:
                return  "Loading"
            }
        }
    }
}


public enum PlayerEndState {
    ///暂停
    case pause
    ///重置到开头
    case reset
    ///循环播放
    case loop
}

public protocol PlayerListener : class {
    func onPlayTime(_ current:TimeInterval,total:TimeInterval)
    func onBufferTime(_ buffer:TimeInterval,total:TimeInterval)
    func onPlayStatus(_ status:PlayerState)
}

// MARK: - Player

/// ▶️ Player, simple way to play and stream media
open class PlayerCenter {
    
    /// single default
    public static let `default` = PlayerCenter()
    
    ///listen
    private(set) weak var listen : PlayerListener?
    
    /// Pauses playback automatically when resigning active.
    open var playbackPausesWhenResigningActive: Bool = true
    
    /// Pauses playback automatically when backgrounded.
    open var playbackPausesWhenBackgrounded: Bool = true
    
    /// Resumes playback when became active.
    open var playbackResumesWhenBecameActive: Bool = false
    
    /// Resumes playback when entering foreground.
    open var playbackResumesWhenEnteringForeground: Bool = false
    

    
    /// Current playback state of the Player.
    open var playerState: PlayerState = .loading {
        didSet {
            if playerState == oldValue{return}
            self.executeClosureOnMainQueueIfNecessary {
                self.listen?.onPlayStatus(self.playerState)
            }
        }
    }
    
    open var isPlaying : Bool{
        return self._avplayer.rate > 0
    }
    
    open var endState : PlayerEndState = .pause
    
    /// Playback buffering size in seconds.
    open var bufferSizeInSeconds: Double = 10
    
    /// Maximum duration of playback.
    open var maximumDuration: TimeInterval {
        get {
            if let playerItem = self._playerItem {
                return CMTimeGetSeconds(playerItem.duration)
            } else {
                return 0
            }
        }
    }
    

    public private(set) var _avplayer: AVPlayer = AVPlayer()
    
    internal var _playerItem: AVPlayerItem?
    internal var _asset: AVAsset?
    
    internal var _playerObservers = [NSKeyValueObservation]()
    internal var _playerItemObservers = [NSKeyValueObservation]()
    internal var _playerLayerObserver: NSKeyValueObservation?
    internal var _playerTimeObserver: Any?
    internal var _seekTimeRequested: CMTime?
    internal var _lastBufferTime: Double = 0
    internal var _preferredMaximumResolution: CGSize = .zero
    
    /// user click play button or pause button
    internal var _isUserPlay: Bool = true
    
    // MARK: - object lifecycle
    
    public init() {
        self._avplayer.actionAtItemEnd = .pause
        self.addPlayerObservers()
        self.addApplicationObservers()
    }
    
    deinit {
        self._avplayer.pause()

        self.removePlayerItemObservers()
        
        self.removePlayerItemNotifications()
        
        self.removePlayerObservers()
        
        self.removeApplicationObservers()
        
    }
    
}

// MARK: - action funcs

extension PlayerCenter {
    
    open func load(url:URL,listen:PlayerListener){
        
        if self.listen === listen{
            self.play()
            return
        }
        self.removePreviousItem()
        
        self.listen = listen
        self._isUserPlay = true
        self.playerState = .loading
        let asset = AVAsset.init(url: url)
        self._asset = asset
        let loadableKeys = ["playable","duration"]
        asset.loadValuesAsynchronously(forKeys: loadableKeys) {[unowned asset] in
            for key in loadableKeys{
                var error: NSError? = nil
                let status = asset.statusOfValue(forKey: key, error: &error)
                if status == .failed{
                    self.playerState = .failed(error)
                    return
                }
            }
            if !asset.isPlayable {
                let e = NSError.init(domain: "PlayerErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey : "Asset.isPlayable is false"])
                self.playerState = .failed(e)
                return
            }
            
            ///success
            let item = AVPlayerItem.init(asset: asset)
            self.replaceCurrentItem(item: item)
            self._autoPlay()
        }
    }
    
    open func play() {
        if self._isUserPlay{return}
        self._isUserPlay = true
        self._avplayer.play()
    }
    
    open func pause() {
        if !self._isUserPlay{return}
        self._isUserPlay = false
        self._avplayer.pause()
    }
    
    open func seek(to time: CMTime, completionHandler: ((Bool) -> Swift.Void)? = nil) {
        if let playerItem = self._playerItem {
            return playerItem.seek(to: time, completionHandler: completionHandler)
        } else {
            _seekTimeRequested = time
        }
    }
    
    open func seekToTime(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: ((Bool) -> Swift.Void)? = nil) {
        if let playerItem = self._playerItem {
            return playerItem.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter, completionHandler: completionHandler)
        }
    }
    
    fileprivate func _autoPlay(){
        if self._isUserPlay{
            self._avplayer.play()
        }
    }
    fileprivate func _autoPause(){
        self._avplayer.pause()
    }
    
}

// MARK: - loading funcs

extension PlayerCenter {
    
    fileprivate func removePreviousItem(){
        self._avplayer.pause()
        self.listen = nil
        self.removePlayerItemObservers()
        self.removePlayerItemNotifications()
    }
    
    fileprivate func replaceCurrentItem(item:AVPlayerItem){

        self._playerItem = item
        self.addPlayerItemObservers()
        self.addPlayerItemNotifications()

        self._avplayer.replaceCurrentItem(with: self._playerItem)
    }
    
}

// MARK: - NSNotifications

extension PlayerCenter {
    
    // MARK: - UIApplication
    
    internal func addApplicationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    internal func removeApplicationObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - AVPlayerItem handlers
    
    @objc internal func playerItemDidPlayToEndTime(_ aNotification: Notification) {
        self.executeClosureOnMainQueueIfNecessary {
            self.playerState = .ended
            switch self.endState{
            case .pause:
                self._avplayer.pause()
                break
            case .reset:
                self._avplayer.pause()
                self._avplayer.seek(to: CMTime.zero, completionHandler: { _ in
                    self.pause()
                })
                break
            case .loop:
                self._avplayer.pause()
                self._avplayer.seek(to: CMTime.zero)
                self._avplayer.play()
                break
            @unknown default:
                break
            }
        }
    }
    
    @objc internal func playerItemFailedToPlayToEndTime(_ aNotification: Notification) {
        self.playerState = .failed(self._playerItem?.error)
    }
    
    // MARK: - UIApplication handlers
    
    @objc internal func handleApplicationWillResignActive(_ aNotification: Notification) {
        if self.playbackPausesWhenResigningActive{
            self._autoPause()
        }
    }
    
    @objc internal func handleApplicationDidBecomeActive(_ aNotification: Notification) {
        if self.playbackResumesWhenBecameActive {
            self._autoPlay()
        }
        
    }
    
    @objc internal func handleApplicationDidEnterBackground(_ aNotification: Notification) {
        if self.playbackPausesWhenBackgrounded {
            self._autoPause()
        }
    }
    
    @objc internal func handleApplicationWillEnterForeground(_ aNoticiation: Notification) {
        if self.playbackResumesWhenEnteringForeground {
            self._autoPlay()
        }
    }
    
}

// MARK: - KVO

extension PlayerCenter {
    
    // MARK: - AVPlayerItemObservers
    
    internal func addPlayerItemObservers() {
        guard let playerItem = self._playerItem else {
            return
        }
        
        self._playerItemObservers.append(playerItem.observe(\.isPlaybackBufferEmpty, options: [.new, .old]) { [weak self] (object, change) in
            if object.isPlaybackBufferEmpty {
                self?.playerState = .loading
            }
            
            switch object.status {
            case .readyToPlay:
                break
            case .failed:
                self?.playerState = PlayerState.failed(playerItem.error)
            default:
                break
            }
        })
        
        self._playerItemObservers.append(playerItem.observe(\.isPlaybackLikelyToKeepUp, options: [.new, .old]) { [weak self] (object, change) in
            if object.isPlaybackLikelyToKeepUp {
                self?._autoPlay()
            }
            switch object.status {
            case .unknown:
                fallthrough
            case .readyToPlay:
                break
            case .failed:
                self?.playerState = PlayerState.failed(playerItem.error)
                break
            @unknown default:
                break
            }
        })
        
        //        self._playerItemObservers.append(playerItem.observe(\.status, options: [.new, .old]) { (object, change) in
        //        })
        
        self._playerItemObservers.append(playerItem.observe(\.loadedTimeRanges, options: [.new, .old]) { [weak self] (object, change) in
            guard let strongSelf = self else {
                return
            }
            let timeRanges = object.loadedTimeRanges
            if let timeRange = timeRanges.first?.timeRangeValue {
                let bufferedTime = CMTimeGetSeconds(CMTimeAdd(timeRange.start, timeRange.duration))
                if strongSelf._lastBufferTime != bufferedTime {
                    strongSelf._lastBufferTime = bufferedTime
                    ///main queue update Buffer time
                    strongSelf.executeClosureOnMainQueueIfNecessary {
                        strongSelf.listen?.onBufferTime(bufferedTime, total: strongSelf._playerItem?.duration.seconds ?? 0)
                    }
                }
            }
            
            let currentTime = CMTimeGetSeconds(object.currentTime())
            let passedTime = strongSelf._lastBufferTime <= 0 ? currentTime : (strongSelf._lastBufferTime - currentTime)
            
            if (passedTime >= strongSelf.bufferSizeInSeconds ||
                strongSelf._lastBufferTime == strongSelf.maximumDuration ||
                timeRanges.first == nil) {
                 strongSelf._autoPlay()
            }
        })
    }
    
    internal func removePlayerItemObservers() {
        for observer in self._playerItemObservers {
            observer.invalidate()
        }
        self._playerItemObservers.removeAll()
    }
    
    // MARK: - AVPlayerObservers
    
    internal func addPlayerObservers() {
        self._playerTimeObserver = self._avplayer.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 100), queue: DispatchQueue.main, using: { [weak self] timeInterval in
            guard let strongSelf = self,let item = strongSelf._playerItem else {
                return
            }
            strongSelf.listen?.onPlayTime(item.currentTime().seconds, total: item.duration.seconds)
        })
        
        if #available(iOS 10.0, tvOS 10.0, *) {
            self._playerObservers.append(self._avplayer.observe(\.timeControlStatus, options: [.new, .old]) { [weak self] (object, change) in
                switch object.timeControlStatus {
                case .paused:
                    self?.playerState = .paused
                case .playing:
                    self?.playerState = .playing
                case .waitingToPlayAtSpecifiedRate:
                    self?.playerState = .loading
                    break
                @unknown default:
                    break
                }
            })
        }
        
    }
    
    internal func removePlayerObservers() {
        if let observer = self._playerTimeObserver {
            self._avplayer.removeTimeObserver(observer)
        }
        for observer in self._playerObservers {
            observer.invalidate()
        }
        self._playerObservers.removeAll()
    }
    
    internal func addPlayerItemNotifications() {
        guard let item = self._playerItem else{return}
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidPlayToEndTime(_:)), name: .AVPlayerItemDidPlayToEndTime, object: item)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlayToEndTime(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: item)
    }
    
    internal func removePlayerItemNotifications() {
        guard let item = self._playerItem else{return}
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: item)
    }
    
    
    
}

// MARK: - queues

extension PlayerCenter {
    
    internal func executeClosureOnMainQueueIfNecessary(withClosure closure: @escaping () -> Void) {
        if Thread.isMainThread {
            closure()
        } else {
            DispatchQueue.main.async(execute: closure)
        }
    }
    
}
