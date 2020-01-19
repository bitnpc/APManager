//
//  APMURLSessionDemux.swift
//  APManager
//
//  Created by Tony Clark on 2019/12/18.
//

import Foundation

class APMURLSessionDemux: NSObject, URLSessionDataDelegate {
    
    internal class MHURLSessionDemuxTaskInfo: NSObject {
        
        private var task: URLSessionDataTask
        public var delegate: URLSessionDataDelegate?
        private var thread: Thread?
        private var modes: Array<String>
        
        init(task: URLSessionDataTask, delegate: URLSessionDataDelegate, modes: Array<RunLoop.Mode>) {
            self.task = task
            self.delegate = delegate
            self.thread = Thread.current
            self.modes = modes.map({ (mode: RunLoop.Mode) -> String in
                return mode.rawValue
            })
        }
        
        public func performBlock(block: @escaping @convention(block)() -> Void) {
            guard let thread = self.thread else { return }
            self.perform(#selector(self.perfomBlockOnClientThread(block:)), on: thread, with: block, waitUntilDone: false, modes: self.modes)
        }
        
        @objc func perfomBlockOnClientThread(block: @escaping @convention(block)() -> Void) {
            block()
        }
        
        func invalidate() -> Void {
            self.delegate = nil
            self.thread = nil
        }
    }
    
    private var configuration: URLSessionConfiguration!
    private var session: URLSession!
    private var taskInfoByTaskID: [NSNumber: MHURLSessionDemuxTaskInfo]!
    private var sessionDelegateQueue: OperationQueue!
    private let queue = DispatchQueue(label: "com.bitnpc.barrierQueue", attributes: .concurrent)
    
    convenience init(_ config: URLSessionConfiguration) {
        self.init()
        self.configuration = config
        self.taskInfoByTaskID = [NSNumber: MHURLSessionDemuxTaskInfo]()
        self.sessionDelegateQueue = OperationQueue.init()
        self.sessionDelegateQueue.maxConcurrentOperationCount = 1
        self.sessionDelegateQueue.name = "MHURLSessionDemux"
        self.session = URLSession.init(configuration: configuration, delegate: self, delegateQueue: self.sessionDelegateQueue)
        
        self.session.sessionDescription = "MHURLSessionDemux"
    }
    
    public func dataWithRequest(_ request: URLRequest, delegate: URLSessionDataDelegate, modes: Array<RunLoop.Mode>) -> URLSessionDataTask {
        
        let task = self.session.dataTask(with: request)
        let taskInfo = MHURLSessionDemuxTaskInfo.init(task: task, delegate: delegate, modes: modes)
        queue.async(flags: .barrier) {
            self.taskInfoByTaskID[NSNumber(value: task.taskIdentifier)] = taskInfo
        }
        return task
    }

    func taskInfoForTask(task: URLSessionTask) -> MHURLSessionDemuxTaskInfo? {
        var taskInfo: MHURLSessionDemuxTaskInfo?
        queue.sync {
            taskInfo = self.taskInfoByTaskID[NSNumber(value: task.taskIdentifier)]
        }
        return taskInfo
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let taskInfo = self.taskInfoForTask(task: task), let delegate = taskInfo.delegate else { return }
        if (delegate.responds(to: #selector(urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)))) {
            taskInfo.performBlock {
                delegate.urlSession?(session, task: task, willPerformHTTPRedirection: response, newRequest: request, completionHandler: completionHandler)
            }
        }else {
            completionHandler(request)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let taskInfo = self.taskInfoForTask(task: task), let delegate = taskInfo.delegate else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        if delegate.responds(to: #selector(urlSession(_:task:didReceive:completionHandler:))) {
            taskInfo.performBlock {
                delegate.urlSession?(session, task: task, didReceive: challenge, completionHandler: completionHandler)
            }
        }else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        
        guard let taskInfo = self.taskInfoForTask(task: task), let delegate = taskInfo.delegate else {
            completionHandler(nil)
            return
        }
        if delegate.responds(to: #selector(urlSession(_:task:needNewBodyStream:))) {
            taskInfo.performBlock {
                delegate.urlSession?(session, task: task, needNewBodyStream: completionHandler)
            }
        }else {
            completionHandler(nil)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
        guard let taskInfo = self.taskInfoForTask(task: task), let delegate = taskInfo.delegate else { return }
        if delegate.responds(to: #selector(urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:))) {
            taskInfo.performBlock {
                delegate.urlSession?(session, task: task, didSendBodyData: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        guard let taskInfo = self.taskInfoForTask(task: task), let delegate = taskInfo.delegate else { return }
        queue.async(flags: .barrier) {
            self.taskInfoByTaskID.removeValue(forKey: NSNumber(value: task.taskIdentifier))
        }
        if delegate.responds(to: #selector(urlSession(_:task:didCompleteWithError:))) {
            taskInfo.performBlock {
                delegate.urlSession?(session, task: task, didCompleteWithError: error)
                taskInfo.invalidate()
            }
        }else {
            taskInfo.invalidate()
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        guard let taskInfo = self.taskInfoForTask(task: dataTask), let delegate = taskInfo.delegate else { return }
        if delegate.responds(to: #selector(urlSession(_:dataTask:didReceive:completionHandler:))) {
            taskInfo.performBlock {
                delegate.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
            }
        }else {
            completionHandler(.allow)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        guard let taskInfo = self.taskInfoForTask(task: dataTask), let delegate = taskInfo.delegate else { return }
        if delegate.responds(to: #selector(urlSession(_:dataTask:didBecome:))) {
            taskInfo.performBlock {
                delegate.urlSession?(session, dataTask: dataTask, didBecome: downloadTask)
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let taskInfo = self.taskInfoForTask(task: dataTask), let delegate = taskInfo.delegate else { return }
        if delegate.responds(to: #selector(urlSession(_:dataTask:didReceive:completionHandler:))) {
            taskInfo.performBlock {
                delegate.urlSession?(session, dataTask: dataTask, didReceive: data)
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        guard let taskInfo = self.taskInfoForTask(task: dataTask), let delegate = taskInfo.delegate else { return }
        if delegate.responds(to: #selector(urlSession(_:dataTask:willCacheResponse:completionHandler:))) {
            taskInfo.performBlock {
                delegate.urlSession?(session, dataTask: dataTask, willCacheResponse: proposedResponse, completionHandler: completionHandler)
            }
        }else {
            completionHandler(proposedResponse)
        }
    }
    
    @available(iOS 10.0, *)
    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let taskInfo = self.taskInfoForTask(task: task), let delegate = taskInfo.delegate else { return }
        if delegate.responds(to: #selector(urlSession(_:task:didFinishCollecting:))) {
            taskInfo.performBlock {
                delegate.urlSession?(session, task: task, didFinishCollecting: metrics)
            }
        }
    }
}
