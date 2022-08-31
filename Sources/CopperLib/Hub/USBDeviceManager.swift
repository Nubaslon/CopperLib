//
//  File.swift
//  
//
//  Created by ANTROPOV Evgeny on 05.04.2022.
//

#if os(macOS)
import Foundation
import Peertalk
#if !FROM_COCOAPODS
import Proto
#endif

class USBDeviceManager: NSObject, PTChannelDelegate {
    private var listningChannel: PTChannel?
    weak var delegate: DeviceManagerDelegate?
    let notificationCenter = NotificationCenter.default
    var allDeviceList = Array<USBDeviceWrapper>()
    
    override init() {
        super.init()
        
    }
        
    public func start() {
        notificationCenter.addObserver(forName: NSNotification.Name.deviceDidAttach, object: PTUSBHub.shared(), queue: nil) {[weak self] notification in
            guard let deviceID = notification.userInfo?[PTUSBHubNotificationKey.deviceID] as? NSNumber else {
                return
            }
            let listningChannel = PTChannel(protocol: nil, delegate: self)
            listningChannel.userInfo = deviceID
            listningChannel.connect(to: 13129, over: PTUSBHub.shared(), deviceID: deviceID, callback: { error in
                self?.device(didConnect: listningChannel)
            })
        }
        notificationCenter.addObserver(forName: NSNotification.Name.deviceDidDetach, object: PTUSBHub.shared(), queue: nil) {[weak self] notification in
            guard let deviceID = notification.userInfo?[PTUSBHubNotificationKey.deviceID] as? NSNumber else {
                return
            }
            if deviceID == (self?.listningChannel?.userInfo as? NSNumber) {
                guard let currentChannel = self?.listningChannel else {
                    return
                }
                self?.device(didDisconnect: currentChannel)
                currentChannel.close()
            }
        }
    }
        
    public func device(didDisconnect device: PTChannel) {
        allDeviceList.removeAll(where: { $0.device.isEqual(to: device) })
        wrapperFor(device: device).deviceDidDisconnect()
        if delegate?.currentDevice == wrapperFor(device: device) {
            delegate?.currentDevice = nil
        }
    }
    
    
    public func device(didConnect device: PTChannel) {
        listningChannel = device
        wrapperFor(device: device).deviceDidConnect()
    }
    
    public func device(didFailToConnect device: PTChannel) {
        allDeviceList.removeAll(where: { $0.device.isEqual(to: device) })
        wrapperFor(device: device).deviceDidFailToConnect()
        if delegate?.currentDevice == wrapperFor(device: device) {
            delegate?.currentDevice = nil
        }
    }
    
    func channelDidEnd(_ channel: PTChannel, error: Error?) {
        wrapperFor(device: channel).deviceDidDisconnect()
        if delegate?.currentDevice == wrapperFor(device: channel) {
            delegate?.currentDevice = nil
        }
    }
    
    func channel(_ channel: PTChannel, shouldAcceptFrame type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
        return true
    }
    
    func channel(_ channel: PTChannel, didRecieveFrame type: UInt32, tag: UInt32, payload: Data?) {
        guard let data = payload else { return }
        if let helloMessage = try? HelloMessage(contiguousBytes: data) {
            wrapperFor(device: channel).info = helloMessage
            delegate?.didUpdateInfo(for: wrapperFor(device: channel))
        } else {
            wrapperFor(device: channel).receiveData(data: data)
        }
    }
    
    
    private func wrapperFor(device: PTChannel) -> USBDeviceWrapper {
        let wraper = allDeviceList
            .compactMap({$0})
            .first { wrapper in
                wrapper.device.isEqual(device)
            }
        if let wrapper = wraper {
            return wrapper
        } else {
            let newWrapper = USBDeviceWrapper(device: device)
            allDeviceList.append(newWrapper)
            return newWrapper
        }
    }
}

public class USBDeviceWrapper: CopperDevice, Equatable {
    public static func == (lhs: USBDeviceWrapper, rhs: USBDeviceWrapper) -> Bool {
        return lhs.device.isEqual(to: rhs.device)
    }
    
    weak public var delegate: ReadableData?
    weak var connectionDelegate: ConnectionDeleagate?
    let device: PTChannel
    public var info: HelloMessage?
    weak public var infoDelegate: DeviceInfoDelegate?
    
    init(device: PTChannel) {
        self.device = device
    }
    
    func deviceDidDisconnect() {
        delegate?.didDisconnect()
        print("didDisconnect")
        self.info = nil
    }
    
    func deviceDidConnect() {
        print("didConnect")
    }
    
    func deviceDidFailToConnect() {
        delegate?.didDisconnect()
        print("didFailToConnect")
    }
    
    func receiveData(data: Data) {
        self.delegate?.port(didReceiveData: data)
    }
    
    public func writeData(data: Data) {
        device.sendFrame(type: 1, tag: 0, payload: data)
    }
}

public func == (lhs: CopperDevice?, rhs: USBDeviceWrapper) -> Bool {
    if let lhsDevice = lhs as? USBDeviceWrapper {
        return lhsDevice.device.isEqual(rhs.device)
    }
    return false
}

extension USBDeviceWrapper: Identifiable {
    public var id: String { return info?.deviceUuid ?? "none" }
}
#endif
