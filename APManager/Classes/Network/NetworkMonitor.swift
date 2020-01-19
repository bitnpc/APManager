//
//  NetworkMonitor.swift
//  APManager
//
//  Created by Tony Clark on 2019/12/16.
//

import Foundation

extension NSNotification.Name {
    static let NetworkMonitorNotification = Notification.Name(rawValue: "NetworkMonitorNotification")
}

@objc public extension NSNotification {
    static var NetworkMonitorNotification: String {
        return "NetworkMonitorNotification"
    }
}

public class NetworkMonitor: NSObject, NetworkMonitorDelegate {
   
    @objc public static let sharedInstance = NetworkMonitor()
    private let reportCountInterval = 100        // 100 次网络请求通知一次
    private var flowLogArray = [NetworkFlowModel]()
    private var shouldMonitor = false
    
    public override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(appWithTerminate(notification:)), name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appEnterBackground(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc public static func bootstrap() {
        APMURLProtocol.start()
        APMNetworkInterceptor.sharedInstance.addDelegate(sharedInstance)
    }
    
    @objc public func start() {
        objc_sync_enter(self)
        self.shouldMonitor = true
        objc_sync_exit(self)
    }
    
    @objc public func stop() {
        objc_sync_enter(self)
        self.shouldMonitor = false
        objc_sync_exit(self)
    }
    
    func shouldIntercept() -> Bool {
        var flag = false
        objc_sync_enter(self)
        flag = shouldMonitor
        objc_sync_exit(self)
        return flag
    }
    
    @objc func appWithTerminate(notification: Notification) -> Void {
        DispatchQueue.main.async {
            self.reportNetworkLog()
        }
    }
    
    @objc func appEnterBackground(notification: Notification) -> Void {
        DispatchQueue.main.async {
            self.reportNetworkLog()
        }
    }
    
    func didNetworkFlowUpdated(flowModel: NetworkFlowModel) -> Void {
        DispatchQueue.main.async {
            self.flowLogArray.append(flowModel)
            if self.flowLogArray.count >= self.reportCountInterval {
                self.reportNetworkLog()
            }
        }
    }
    
    func reportNetworkLog() -> Void {
        let logs = self.flowLogArray
        self.flowLogArray.removeAll()
        NotificationCenter.default.post(name: Notification.Name.NetworkMonitorNotification, object: nil, userInfo: ["logs" : logs])
    }
}
