//
//  ANRMonitor.swift
//  APManager
//
//  Created by Tony on 12/12/2019.
//  Copyright (c) 2019 Tony. All rights reserved.
//

import Foundation
import CoreFoundation

extension NSNotification.Name {
    static let ANRNotification = Notification.Name(rawValue: "ANRNotification")
}

@objc public extension NSNotification {
    static var ANRNotification: String {
        return "ANRNotification"
    }
}

public class ANRMonitor: NSObject {
    @objc public static let sharedInstance = ANRMonitor()
    
    let anrThreshold = 0.088
    private var runLoopObserver : CFRunLoopObserver?
    var dispatchSemaphore: DispatchSemaphore?
    private var timeoutCount: Int = 0
    var runLoopActivity: CFRunLoopActivity?
    
    private override init() {}
    
    @objc public func start() -> Void {
        if self.runLoopObserver != nil {
            return
        }
        self.dispatchSemaphore = DispatchSemaphore(value: 0)
        var context: CFRunLoopObserverContext = CFRunLoopObserverContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        self.runLoopObserver = CFRunLoopObserverCreate(
            kCFAllocatorDefault,
            CFRunLoopActivity.allActivities.rawValue,
            true,
            0,
            runLoopObserverCallback,
            &context
        )
        CFRunLoopAddObserver(CFRunLoopGetMain(), self.runLoopObserver, CFRunLoopMode.commonModes)
        
        DispatchQueue.global().async {
            while true {
                let semaphoreWait = self.dispatchSemaphore?.wait(timeout: DispatchTime.now() + self.anrThreshold)
                if semaphoreWait != DispatchTimeoutResult.success {
                    if self.runLoopObserver == nil {
                        self.timeoutCount = 0;
                        self.dispatchSemaphore = DispatchSemaphore(value: 0)
                        self.runLoopActivity = CFRunLoopActivity.entry
                        return
                    }
                    if self.runLoopActivity == CFRunLoopActivity.beforeSources || self.runLoopActivity == CFRunLoopActivity.afterWaiting {
                        self.timeoutCount += 1
                        // 连续 3 次卡顿
                        if self.timeoutCount < 3 {
                            continue
                        }
                        DispatchQueue.global().async {
                            NotificationCenter.default.post(name: Notification.Name.ANRNotification, object: nil)
                        }
                    }
                }
                self.timeoutCount = 0
            }
        }
    }
    
    @objc public func stop() -> Void {
        if self.runLoopObserver == nil {
            return
        }
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), self.runLoopObserver, CFRunLoopMode.commonModes)
        self.runLoopObserver = nil
    }
}

internal func runLoopObserverCallback(observer: CFRunLoopObserver?, activity: CFRunLoopActivity, info: UnsafeMutableRawPointer?) {
    let monitor: ANRMonitor = Unmanaged<ANRMonitor>.fromOpaque(info!).takeUnretainedValue()
    monitor.runLoopActivity = activity
    
    let semaphore: DispatchSemaphore = monitor.dispatchSemaphore!
    semaphore.signal()
}
