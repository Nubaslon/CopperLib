//
//  File.swift
//  
//
//  Created by ANTROPOV Evgeny on 16.02.2022.
//

import Foundation
#if FROM_COCOAPODS
#else
@_exported import Proto
#endif
@_exported import SwiftProtobuf
import Combine

@available(iOS 13.0, *)
public protocol Plugin: AnyObject {
    func handle(message: InboundData) async throws -> SwiftProtobuf.Message?
    var messageSendSubject: PassthroughSubject<SwiftProtobuf.Message, Never> { get }
}


