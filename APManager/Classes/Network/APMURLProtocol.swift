//
//  APMURLProtocol.swift
//  APManager
//
//  Created by Tony Clark on 2019/12/17.
//

import Foundation

struct NetworkDuration {
    public var totalDuration: TimeInterval = 0.0
    public var tcpDuration: TimeInterval = 0.0
    public var dnsDuration: TimeInterval = 0.0
    public var sslDuration: TimeInterval = 0.0
}

public class APMURLProtocol: URLProtocol, URLSessionDataDelegate {
    
    private var dataTask: URLSessionDataTask!
    private var startTime: TimeInterval = 0.0
    private var urlRespose: URLResponse?
    private var receivedData: NSMutableData = NSMutableData()
    private var error: Error?
    private var modes: [RunLoop.Mode]!
    private var metrics: AnyObject?
    
    private static let sharedDemux: APMURLSessionDemux = {
        let config = URLSessionConfiguration.default
        let shared = APMURLSessionDemux(config)
        return shared
    }()
    
    private static let swizzleSessionConfiguration: Void = {
        let defaultSessionConfiguration = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.default))
        let interDefaultSessionConfiguration = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.interceptorDefault))
        method_exchangeImplementations(defaultSessionConfiguration!, interDefaultSessionConfiguration!)
        
        let ephemeralSessionConfiguration = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.ephemeral))
        let interEphemeralSessionConfiguration = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.interceptorEphemeral))
        method_exchangeImplementations(ephemeralSessionConfiguration!, interEphemeralSessionConfiguration!)
    }()
    
    @objc public static func start() {
        URLProtocol.registerClass(self)
        _ = swizzleSessionConfiguration
    }
    
    private static let kRecursiveRequestFlagProperty = "com.bitnpc.mhurlProtocol"
    
    /* If you are confused with the thread in which these methods are called, just consult this threading notes. Line number: 115
     (https://github.com/robovm/apple-ios-samples/blob/master/CustomHTTPProtocol/Read%20Me%20About%20CustomHTTPProtocol.txt)
     */
    
    override class public func canInit(with request: URLRequest) -> Bool {
        if (URLProtocol.property(forKey: kRecursiveRequestFlagProperty, in: request) != nil) {
            return false
        }
        if APMNetworkInterceptor.sharedInstance.shouldIntercept() == false {
            return false
        }
        if (request.url?.scheme != "http") && (request.url?.scheme != "https") {
            return false
        }
        return true
    }
    
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        let mutableRequest = request as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: kRecursiveRequestFlagProperty, in: mutableRequest)
        return mutableRequest.copy() as! URLRequest
    }

    public override func startLoading() {
        var calculatedModes = Array<RunLoop.Mode>()
        calculatedModes.append(RunLoop.Mode.default)
        
        let currentMode = RunLoop.current.currentMode
        if (currentMode != nil) && currentMode != RunLoop.Mode.default {
            calculatedModes.append(currentMode!)
        }
        self.modes = calculatedModes
        
        self.startTime = NSDate.timeIntervalSinceReferenceDate
        self.dataTask = APMURLProtocol.self.sharedDemux.dataWithRequest(self.request, delegate: self, modes: self.modes)
        self.dataTask.resume()
    }
    
    public override func stopLoading() {
        let networkDuration = self.calculateDuration(metrics: self.metrics, startInterval: self.startTime, error: self.error)
        APMNetworkInterceptor.sharedInstance.handleResult(self.receivedData as Data, response: self.urlRespose, request: self.request, error: self.error, duration: networkDuration)
        self.dataTask?.cancel()
        self.dataTask = nil
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let redirectRequest = request as! NSMutableURLRequest;
        URLProtocol.removeProperty(forKey: APMURLProtocol.kRecursiveRequestFlagProperty, in: redirectRequest)
        self.client?.urlProtocol(self, wasRedirectedTo: redirectRequest as URLRequest, redirectResponse: response)
        self.dataTask.cancel()
        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: [NSLocalizedDescriptionKey : "Redirected request"])
        self.client?.urlProtocol(self, didFailWithError: error)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.urlRespose = response
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy:.notAllowed)
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.receivedData.append(data)
        self.client?.urlProtocol(self, didLoad: data)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.error = error
        if error != nil {
            self.client?.urlProtocol(self, didFailWithError:error!)
        }else {
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let card = URLCredential.init(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, card)
        }
    }
    
    @available(iOS 10.0, *)
    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        self.metrics = metrics;
    }
    
    func calculateDuration(metrics: AnyObject?, startInterval: TimeInterval, error: Error?) -> NetworkDuration {
        var duration = NetworkDuration()
        if error != nil {
            let nsError = error as NSError?
            if nsError!.code == NSURLErrorSecureConnectionFailed {
                duration.sslDuration = -1
            }else if nsError!.code == NSURLErrorCannotFindHost {
                duration.totalDuration = -1
            }else if nsError!.code == NSURLErrorDNSLookupFailed {
                duration.dnsDuration = -1
            }
            return duration
        }
        if #available(iOS 10.0, *) {
            guard let m = metrics as? URLSessionTaskMetrics, let fm = m.transactionMetrics.first else {
                return duration
            }
            if fm.domainLookupStartDate != nil && fm.domainLookupEndDate != nil {
                duration.dnsDuration = fm.domainLookupEndDate!.timeIntervalSince(fm.domainLookupStartDate!)
            }
            if fm.secureConnectionStartDate != nil && fm.secureConnectionEndDate != nil {
                duration.sslDuration = fm.secureConnectionEndDate!.timeIntervalSince(fm.secureConnectionStartDate!)
            }
            if fm.connectStartDate != nil && fm.connectEndDate != nil {
                duration.tcpDuration = fm.connectEndDate!.timeIntervalSince(fm.connectStartDate!)
            }
            duration.totalDuration = m.taskInterval.duration
            if duration.totalDuration == 0 {
                duration.totalDuration = NSDate.timeIntervalSinceReferenceDate - startInterval
            }
        }
        return duration
    }
}


