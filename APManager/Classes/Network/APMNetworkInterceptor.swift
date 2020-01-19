//
//  APMNetworkInterceptor.swift
//  Alamofire
//
//  Created by Tony Clark on 2019/12/24.
//

import Foundation

protocol NetworkMonitorDelegate: class {
    func shouldIntercept() -> Bool
    func didNetworkFlowUpdated(flowModel: NetworkFlowModel) -> Void
}

class APMNetworkInterceptor: NSObject {

    public static let sharedInstance = APMNetworkInterceptor()
    
    private let delegates = WeakList<NetworkMonitorDelegate>()
    
    public func shouldIntercept() -> Bool {
        var shouldIntercept = false
        for delegate in self.delegates {
            if delegate.shouldIntercept() {
                shouldIntercept = true
            }
        }
        return shouldIntercept
    }
    
    public func addDelegate(_ delegate: NetworkMonitorDelegate) {
        self.delegates.append(delegate)
    }

    public func removeDelegate(_ delegate: NetworkMonitorDelegate) {
        self.delegates.remove(delegate)
    }

    public func handleResult(_ data: Data,
                             response: URLResponse?,
                             request: URLRequest,
                             error: Error?,
                             duration: NetworkDuration) -> Void {
        let model = NetworkFlowModel(data: data, response: response, request: request, error: error, duration: duration)
        for delegate in self.delegates {
            delegate.didNetworkFlowUpdated(flowModel: model)
        }
    }
}
