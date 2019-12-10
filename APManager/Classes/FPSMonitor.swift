
//
//  FPSMonitor.swift
//  miapm
//
//  Created by Tong Chao on 12/10/2019.
//  Copyright (c) 2019 Tong Chao. All rights reserved.
//

import UIKit

// FPSMonitor 协议，实现此方法获取 fps 更新通知
public protocol FPSMonitorDelegate: NSObjectProtocol {
    func fpsMonitor(_ monitor: FPSMonitor, didUpdate fps: Int) -> Void
}

public class FPSMonitor: NSObject {
    
    public weak var delegate: FPSMonitorDelegate?
    
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
    
    public func startMonitor() -> Void {
        self.stopMonitor()
        self.displayLink.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
    }
    
    public func stopMonitor() -> Void {
        self.displayLink.remove(from: RunLoop.main, forMode: RunLoopMode.commonModes)
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
        
        if timeInterval - lastTime >= monitorInterval {
            let fps = Int(round(Double(self.cnt) / timeInterval))
            self.delegate?.fpsMonitor(self, didUpdate: fps)
            self.lastTime = 0.0
            self.cnt = 0
        }
    }
}

