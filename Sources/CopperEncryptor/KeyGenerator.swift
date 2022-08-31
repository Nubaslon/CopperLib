//
//  KeyGenerator.swift
//  
//
//  Created by ANTROPOV Evgeny on 17.02.2022.
//

import Foundation
import CommonCrypto
#if !os(macOS)
import UIKit
#endif

public typealias EncryptedKey = String

public class KeyGenerator {
    public class func key(for name: String, passPhrase: String) -> (key: [UInt8], iv: [UInt8]) {
#if !os(macOS)
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "None"
#else
        let deviceId = "OSX"
#endif
        let digest = sha512("\(name)\(passPhrase)\(deviceId)")
        var keyAndIVArray = [UInt8].init(repeating: 0, count: Int(44))
        var currentOffset = 42
        for i in 1 ... 32+12 {
            let indexToSave = digest.readCycled(from: currentOffset, offset: 0)
            keyAndIVArray[i - 1] = digest.readCycled(from: currentOffset, offset: Int(indexToSave))
            currentOffset = currentOffset + Int(digest.readCycled(from: currentOffset, offset: Int(indexToSave) + i))
        }
        let luckyIndex = [3,7,9,12,14,17,21,24,26,28,33,42]
        var key = [UInt8]()
        var iv = [UInt8]()
        for (index, value) in keyAndIVArray.enumerated() {
            if luckyIndex.contains(index) {
                iv.append(value)
            } else {
                key.append(value)
            }
        }
        return (
            key: key,
            iv: iv
        )
    }
    
    class func sha512(_ string: String) -> [UInt8] {
        var digest = [UInt8].init(repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
        let data = string.data(using: String.Encoding.utf8)!
        _ = data.withUnsafeBytes({CC_SHA512($0, CC_LONG(data.count), &digest)})
        
        return digest
    }
}

extension Array where Self.Element == UInt8 {
    func readCycled(from: Int, offset: Int) -> UInt8 {
        let returnValue: UInt8?
        let index = (from + offset) % count
        returnValue = self[index]
        guard let returnValue = returnValue else {
            fatalError("Array must not be empty")
        }
        return returnValue
    }
}
