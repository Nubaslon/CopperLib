//
//  NetworkRequestInterceptor.swift
//  
//
//  Created by ANTROPOV Evgeny on 13.03.2022.
//

import Foundation


@available(iOS 13.0, *)
@objc public class NetworkRequestInterceptor: NSObject{

    class func swizzleProtocolClasses(){
        let instance = URLSessionConfiguration.default
        let uRLSessionConfigurationClass: AnyClass = object_getClass(instance)!

        let method1: Method = class_getInstanceMethod(uRLSessionConfigurationClass, #selector(getter: uRLSessionConfigurationClass.protocolClasses))!
        let method2: Method = class_getInstanceMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.fakeProcotolClasses))!

        method_exchangeImplementations(method1, method2)
    }
    
    public class func startRecording() {
        URLProtocol.registerClass(NetworkRedirectUrlProtocol.self)
        swizzleProtocolClasses()
    }
    
    public class func stopRecording() {
        URLProtocol.unregisterClass(NetworkRedirectUrlProtocol.self)
        swizzleProtocolClasses()
    }
}

@available(iOS 13.0, *)
extension URLSessionConfiguration {
    
    @objc func fakeProcotolClasses() -> [AnyClass]? {
        guard let fakeProcotolClasses = self.fakeProcotolClasses() else {
            return []
        }
        var originalProtocolClasses = fakeProcotolClasses.filter {
            return $0 != NetworkRedirectUrlProtocol.self
        }
        originalProtocolClasses.insert(NetworkRedirectUrlProtocol.self, at: 0)
        return originalProtocolClasses
    }
    
}
