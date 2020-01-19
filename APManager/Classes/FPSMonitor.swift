//
//  FPSMonitor.swift
//  APManager
//
//  Created by Tony on 12/12/2019.
//  Copyright (c) 2019 Tony. All rights reserved.
//

import Foundation

// FPSMonitor 协议，实现此方法获取 fps 更新通知
@objc public protocol FPSMonitorDelegate: NSObjectProtocol {
    func fpsMonitor(_ monitor: FPSMonitor, didUpdate fps: Int) -> Void
}

public class FPSMonitor: NSObject {
    
    @objc public weak var delegate: FPSMonitorDelegate?
    
    // 防止循环引用，添加弱引用
    internal class DisplayLinkProxy: NSObject {
        weak var monitor: FPSMonitor?
        
        @objc func tick(_ displayLink: CADisplayLink) -> Void {
            monitor?.tock(displayLink)
        }
    }
    
    private let displayLink: CADisplayLink
    private let displayLinkProxy: DisplayLinkProxy
    
    public override init() {
        self.displayLinkProxy = DisplayLinkProxy()
        self.displayLink = CADisplayLink(
            target: self.displayLinkProxy, selector: #selector(DisplayLinkProxy.tick(_:))
        )
        super.init()
        self.displayLinkProxy.monitor = self
    }
    
    deinit {
        self.displayLink.invalidate()
    }
    
    private var runloop: RunLoop?
    private var mode: RunLoop.Mode?
    
    @objc public func start() -> Void {
        self.stop()
        self.runloop = RunLoop.main
        self.mode = RunLoop.Mode.common
        self.displayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
    }
    
    @objc public func stop() -> Void {
        guard let runloop = self.runloop, let mode = self.mode else {
            return
        }
        self.displayLink.remove(from: runloop, forMode: mode)
        self.runloop = nil
        self.mode = nil
    }
    
    // 最后一次计算 fps 的起始时间
    private var lastTime: CFAbsoluteTime = 0.0
    
    // 帧数
    private var cnt = 0
    
    // fps 更新间隔
    public var monitorInterval: TimeInterval = 3.0
    
    // DisplayLink 回调方法
    func tock(_ displayLink: CADisplayLink) -> Void {
        if fabs(self.lastTime - 0.0) < Double.leastNonzeroMagnitude {
            self.lastTime = CFAbsoluteTimeGetCurrent()
            return;
        }
        self.cnt += 1
        
        let currentTime = CFAbsoluteTimeGetCurrent()
        let timeInterval = currentTime - lastTime
        
        if timeInterval >= monitorInterval {
            let fps = Int(round(Double(self.cnt) / timeInterval))
            debugPrint("fps: \(fps)")
            self.delegate?.fpsMonitor(self, didUpdate: fps)
            self.lastTime = 0.0
            self.cnt = 0
        }
    }
}

