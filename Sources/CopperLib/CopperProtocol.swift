//
//  CopperProtocol.swift
//  
//
//  Created by ANTROPOV Evgeny on 16.02.2022.
//

import Foundation

#if !FROM_COCOAPODS
import Proto
import Peertalk
#else
import PeerTalk
#endif
import Combine
import SwiftProtobuf
import Network

@available(iOS 13.0, *)
public protocol ConnectionDeleagate: AnyObject {
    func didConnect(port: CopperDevice)
    func didDisconnect(port: CopperDevice)
}

@available(iOS 13.0, *)
public protocol ReadableData: AnyObject {
    func port(didReceiveData data: Data)
    func didDisconnect()
}

@available(iOS 13.0, *)
public protocol SendableData {
    func writeData(data: Data)
    var delegate: ReadableData? { get set }
}

@available(iOS 13.0, *)
public class CopperProtocol: ReadableData {
    enum ManagerError: Error {
        case unknownResponse
        case responseTimeout
        case applicationError(ErrorResponse)
        case mappedError(SwiftProtobuf.Message)
    }
    
    var connectedPort: CopperDevice
    var oldBytes = Data()
    private let reciveSubject = PassthroughSubject<MessageData, Never>()
    
    init(port: CopperDevice) {
        self.connectedPort = port
        self.connectedPort.delegate = self
    }
    
    public func port(didReceiveData data: Data) {
        if !data.isEmpty {
            let isFullLastMessage = data.last == 0
            var separatedBytes = (oldBytes + data).split(separator: 0)
            oldBytes = isFullLastMessage ? Data() : separatedBytes.popLast() ?? Data()
            for recivedBytes in separatedBytes {
                if let bytes = recivedBytes.decodeCOBS() {
                    guard let message = try? MessageData(serializedData: bytes) else { return }
                    reciveSubject.send(message)
                }
            }
        }
    }
    
    public func sendWithoutResponse(message: @autoclosure () -> SwiftProtobuf.Message) async throws -> UUID {
        let message = messageData(for: message())
        let data = try message.serializedData()
        connectedPort.writeData(data: data.encodeCOBS() + [0])
        return message.id.uuid
    }
    
    public func sendWithResponse<T: SwiftProtobuf.Message & TypedMessage>(type: T.Type, message: @autoclosure () -> T.Request, timeout: TimeInterval = 30) async throws -> T.Response where T.Request: SwiftProtobuf.Message, T.Response: SwiftProtobuf.Message {
        let uuid = try await sendWithoutResponse(message: message())
        guard let message = await asyncHandler(timeout: timeout).first(where: {$0.id == uuid}) else {
            throw ManagerError.responseTimeout
        }
        guard let typedMessage = message.data as? T.Response else {
            guard let errorMessage = message.data as? ErrorResponse else {
                throw ManagerError.mappedError(message.data)
            }
            throw ManagerError.applicationError(errorMessage)
        }
        return typedMessage
    }
    
    public func respond(to: InboundData, with: SwiftProtobuf.Message) async throws {        
        var messageWrapper = MessageData()
        messageWrapper.message = try! Google_Protobuf_Any(message: with)
        messageWrapper.id = to.id.data
        let data = try messageWrapper.serializedData()
        connectedPort.writeData(data: data.encodeCOBS() + [0])
    }
    
    public func didDisconnect() {
        reciveSubject.send(completion: .finished)
    }
    
    public func asyncHandler(timeout: TimeInterval? = nil) -> AsyncStream<InboundData> {
        return AsyncStream<InboundData> { continuation in
            let cancelation = reciveSubject.sink { completion in
                continuation.finish()
            } receiveValue: {[weak self] message in
                guard let messageObject = try? self?.message(from: message) else { return }
                continuation.yield(InboundData(data: messageObject, id: message.id.uuid, time: Date()))
            }
            @Sendable
            func myCancel(termination: AsyncStream<InboundData>.Continuation.Termination) -> Void {
                cancelation.cancel()
            }
            continuation.onTermination = myCancel
            if let timeout = timeout {
                DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + timeout) {
                    cancelation.cancel()
                    continuation.finish()
                }
            }
        }
    }
    
    private func messageData(for message: SwiftProtobuf.Message) -> MessageData {
        var messageWrapper = MessageData()
        messageWrapper.message = try! Google_Protobuf_Any(message: message)
        messageWrapper.id = UUID().data
        return messageWrapper
    }
    
    private func message(from messageData: MessageData) throws -> SwiftProtobuf.Message {
        for type in MessageData.allRequests {
            if type.0 == messageData.message.typeURL {
                if let object = try? type.1.init(unpackingAny: messageData.message) {
                    return object
                }
            }
        }
        for type in MessageData.allResponse {
            if type.0 == messageData.message.typeURL {
                if let object = try? type.1.init(unpackingAny: messageData.message) {
                    return object
                }
            }
        }
        print("Print recived unknown type \(messageData.message.typeURL)")
        throw ManagerError.unknownResponse
    }
}

@available(iOS 13.0, *)
public protocol DeviceInfoDelegate: AnyObject {
    func didUpdateInfo(for device: CopperDevice)
}

@available(iOS 13.0, *)
public protocol DeviceInfo {
    var info: HelloMessage? { get }
    var infoDelegate: DeviceInfoDelegate? { get }
}

@available(iOS 13.0, *)
public typealias CopperDevice = DeviceInfo & SendableData

@available(iOS 13.0, *)
func == (lhs: DeviceInfo, rhs: DeviceInfo) -> Bool {
    guard let luuid = lhs.info?.deviceUuid, let ruuid = rhs.info?.deviceUuid else {
        return false
    }
    return luuid == ruuid
}
