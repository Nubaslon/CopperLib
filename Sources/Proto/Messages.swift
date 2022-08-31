//
//  File.swift
//  
//
//  Created by ANTROPOV Evgeny on 16.02.2022.
//

import Foundation
@_exported import SwiftProtobuf

extension MessageData.Connect: TypedMessage {}
extension MessageData.LogsLabels: TypedMessage {}
extension MessageData.LogsList: TypedMessage {}
extension MessageData.Logs: TypedMessage {}
extension MessageData.LiveLog: TypedMessage {}
extension MessageData.NetworkLabels: TypedMessage {}
extension MessageData.NetworkRecords: TypedMessage {}
extension MessageData.NetworkLiveRecord: TypedMessage {}
extension MessageData.NetworkIntecept: TypedMessage {}
extension MessageData.NetworkInteceptRecord: TypedMessage {}
public extension MessageData {
    private static var allTypes: [(request: SwiftProtobuf.Message.Type, response: SwiftProtobuf.Message.Type)] {
        return [
            MessageData.Connect().subTypes,
            MessageData.LogsLabels().subTypes,
            MessageData.LogsList().subTypes,
            MessageData.Logs().subTypes,
            MessageData.LiveLog().subTypes,
            MessageData.NetworkLabels().subTypes,
            MessageData.NetworkRecords().subTypes,
            MessageData.NetworkLiveRecord().subTypes,
            MessageData.NetworkIntecept().subTypes,
            MessageData.NetworkInteceptRecord().subTypes,
            (ErrorResponse.self, ErrorResponse.self)
        ]
    }
}

public protocol TypedMessage {
    associatedtype Request
    associatedtype Response
}

public extension TypedMessage where Request : SwiftProtobuf.Message, Response: SwiftProtobuf.Message {
    var subTypes: (request: SwiftProtobuf.Message.Type, response: SwiftProtobuf.Message.Type) { return (Request.self, Response.self)  }
}

public protocol AnyTypedMessage {
    var request: SwiftProtobuf.Message { get }
    var response: SwiftProtobuf.Message { get }
}

public extension MessageData {
    static var allRequests: [(String, SwiftProtobuf.Message.Type)] {
        return allTypes.map({ ((try? Google_Protobuf_Any(message: $0.request.init()).typeURL) ?? "", $0.request) })
    }
    
    static var allResponse: [(String, SwiftProtobuf.Message.Type)] {
        return allTypes.map({ ((try? Google_Protobuf_Any(message: $0.response.init()).typeURL) ?? "", $0.response) })
    }
}

public struct InboundData {
    public let data: SwiftProtobuf.Message
    public let id: UUID
    public let time: Date
    
    public init(data: SwiftProtobuf.Message, id: UUID, time: Date) {
        self.data = data
        self.id = id
        self.time = time
    }
}

