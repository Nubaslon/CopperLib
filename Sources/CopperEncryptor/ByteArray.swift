//
//  ByteArray.swift
//  
//
//  Created by ANTROPOV Evgeny on 16.02.2022.
//

import Foundation

public class ByteArray: Codable, CustomDebugStringConvertible {

    public class InputStream {
        fileprivate let base: Foundation.InputStream
        var hasBytesAvailable: Bool { return base.hasBytesAvailable }
        
        fileprivate init(data: Data) {
            base = Foundation.InputStream(data: data)
        }
        
        func open() {
            base.open()
        }
        func close() {
            base.close()
        }
        
        func read(count: Int) -> ByteArray? {
            var out = [UInt8].init(repeating: 0, count: count)

            var bytesRead = 0
            while bytesRead < count {
                let remainingCount = count - bytesRead
                let n = out.withUnsafeMutableBufferPointer {
                    (bytes: inout UnsafeMutableBufferPointer<UInt8>) in
                    return base.read(bytes.baseAddress! + bytesRead, maxLength: remainingCount)
                }
                guard n > 0 else {
                    print("Stream reading problem")
                    return nil
                }
                bytesRead += n
            }
            return ByteArray(bytes: out)
        }
        
        @discardableResult
        func skip(count: Int) -> Int {
            let dataRead = read(count: count)
            return dataRead?.count ?? 0
        }
        func readUInt8() -> UInt8? {
            let data = self.read(count: MemoryLayout<UInt8>.size)
            return UInt8(data: data)
        }
        func readUInt16() -> UInt16? {
            let data = self.read(count: MemoryLayout<UInt16>.size)
            return UInt16(data: data)
        }
        func readUInt32() -> UInt32? {
            let data = self.read(count: MemoryLayout<UInt32>.size)
            return UInt32(data: data)
        }
        func readUInt64() -> UInt64? {
            let data = self.read(count: MemoryLayout<UInt64>.size)
            return UInt64(data: data)
        }
        func readInt8() -> Int8? {
            let data = self.read(count: MemoryLayout<Int8>.size)
            return Int8(data: data)
        }
        func readInt16() -> Int16? {
            let data = self.read(count: MemoryLayout<Int16>.size)
            return Int16(data: data)
        }
        func readInt32() -> Int32? {
            let data = self.read(count: MemoryLayout<Int32>.size)
            return Int32(data: data)
        }
        func readInt64() -> Int64? {
            let data = self.read(count: MemoryLayout<Int64>.size)
            return Int64(data: data)
        }
    }
    public class OutputStream {
        private let base: Foundation.OutputStream
        fileprivate init() {
            base = Foundation.OutputStream(toMemory: ())
        }
        public func open() {
            base.open()
        }
        public func close() {
            base.close()
        }
        var data: ByteArray? {
            if let data = base.property(forKey: .dataWrittenToMemoryStreamKey) as? Data {
                return ByteArray(data: data)
            } else {
                return nil
            }
        }

        @discardableResult
        func write<T: FixedWidthInteger>(value: T) -> Int {
            return write(data: value.data)
        }
        @discardableResult
        func write(data: ByteArray) -> Int {
            guard data.count > 0 else { return 0 }
            
            let writtenCount = data.withBytes { bytes in
                return base.write(bytes, maxLength: bytes.count)
            }
            assert(writtenCount == data.count, "Written \(writtenCount) bytes instead of \(data.count) requested")
            return writtenCount
        }
    }
    
    private enum CodingKeys: CodingKey {
        case bytes
    }
    
    fileprivate var bytes: [UInt8]
    fileprivate var sha256cache: ByteArray?
    fileprivate var sha512cache: ByteArray?

    public var isEmpty: Bool { return bytes.isEmpty }
    public var count: Int { return bytes.count }
    
    
    public var asData: Data { return Data(self.bytes) }
    
    subscript (index: Int) -> UInt8 {
        get { return bytes[index] }
        set { bytes[index] = newValue }
    }
    subscript (range: CountableRange<Int>) -> ByteArray {
        return ByteArray(bytes: self.bytes[range])
    }

    public var debugDescription: String {
        return asHexString
    }
    
    public init() {
        bytes = []
    }
    public init(data: Data) {
        self.bytes = Array(data)
    }
    public init(bytes: [UInt8]) {
        self.bytes = [UInt8](bytes)
    }
    public init(bytes: ArraySlice<UInt8>) {
        self.bytes = [UInt8](bytes)
    }
    
    convenience public init(count: Int) {
        self.init(bytes: [UInt8](repeating: 0, count: count))
    }
    convenience public init(capacity: Int) {
        self.init()
        bytes.reserveCapacity(capacity)
    }
    convenience public init(contentsOf url: URL, options: Data.ReadingOptions = []) throws {
        let data = try Data(contentsOf: url, options: options)
        self.init(data: data)
    }
    convenience public init(utf8String: String) {
        self.init(data: utf8String.data(using: .utf8)!)
    }
    convenience public init?(base64Encoded: String?) {
        if let base64Encoded = base64Encoded {
            guard let data = Data(base64Encoded: base64Encoded) else { return nil }
            self.init(data: data)
        } else {
            return nil
        }
    }
    
    convenience public init?<T: StringProtocol>(hexString string: T) {
        func decodeNibble(u: UInt16) -> UInt8? {
            switch(u) {
            case 0x30 ... 0x39:
                return UInt8(u - 0x30)
            case 0x41 ... 0x46:
                return UInt8(u - 0x41 + 10)
            case 0x61 ... 0x66:
                return UInt8(u - 0x61 + 10)
            default:
                return nil
            }
        }
        
        self.init()
        bytes.reserveCapacity(string.utf16.count/2)
        var even = true
        var byte: UInt8 = 0
        for c in string.utf16 {
            guard let val = decodeNibble(u: c) else { return nil }
            if even {
                byte = val << 4
            } else {
                byte += val
                bytes.append(byte)
            }
            even = !even
        }
        guard even else { return nil }
    }
    
    deinit {
        erase()
    }
    
    fileprivate func invalidateHashCache() {
        sha256cache = nil
        sha512cache = nil
    }
    
    public func clone() -> ByteArray {
        let bytesClone = self.bytes.clone()
        return ByteArray(bytes: bytesClone)
    }
    
    public func bytesCopy() -> [UInt8] {
        return bytes.clone()
    }
    
    public func erase() {
        bytes.erase()
        invalidateHashCache()
    }
    
    public var asHexString: String {
        let hexDigits = Array("0123456789abcdef".utf16)
        var chars: [unichar] = []
        chars.reserveCapacity(2 * count)
        for byte in self.bytes {
            chars.append(hexDigits[Int(byte / 16)])
            chars.append(hexDigits[Int(byte % 16)])
        }
        return String(utf16CodeUnits: chars, count: chars.count)
    }
    
    public func prefix(_ maxLength: Int) -> ByteArray {
        return ByteArray(bytes: self.bytes.prefix(maxLength))
    }
    public func prefix(upTo: Int) -> ByteArray {
        return ByteArray(bytes: self.bytes.prefix(upTo: upTo))
    }
    public func suffix(from: Int) -> ByteArray {
        return ByteArray(bytes: self.bytes.suffix(from: from))
    }
    
    public func trim(toCount newCount: Int) {
        if (newCount < 0) || (bytes.count <= newCount) { return }
        
        for i in newCount..<bytes.count {
            bytes[i] = 0
        }
        bytes.removeLast(bytes.count - newCount)
        invalidateHashCache()
    }
    
    public static func concat(_ arrays: ByteArray...) -> ByteArray {
        var totalSize = 0
        for arr in arrays {
            totalSize += arr.count
        }
        var buffer = [UInt8]()
        buffer.reserveCapacity(totalSize)
        for arr in arrays {
            buffer.append(contentsOf: arr.bytes)
        }
        return ByteArray(bytes: buffer)
    }
    
    public func append(_ value: UInt8) {
        bytes.append(value)
        invalidateHashCache()
    }
    public func append(bytes: Array<UInt8>) {
        self.bytes.append(contentsOf: bytes)
        invalidateHashCache()
    }
    public func append(_ another: ByteArray) {
        self.bytes.append(contentsOf: another.bytes)
        invalidateHashCache()
    }
    
    public func write(to url: URL, options: Data.WritingOptions) throws {
        try asData.write(to: url, options: options)
    }
    
    @discardableResult
    public func withBytes<TResult>(_ body: ([UInt8]) -> TResult) -> TResult {
        return body(bytes)
    }
    @discardableResult
    public func withMutableBytes<TResult>(_ body: (inout [UInt8]) -> TResult) -> TResult {
        return body(&bytes)
    }

    
    public func base64EncodedString() -> String {
        return Data(bytes).base64EncodedString()
    }
    
    public func toString(using encoding: String.Encoding = .utf8) -> String? {
        return String(bytes: self.bytes, encoding: encoding)
    }
    
    public func asInputStream() -> ByteArray.InputStream {
        return ByteArray.InputStream(data: Data(self.bytes))
    }
    public static func makeOutputStream() -> ByteArray.OutputStream {
        return ByteArray.OutputStream()
    }
    
    
    public func containsOnly(_ value: UInt8) -> Bool {
        for i in 0..<bytes.count {
            if bytes[i] != value {
                return false
            }
        }
        return true
    }
}

extension ByteArray: Equatable {
    public static func ==(lhs: ByteArray, rhs: ByteArray) -> Bool {
        return lhs.bytes == rhs.bytes
    }
}

extension ByteArray: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bytes)
    }
}



public func sizeof<T: FixedWidthInteger>(_ value: T) -> Int {
    return MemoryLayout.size(ofValue: value)
}

extension FixedWidthInteger {
    init?(data: ByteArray?) {
        guard let data = data else { return nil }
        guard data.count == MemoryLayout<Self>.size else { return nil }
        
        
        self = data.withBytes { bytes in
            return bytes.withUnsafeBytes{ ptr in
                return ptr.load(as: Self.self)
            }
        }
    }
    
    init?(_ value: String?) {
        guard let value = value else {
            return nil
        }
        self.init(value)
    }
    
    var data: ByteArray {
        return ByteArray(bytes: self.bytes)
    }
    
    var bytes: [UInt8] {
        return withUnsafeBytes(of: self) { Array($0) }
    }
    var asHexString: String {
        let size = MemoryLayout<Self>.size
        return String(format: "%0\(size*2)x", arguments: [self as! CVarArg])
    }
    var byteWidth: Int {
        return bitWidth / UInt8.bitWidth
    }
}
