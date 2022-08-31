//
//  CopperHubManager.swift
//  
//
//  Created by ANTROPOV Evgeny on 16.02.2022.
//

#if os(macOS)
import Foundation
#if !FROM_COCOAPODS
import Proto
#endif


@available(macOS 12.0, *)
public class CopperHubManager: ObservableObject, DeviceManagerDelegate  {
    public enum ConnectionStatus {
        case none
        case connecting
        case connected
    }
    public static let shared = CopperHubManager()
    private var networkManager = NetworkDeviceManager()
    private var usbManager = USBDeviceManager()
    
    init() {
        networkManager.delegate = self
        usbManager.delegate = self
        usbManager.start()
        networkManager.start()
    }
    
    public var deviceList: [CopperDevice] {
        get {
            (networkManager.allDeviceList.map{$0 as CopperDevice} + usbManager.allDeviceList.map{$0 as CopperDevice})
                .filter({ $0.info != nil })
        }
    }
    public var proto: CopperProtocol? {
        didSet {
            objectWillChange.send()
        }
    }
    
    @Published
    public var status: ConnectionStatus = .none
    
    public var currentDevice: CopperDevice? {
        get {
            proto?.connectedPort
        }
        set {
            if let value = newValue {
                Task {
                    await MainActor.run {
                        self.status = .connecting
                    }
                    let proto = CopperProtocol(port: value)
                    do {
                        try await proto.sendWithResponse(type: MessageData.Connect.self, message: .with { request in
                            _ = 0
                        }, timeout: 2)
                        self.proto = proto
                        await MainActor.run {
                            self.status = .connected
                        }
                    } catch {
                        await MainActor.run {
                            self.status = .none
                        }
                    }
                }
            } else {
                self.status = .none
                self.proto = nil
            }
        }
    }
    
    
    public func didUpdateInfo(for device: CopperDevice) {
        Task.detached {
            await MainActor.run {
                self.objectWillChange.send()
            }
        }
    }
}

protocol DeviceManagerDelegate: AnyObject {
    var currentDevice: CopperDevice? { get set }
    func didUpdateInfo(for device: CopperDevice)
}

#endif
