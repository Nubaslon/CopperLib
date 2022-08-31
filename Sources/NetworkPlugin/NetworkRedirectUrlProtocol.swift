//
//  NetworkRedirectUrlProtocol.swift
//  
//
//  Created by ANTROPOV Evgeny on 13.03.2022.
//

import Foundation

class NetworkRedirectUrlProtocol: URLProtocol {
    weak var session: URLSession?
    weak var sessionTask: URLSessionTask?
    let uuid = UUID()
    
    open override class func canInit(with request: URLRequest) -> Bool {
        if let refiredValue = URLProtocol.property(forKey: "NetworkRedirectUrlProtocol", in: request) as? String, refiredValue == "YES" {
            return false
        }
        return true
//        return NetworkInterceptor.shared.isRequestRedirectable(urlRequest: request)
    }
    
    open override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        let mutableRequest: NSMutableURLRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty("YES", forKey: "NetworkRedirectUrlProtocol", in: mutableRequest)
        return mutableRequest.copy() as! URLRequest
    }
    
    open override func startLoading() {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [type(of: self)]
        
        globalNetworkHandler?.saveRequest(id: uuid, urlRequest: request)
        if globalNetworkHandler?.isNetworkInterceptEnabled() == true {
            globalNetworkHandler?.requestOverInterceptor(id: uuid, request: request) {[weak self] response, body, error in
                self?.handleResponse(response: response, data: body, error: error)
            }
        } else {
            let delegate = NetworkRedirectUrlSessionDelegate(urlProtocol: self)
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            let sessionTask = session.dataTask(with: request, completionHandler: { [weak self] (data, response, error) in
                self?.handleResponse(response: response, data: data, error: error)
            })
            sessionTask.resume()
            self.sessionTask = sessionTask
            self.session = session
        }
    }
    
    private func handleResponse(response: URLResponse?, data: Data?, error: Error?) {
        defer {
            session?.invalidateAndCancel()
        }
        globalNetworkHandler?.saveResponse(id: uuid, urlResponse: response, data: data, error: error)
        sessionTask = nil
        if let error = error {            
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let response = response else {
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        client?.urlProtocol(self, didLoad: data ?? Data())
        client?.urlProtocolDidFinishLoading(self)
        
    }
    
    override public func stopLoading() {
        defer {
            session?.invalidateAndCancel()
        }
        guard sessionTask != nil else { return }
        enum RequestCancelError: Error {
            case cancel
        }        
        sessionTask?.cancel()
        globalNetworkHandler?.saveResponse(id: uuid, urlResponse: nil, data: nil, error: RequestCancelError.cancel)
        sessionTask = nil
    }
}

class NetworkRedirectUrlSessionDelegate: NSObject, URLSessionDataDelegate {
    weak var urlProtocol: URLProtocol?
    
    init(urlProtocol: URLProtocol) {
        self.urlProtocol = urlProtocol
        super.init()
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let urlProtocol = urlProtocol else {
            return
        }

        if let error = error {
            urlProtocol.client?.urlProtocol(urlProtocol, didFailWithError: error)
            return
        }
        urlProtocol.client?.urlProtocolDidFinishLoading(urlProtocol)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let urlProtocol = urlProtocol else {
            return
        }
        urlProtocol.client?.urlProtocol(urlProtocol, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let urlProtocol = urlProtocol else {
            return
        }
        urlProtocol.client?.urlProtocol(urlProtocol, didLoad: data)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let urlProtocol = urlProtocol else {
            return
        }
        urlProtocol.client?.urlProtocol(urlProtocol, wasRedirectedTo: request, redirectResponse: response)
    }
}
