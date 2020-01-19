//
//  NetworkUtil.swift
//  APManager
//
//  Created by Tony Clark on 2019/12/24.
//

import Foundation

class NetworkUtil {
    
    static func getRequestLength(with request: URLRequest) -> UInt {
        var headerFields = request.allHTTPHeaderFields
        let cookiesHeader = self.getCookies(request)
        if cookiesHeader.count > 0 {
            let header = NSMutableDictionary.init(dictionary: headerFields ?? [:])
            header.addEntries(from: cookiesHeader)
            headerFields = header.copy() as? [String : String]
        }
        let headerLength = self.getHeaderLength(headerFields)
        let httpBody = self.getHttpBody(from: request)
        let bodyLength = UInt(httpBody?.count ?? 0)
        return headerLength + bodyLength
    }
    
    static func getResponseLength(with request: URLResponse, responseData: Data) -> UInt {
        var responseLength: UInt = 0
        guard let httpResponse = request as? HTTPURLResponse else {
            return 0
        }
        let headerFields = httpResponse.allHeaderFields
        let headerLength = self.getHeaderLength(headerFields as? Dictionary<String, String>)
        
        var contentLength: UInt = 0
        if httpResponse.expectedContentLength != -1 {
            contentLength = UInt(httpResponse.expectedContentLength)
        }else {
            contentLength = UInt(responseData.count)
        }
        responseLength = headerLength + contentLength
        return responseLength
    }
    
    static func getHeaderLength(_ headers: Dictionary<String, String>?) -> UInt {
        if headers != nil {
            do {
                let data = try JSONSerialization.data(withJSONObject: headers as Any, options: .prettyPrinted)
                return UInt(data.count)
            }catch {
                return 0
            }
        }
        return 0
    }
    
    static func getHttpBody(from request: URLRequest) -> Data? {
        var httpBody: Data? = nil
        if request.httpBody != nil {
            httpBody = request.httpBody!
        }
        if request.httpMethod == "POST" {
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer {
                buffer.deallocate()
            }
            guard let stream: InputStream = request.httpBodyStream else { return httpBody }
            let data = NSMutableData()
            while stream.hasBytesAvailable {
                let readLen = stream.read(buffer, maxLength: bufferSize)
                if readLen > 0 && stream.streamError == nil {
                    data.append(buffer, length: readLen)
                }
            }
            httpBody = data.copy() as? Data
            stream.close()
        }
        return httpBody
    }
    
    static func getCookies(_ request: URLRequest) -> Dictionary<String, String> {
        guard let url = request.url else {
            return Dictionary()
        }
        var cookiesHeader: Dictionary<String, String> = Dictionary()
        let cookieStorage = HTTPCookieStorage.shared
        let cookies = cookieStorage.cookies(for: url)
        if cookies != nil {
            cookiesHeader = HTTPCookie.requestHeaderFields(with: cookies!)
        }
        return cookiesHeader
    }
}
