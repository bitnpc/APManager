//
//  NetworkFlowModel.swift
//  APManager
//
//  Created by Tony Clark on 2019/12/24.
//

import Foundation

public class NetworkFlowModel: NSObject {
    
    @objc public let host: String
    @objc public let path: String
    @objc public let urlString: String
    @objc public let dnsDuration: TimeInterval
    @objc public let sslDuration: TimeInterval
    @objc public let tcpDuration: TimeInterval
    @objc public let totalDuration: TimeInterval
    @objc public let uploadFlow: UInt
    @objc public let downFlow: UInt
    
    init(data: Data,
         response: URLResponse?,
         request: URLRequest,
         error: Error?,
         duration: NetworkDuration) {
        if request.url != nil {
            self.host = request.url!.host ?? ""
            self.path = request.url!.path 
            self.urlString = request.url!.absoluteString
        }else {
            self.host = ""
            self.path = ""
            self.urlString = ""
        }
        self.dnsDuration = duration.dnsDuration
        self.sslDuration = duration.sslDuration
        self.tcpDuration = duration.tcpDuration
        self.totalDuration = duration.totalDuration
        self.uploadFlow = NetworkUtil.getRequestLength(with: request)
        if response == nil {
            self.downFlow = 0
        }else {
            self.downFlow = NetworkUtil.getResponseLength(with: response!, responseData: data)
        }
        super.init()
    }

}
