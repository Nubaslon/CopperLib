//
//  ChaCha20.swift
//  
//
//  Created by ANTROPOV Evgeny on 16.02.2022.
//

import Foundation
#if !FROM_COCOAPODS
import CopperEncryptorChaCha20
#endif

public final class ChaCha20 {

    public static let nonceSize = 12
    private let blockSize = 64
    private var key: [UInt8]
    private var iv: [UInt8]
    private var counter: UInt32
    private var block: [UInt8]
    private var posInBlock: Int
    
    public init(key: [UInt8], iv: [UInt8]) {
        precondition(key.count == 32, "ChaCha20 expects 32-byte key")
        precondition(iv.count == ChaCha20.nonceSize, "ChaCha20 expects \(ChaCha20.nonceSize)-byte IV")
        
        self.key = key
        self.iv = iv
        
        block = [UInt8](repeating: 0, count: blockSize)
        counter = 0
        posInBlock = blockSize
    }
    deinit {
        erase()
    }
    
    public func erase() {
        key = []
        iv = []
        block = [UInt8](repeating: 0, count: blockSize)
        counter = 0
    }
    
    func xor(bytes: inout [UInt8]) throws {
        key.withDecryptedBytes { keyBytes in
            iv.withDecryptedBytes { ivBytes in
                for i in 0..<bytes.count {
                    if posInBlock == blockSize {
                        var counterBytes = counter.bytes
                        chacha20_make_block(keyBytes, ivBytes, &counterBytes, &block)
                        counter += 1
                        posInBlock = 0
                    }
                    bytes[i] ^= block[posInBlock]
                    posInBlock += 1
                }
            }
        }
    }
    
    public func encrypt(data: ByteArray) throws -> ByteArray {
        var outBytes = data.bytesCopy()
        try xor(bytes: &outBytes)
        return ByteArray(bytes: outBytes)
    }
    
    public func decrypt(data: ByteArray) throws -> ByteArray {
        return try encrypt(data: data)
    }
}

extension Array where Element == UInt8 {
    public func withDecryptedBytes<T>(_ handler: ([UInt8]) throws -> T) rethrows -> T {
        if self.isEmpty {
            return try handler([])
        }
        
        assert(!self.allSatisfy { $0 == 0 }, "All bytes are zero. Possibly erased too early?")
        
        var bytesCopy = self.clone()
        defer {
            bytesCopy.erase()
        }
        return try handler(bytesCopy)
    }
}

public extension Array where Element == UInt8 {
    func clone() -> Array<UInt8> {
        return self.withUnsafeBufferPointer {
            [UInt8].init($0)
        }
    }
}

public extension Array where Element == UInt8 {
    mutating func erase() {
        withUnsafeBufferPointer {
            let mutatablePointer = UnsafeMutableRawPointer(mutating: $0.baseAddress!)
            memset_s(mutatablePointer, $0.count, 0, $0.count)
        }
        removeAll()
    }
}
