//
//  File.swift
//  
//
//  Created by ANTROPOV Evgeny on 05.04.2022.
//

#if os(macOS)
import Foundation
import Network
#if !FROM_COCOAPODS
import Proto
#endif

class NetworkDeviceManager: NSObject, ObservableObject, DeviceInfoDelegate {
    weak var delegate: DeviceManagerDelegate?
    
    private var simulatorListner: NWListener
    private let netConnectionQueue = DispatchQueue.global(qos: .utility)
    var allDeviceList = [NetworkDeviceWrapper]()
    
    override init() {
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
        simulatorListner = try! NWListener(using: params, on: .init(rawValue: 13228)! )
        simulatorListner.service = NWListener.Service(name:"Copper Hub", type: "_cop._tcp.")
        super.init()
    }
    
    public func start() {
        simulatorListner.newConnectionHandler = {
            (newConnection) in
            newConnection.stateUpdateHandler = {
                [weak self] state in
                switch(state) {
                case .ready:
                    let connection = NetworkDeviceWrapper(nwConnection: newConnection)
                    connection.infoDelegate = self
                    connection.networkDeviceManager = self
                    self?.allDeviceList.append(connection)
                default:
                    ()
                }
            }
            newConnection.start( queue: self.netConnectionQueue )
        }
        simulatorListner.start(queue: self.netConnectionQueue)
    }
    
    func didUpdateInfo(for device: CopperDevice) {
        delegate?.didUpdateInfo(for: device)
    }
}

class NetworkDeviceWrapper: CopperDevice {
    var info: HelloMessage?
    weak var infoDelegate: DeviceInfoDelegate?
    weak var networkDeviceManager: NetworkDeviceManager?
    weak var delegate: ReadableData?
    let nwConnection: NWConnection
    
    init(nwConnection: NWConnection) {
        self.nwConnection = nwConnection
        if nwConnection.state == .ready {
            self.readData()
        }
        self.nwConnection.stateUpdateHandler = {[weak self] newState in
            guard let self = self else { return }
            switch(newState) {
            case .ready:
                self.readData()
            case .cancelled, .failed(_):
                self.networkDeviceManager?.allDeviceList.removeAll(where: { $0 == self })
                self.delegate?.didDisconnect()
            default:
                ()
            }
        }
    }
    
    func readData() {
        var recursive: () -> () = {}
        recursive = {
            self.nwConnection.receive(minimumIncompleteLength: 1, maximumLength: 65000) { data, contentContext, isComplete, error in
                if let error = error {
                    print("NWConnection Copper : \(error)")
                    return
                }
                if let data = data, !data.isEmpty {
                    if let helloMessage = try? HelloMessage(contiguousBytes: data), self.info == nil  {
                        self.info = helloMessage
                        self.infoDelegate?.didUpdateInfo(for: self)
                    } else {
                        self.delegate?.port(didReceiveData: data)
                    }
                }
                recursive()
            }
        }
        recursive()
    }
    
    func writeData(data: Data) {
        nwConnection.send(content: data, isComplete: true, completion: NWConnection.SendCompletion.idempotent)
    }
    
    
}

#endif
