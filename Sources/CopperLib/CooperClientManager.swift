//
//  CopperClientManager.swift
//  
//
//  Created by ANTROPOV Evgeny on 16.02.2022.
//
#if !os(macOS)
import Foundation
import UIKit
#if !FROM_COCOAPODS
import Proto
import CopperPlugin
import Peertalk
#else
import PeerTalk
#endif
import Combine
import SwiftProtobuf
import Network


@available(iOS 13.0, *)
class CopperClientManager: ConnectionDeleagate {
    private var connectionState: State = .pending
    var darkLighPort = USBPortWrapper()
    var nerworkPort = NetworkPort()
    var currentProto: CopperProtocol?
    
    private var plugins = [Plugin]()
    var cancelables = Set<AnyCancellable>()
    
    enum State {
        case pending
        case waitingResponse
        case connected
    }
    
    init() {
        startNewPorts()
        darkLighPort.connectionDelegate = self
    }
    
    func startNewPorts() {
        currentProto = nil
        nerworkPort.netConnection.cancel()
        nerworkPort = NetworkPort()
        nerworkPort.connectionDelegate = self
    }
    
    func registerPlugin(plugin: Plugin) {
        plugins.append(plugin)
    }
    
    func handleInboundRequest(proto: CopperProtocol) {
        let stream = proto.asyncHandler()
        Task {
            do {
                for await inputMessage in stream {
                    try Task.checkCancellation()
                    switch(inputMessage.data) {
                    case _ as MessageData.Connect.Request:
                        // TODO: Realize connected state
                        enableAllPlugins(proto: proto)
                        try await proto.respond(to: inputMessage, with: MessageData.Connect.Response.init())
                        connectionState = .connected
                        currentProto = proto
                    default:
                        try await handleConnectedData(proto: proto, data: inputMessage)
                    }
                }
            } catch {
                print(error)
            }
        }
    }
    
    func enableAllPlugins(proto: CopperProtocol) {
        plugins.forEach({ plugin in
            plugin.messageSendSubject
                .eraseToAnyPublisher()
                .sink(receiveValue: { (message: SwiftProtobuf.Message) in
                Task {
                    _ = try? await proto.sendWithoutResponse(message: message)
                }
            }).store(in: &cancelables)
        })
    }
    
    func handleConnectedData(proto: CopperProtocol, data: InboundData) async throws {
        // TODO: Check connection state
        guard connectionState == .connected else { return }
        for plugin in plugins {
            if let response = try await plugin.handle(message: data) {
                try await proto.respond(to: data, with: response)
                break
            }
        }
    }
    
    func didConnect(port: CopperDevice) {
        let helloMessage = HelloMessage.with { message in
            message.deviceUuid = UUID().uuidString
            message.deviceName = UIDevice.current.name
        }
        let data = try! helloMessage.serializedData()
        port.writeData(data: data)
        let cooperProtocol = CopperProtocol(port: port)
        connectionState = .waitingResponse
        handleInboundRequest(proto: cooperProtocol)
    }
    
    func didDisconnect(port: CopperDevice) {
        connectionState = .pending
        startNewPorts()
        cancelables.forEach({$0.cancel()})
    }
}

class USBPortWrapper: NSObject, PTChannelDelegate, CopperDevice {
    weak var delegate: ReadableData?
    weak var connectionDelegate: ConnectionDeleagate?
    var port: PTChannel?
    var channel: PTChannel?
    var info: HelloMessage?
    weak var infoDelegate: DeviceInfoDelegate?
    
    override init() {
        super.init()
        self.port = PTChannel(protocol: nil, delegate: self)
        self.port?.listen(on: 13129, IPv4Address: INADDR_LOOPBACK, callback: { error in
            assert(error == nil, "Failed open port")
        })
    }
    
    func close() {
        self.port?.close()
    }
    
    func channel(_ channel: PTChannel, shouldAcceptFrame type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
        return true
    }
    
    func channel(_ channel: PTChannel, didRecieveFrame type: UInt32, tag: UInt32, payload: Data?) {
        guard let data = payload else { return }
        if let helloMessage = try? HelloMessage(contiguousBytes: data), self.info == nil  {
            self.info = helloMessage
            self.infoDelegate?.didUpdateInfo(for: self)
        } else {
            delegate?.port(didReceiveData: data)
        }
    }
    
    func channelDidEnd(_ channel: PTChannel, error: Error?) {
        self.connectionDelegate?.didDisconnect(port: self)
    }
    
    func channel(_ channel: PTChannel, didAcceptConnection otherChannel: PTChannel, from address: PTAddress) {
        self.channel?.close()
        self.channel = otherChannel
        self.channel?.delegate = self
        self.connectionDelegate?.didConnect(port: self)
    }
    
    func writeData(data: Data) {
        self.channel?.sendFrame(type: 1, tag: 0, payload: data, callback: nil)
    }
}


class NetworkPort: CopperDevice {
    var info: HelloMessage?
    weak var infoDelegate: DeviceInfoDelegate?
    let netConnection: NWConnection
    private let netConnectionQueue = DispatchQueue.global(qos: .userInitiated)
    
    init() {
        let options = NWProtocolTCP.Options()
        options.enableKeepalive = true
        options.keepaliveInterval = 1
        options.keepaliveIdle = 1
        options.keepaliveCount = 2
        options.retransmitFinDrop = true
        options.connectionDropTime = 1
        options.connectionTimeout = 1
        options.persistTimeout = 1
        options.noDelay = true
        let params = NWParameters(tls: nil, tcp: options)
        params.allowLocalEndpointReuse = false
        netConnection = NWConnection(host: .ipv4(.loopback), port: .init(rawValue: 13228)!, using: params)
        
        
        self.netConnection.stateUpdateHandler = {[weak self] newState in
            guard let self = self else { return }
            switch(newState) {
            case .setup:
                self.netConnection.start(queue: self.netConnectionQueue)
            case .ready:
                self.connectionDelegate?.didConnect(port: self)
                self.readData()
            case .cancelled, .failed(_):
                self.delegate?.didDisconnect()
                self.connectionDelegate?.didDisconnect(port: self)
                
            case .waiting(_):
                self.netConnectionQueue.asyncAfter(deadline: .now() + 0.5) {
                    self.netConnection.restart()
                }
            case .preparing:
                ()
            }
        }
        
        self.netConnectionQueue.async {
            self.netConnection.start(queue: self.netConnectionQueue)
        }
    }
    
    func readData() {
        var recursive: () -> () = {}
        recursive = {
            self.netConnection.receive(minimumIncompleteLength: 1, maximumLength: 6500) { data, contentContext, isComplete, error in
                if let error = error {
                    print("NWConnection Copper : \(error)")
                    
                    return
                }
                if let data = data, !data.isEmpty {
                    self.delegate?.port(didReceiveData: data)
                }
                recursive()
            }
        }
        recursive()
    }
    
    func writeData(data: Data) {
        netConnection.send(content: data, isComplete: true, completion: NWConnection.SendCompletion.idempotent)
    }
    
    weak var delegate: ReadableData?
    weak var connectionDelegate: ConnectionDeleagate?
}
#endif
