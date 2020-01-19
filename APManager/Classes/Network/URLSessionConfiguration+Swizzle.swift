//
//  URLSessionConfiguration+Swizzle.swift
//  APManager
//
//  Created by Tony Clark on 2019/12/19.
//

import Foundation

extension URLSessionConfiguration {
    
    @objc open class var interceptorDefault: URLSessionConfiguration {
        let configuration = self.interceptorDefault
        configuration.protocolClasses?.insert(APMURLProtocol.self, at: 0)
        return configuration
    }
    
    @objc open class var interceptorEphemeral: URLSessionConfiguration {
        let configuration = self.interceptorEphemeral
        configuration.protocolClasses?.insert(APMURLProtocol.self, at: 0)
        return configuration
    }
}


