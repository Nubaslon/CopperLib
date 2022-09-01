//
//  LoggerPlugin.swift
//  
//
//  Created by ANTROPOV Evgeny on 16.02.2022.
//

import Foundation
@_exported import Logging
#if !FROM_COCOAPODS
import CopperPlugin
import CopperEncryptor
#endif
import Combine

@available(iOS 13.0, *)
public class LoggerPlugin: Plugin {
    let encryptionKey: EncryptedKey
    let logName: String
    var encryptors = [String: ChaCha20]()
    var liveLogEnabled = false
    public var messageSendSubject: PassthroughSubject<SwiftProtobuf.Message, Never> = PassthroughSubject()
    let logsSubject = PassthroughSubject<SwiftProtobuf.Message, Never>()
    var cancelables = Set<AnyCancellable>()
    
    public init(encryptionKey: EncryptedKey, printClosure: ((LogRecord) -> ())? = nil) {
        self.encryptionKey = encryptionKey
        let dateFormatter = MicrosecondPrecisionDateFormatter()
        logName = dateFormatter.string(from: Date())
        logsSubject
            .filter { _ in self.liveLogEnabled }
            .eraseToAnyPublisher()
            .subscribe(messageSendSubject)
            .store(in: &cancelables)
        LoggingSystem.bootstrap({ CopperLogHandler(label: $0, encryptor: self.encryptor(for: $0), sendSubject: self.logsSubject, globalLogsDirectory: self.globalLogsDirectory(), logName: self.logName, printClosure: printClosure) })
    }

    func encryptor(for label: String) -> ChaCha20 {
        if let encryptor = encryptors[label] {
            return encryptor
        } else {
            let key = KeyGenerator.key(for: logName, passPhrase: encryptionKey)
            let encryptor = ChaCha20(key: key.key, iv: key.iv)
            encryptors[label] = encryptor
            return encryptor
        }
    }
    
    public func handle(message: InboundData) async throws -> SwiftProtobuf.Message? {
        switch(message.data){
        case is MessageData.LogsLabels.Request:
            let logsLabels = try await getAllLogsLabels()
            return MessageData.LogsLabels.Response.with{ message in
                message.labels = logsLabels
            }
        case let request as MessageData.LogsList.Request:
            let logNames = try await getAllLogsNames(for: request.label).map({ name in
                MessageData.LogsList.Response.LogName.with { message in
                    message.name = name
                    message.isActive = name == logName
                }
            })
            return MessageData.LogsList.Response.with{ message in
                message.logNames = logNames
            }
        case let request as MessageData.Logs.Request:
            let logs = try await readLogs(label: request.label, name: request.name)
            return MessageData.Logs.Response.with{ message in
                message.logs = logs
            }
        case let request as MessageData.LiveLog.Request:
            liveLogEnabled = request.enable
        default:
            ()
        }
        return nil
    }
    
    func getAllLogsLabels() async throws -> [String] {
        let manager = FileManager.default
        return try manager.contentsOfDirectory(atPath: globalLogsDirectory().path)
    }
    
    func getAllLogsNames(for label: String) async throws -> [String] {
        let manager = FileManager.default
        return try manager.contentsOfDirectory(atPath: globalLogsDirectory().appendingPathComponent(label, isDirectory: true).path).map({ $0.replacingOccurrences(of: ".log", with: "") })
    }
    
    func readLogs(label: String, name: String) async throws -> [String] {
        let filePath = globalLogsDirectory().appendingPathComponent(label, isDirectory: true).appendingPathComponent(name + ".log", isDirectory: false)
        let key = KeyGenerator.key(for: name, passPhrase: encryptionKey)
        let decryptor = ChaCha20(key: key.key, iv: key.iv)
        let decrypted = try decryptor.decrypt(data: .init(contentsOf: filePath))
        var resultStrings = [String]()
        for splitedBytes in decrypted.asData.split(separator: 0) {
            guard let string = String(data: splitedBytes.decodeCOBS() ?? splitedBytes, encoding: .utf8) else {
                print("Failed decode logs")
                continue
            }
            resultStrings.append(string)
        }
        return resultStrings
    }
    
    func globalLogsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let homeDirectory = paths[0]
        let logsDirectory = homeDirectory.appendingPathComponent("CopperLogger", isDirectory: true)
        if !FileManager.default.fileExists(atPath: logsDirectory.path) {
            try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        return logsDirectory
    }
    
    public func observation() -> AsyncStream<SwiftProtobuf.Message>? {
        return nil
    }
}

@available(iOS 13.0, *)
class CopperLogHandler: LogHandler {
    var logLabel: String
    var logName: String
    public var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .info
    var logFilePath: URL = URL(fileURLWithPath: "")
    var writeStream: OutputStream = OutputStream(toMemory: ())
    let encryptor: ChaCha20
    let sendSubject: PassthroughSubject<SwiftProtobuf.Message, Never>
    let globalLogsDirectory: URL
    var printClosure: ((LogRecord) -> ())? = nil
    
    init(label: String, encryptor: ChaCha20, sendSubject: PassthroughSubject<SwiftProtobuf.Message, Never>, globalLogsDirectory: URL, logName: String, printClosure: ((LogRecord) -> ())?) {
        self.globalLogsDirectory = globalLogsDirectory
        self.sendSubject = sendSubject
        self.encryptor = encryptor
        self.printClosure = printClosure
        self.logName = logName
        logLabel = label
        logFilePath = logsDirectory().appendingPathComponent("\(logName).log", isDirectory: false)
        writeStream = OutputStream(toFileAtPath: logFilePath.path, append: true) ?? OutputStream(toMemory: ())
        writeStream.open()
    }
    
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[metadataKey]
        }
        set {
            self.metadata[metadataKey] = newValue
        }
    }
    
    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {
        let logRecord = LogRecord(id: UUID(), time: Date(), label: logLabel, level: level, message: message.description, metadata: metadata?.encodable(), file: file, function: function, line: line, isMain: Thread.isMainThread)
        printClosure?(logRecord)
        let jsonEncoder = JSONEncoder()
        guard let data = try? jsonEncoder.encode(logRecord) else {
            assertionFailure("Can't encode log record")
            return
        }
    
        sendSubject.send(MessageData.LiveLog.Response.with({ message in
            message.label = logLabel
            message.name = logName
            message.log = String(data: data, encoding: .utf8) ?? "Error encode"
        }))
        let encryptedData = try! encryptor.encrypt(data: .init(data: data.encodeCOBS() + [0]))
        _ = encryptedData.asData.withUnsafeBytes { writeStream.write($0, maxLength: encryptedData.count) }
    }
            
   
    
    func logsDirectory() -> URL {
        let logsDirectory = globalLogsDirectory.appendingPathComponent(logLabel, isDirectory: true)
        if !FileManager.default.fileExists(atPath: logsDirectory.path) {
            try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        return logsDirectory
    }
    
}

@available(iOS 13.0, *)
public struct LogRecord: Codable {
    public typealias Metadata = [String: EncodableMetadataValue]
    public enum EncodableMetadataValue: Codable {
        /// A metadata value which is a `String`.
        ///
        /// Because `MetadataValue` implements `ExpressibleByStringInterpolation`, and `ExpressibleByStringLiteral`,
        /// you don't need to type `.string(someType.description)` you can use the string interpolation `"\(someType)"`.
        case string(String)

        /// A metadata value which is a dictionary from `String` to `Logger.MetadataValue`.
        ///
        /// Because `MetadataValue` implements `ExpressibleByDictionaryLiteral`, you don't need to type
        /// `.dictionary(["foo": .string("bar \(buz)")])`, you can just use the more natural `["foo": "bar \(buz)"]`.
        case dictionary(Metadata)

        /// A metadata value which is an array of `Logger.MetadataValue`s.
        ///
        /// Because `MetadataValue` implements `ExpressibleByArrayLiteral`, you don't need to type
        /// `.array([.string("foo"), .string("bar \(buz)")])`, you can just use the more natural `["foo", "bar \(buz)"]`.
        case array([Metadata.Value])
        
        public var stringData: String {
            switch(self) {
            case let .string(string):
                return string
            case let .array(array):
                return array.map({$0.stringData}).joined(separator: "\n")
            case let .dictionary(dictionary):
                return dictionary.map { "\"\($0.key)\" = \"\($0.value.stringData)\"" }.joined(separator: "\n")
            }
        }
    }
    public let id: UUID
    public let time: Date
    public let label: String
    public let level: Logger.Level
    public let message: String
    public let metadata: Metadata?
    public let file: String
    public let function: String
    public let line: UInt
    public let isMain: Bool
    
    public var prettyString: String {
        let dateFormatter = MicrosecondPrecisionDateFormatter()
        if let metadata = metadata, !prettify(metadata).isEmpty  {
            return "\(dateFormatter.string(from: Date())) \(label):\(level) \(message)\n\(prettify(metadata))\n"
        } else {
            return "\(dateFormatter.string(from: Date())) \(label):\(level) \(message)"
        }
    }
    
    private func prettify(_ metadata: Metadata) -> String {
        return !metadata.isEmpty
            ? metadata.lazy.sorted(by: { $0.key < $1.key }).map { "\($0)=\($1)" }.joined(separator: "\n")
            : ""
    }
}

@available(iOS 13.0, *)
extension Logger.MetadataValue {
    func encodable() -> LogRecord.EncodableMetadataValue {
        switch(self){
        case let .string(string):
            return .string(string)
        case let .stringConvertible(convertiable):
            return .string(convertiable.description)
        case let .dictionary(dictionary):
            return .dictionary(dictionary.mapValues({$0.encodable()}))
        case let .array(array):
            return .array(array.map({$0.encodable()}))
        }
    }
}

@available(iOS 13.0, *)
extension Logger.Metadata {
    func encodable() -> LogRecord.Metadata {
        return self.mapValues({ $0.encodable() })
    }
}

@available(iOS 13.0, *)
@objc
public class CPPLogger: NSObject {
    public static var objcLogger = Logger(label: "copper.objc")
    
    @objc
    static public func logError(message: String, metadata: NSDictionary? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        objcLogger.log(level: .error, .init(stringLiteral: message), metadata: metadata?.metadata, source: nil, file: file, function: function, line: line)
    }
    
    @objc
    static public func logCritical(message: String, metadata: NSDictionary? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        objcLogger.log(level: .critical, .init(stringLiteral: message), metadata: metadata?.metadata, source: nil, file: file, function: function, line: line)
    }
    
    @objc
    static public func logDebug(message: String, metadata: NSDictionary? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        objcLogger.log(level: .debug, .init(stringLiteral: message), metadata: metadata?.metadata, source: nil, file: file, function: function, line: line)
    }
    
    @objc
    static public func logInfo(message: String, metadata: NSDictionary? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        objcLogger.log(level: .info, .init(stringLiteral: message), metadata: metadata?.metadata, source: nil, file: file, function: function, line: line)
    }
    
    @objc
    static public func logNotice(message: String, metadata: NSDictionary? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        objcLogger.log(level: .notice, .init(stringLiteral: message), metadata: metadata?.metadata, source: nil, file: file, function: function, line: line)
    }
    
    @objc
    static public func logTrace(message: String, metadata: NSDictionary? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        objcLogger.log(level: .trace, .init(stringLiteral: message), metadata: metadata?.metadata, source: nil, file: file, function: function, line: line)
    }
    
    @objc
    static public func logWarning(message: String, metadata: NSDictionary? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        objcLogger.log(level: .warning, .init(stringLiteral: message), metadata: metadata?.metadata, source: nil, file: file, function: function, line: line)
    }
}

@available(iOS 13.0, *)
extension NSDictionary {
    var metadata: Logger.Metadata {
        return self.reduce(Logger.Metadata()) {  partialResult, value in
            var newResult = partialResult
            newResult["\(value.key)"] = Logger.MetadataValue.init(stringLiteral: "\(value.value)")
            return newResult
        }
    }
}
