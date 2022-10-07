//
//  NetworkPlugin.swift
//  
//
//  Created by ANTROPOV Evgeny on 13.03.2022.
//

import Foundation

@_exported import Logging
#if !FROM_COCOAPODS
import CopperPlugin
import CopperEncryptor
#endif
import Combine

@available(iOS 13.0, *)
var globalNetworkHandler: NetworkHandler?

@available(iOS 13.0, *)
public class NetworkPlugin: Plugin {
    let encryptionKey: EncryptedKey
    let logName: String
    var encryptors = [String: ChaCha20]()
    
    public var messageSendSubject: PassthroughSubject<SwiftProtobuf.Message, Never> = PassthroughSubject()
    let logsSubject = PassthroughSubject<SwiftProtobuf.Message, Never>()
    var cancelables = Set<AnyCancellable>()
    var liveLogEnabled = false
    var interceptorEnabled = false
    
    public init(encryptionKey: EncryptedKey) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH:mm:ss"
        logName = dateFormatter.string(from: Date())
        self.encryptionKey = encryptionKey
        logsSubject
            .filter { _ in self.liveLogEnabled }
            .eraseToAnyPublisher()
            .subscribe(messageSendSubject)
            .store(in: &cancelables)
        
        let key = KeyGenerator.key(for: logName, passPhrase: encryptionKey)
        let logFilePath = globalLogsDirectory().appendingPathComponent("\(logName).log", isDirectory: false)
        globalNetworkHandler = NetworkHandler(encryptor: ChaCha20(key: key.key, iv: key.iv), sendSubject: self.logsSubject, logName: logName, logFilePath: logFilePath, isNetworkInterceptEnabled: { [weak self] in return self?.interceptorEnabled ?? false })
        DispatchQueue.global(qos: .userInitiated).async {
            NetworkRequestInterceptor.startRecording()
        }        
    }
    
    func globalLogsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let homeDirectory = paths[0]
        let logsDirectory = homeDirectory.appendingPathComponent("CopperNetwork", isDirectory: true)
        if !FileManager.default.fileExists(atPath: logsDirectory.path) {
            try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        return logsDirectory
    }
    
    public func handle(message: InboundData) async throws -> Message? {
        switch(message.data){
        case is MessageData.NetworkLabels.Request:
            let logsLabels = try await getAllNetworkLabels()
            return MessageData.NetworkLabels.Response.with{ message in
                message.labels = logsLabels.map { value in
                    MessageData.NetworkLabels.Response.NetworkLabel.with { label in
                        label.name = value
                        label.isActive = value == self.logName
                    }
                }
            }
        case let request as MessageData.NetworkRecords.Request:
            let logs = try await readRecords(label: request.label)
            return MessageData.NetworkRecords.Response.with{ message in
                message.records = logs
            }
        case let request as MessageData.NetworkLiveRecord.Request:
            liveLogEnabled = request.enable
        case let request as MessageData.NetworkIntecept.Request:
            interceptorEnabled = request.enable
        case let response as MessageData.NetworkInteceptRecord.Response:
            let jsonDecoder = JSONDecoder()
            let responseObject = try jsonDecoder.decode(InterceptorResponse.self, from: response.responseData)
            globalNetworkHandler?.handleResponseOverInterceptor(id: response.id.uuid, response: responseObject)
        default:
            ()
        }
        return nil
    }
    
    func getAllNetworkLabels() async throws -> [String] {
        let manager = FileManager.default
        return try manager.contentsOfDirectory(atPath: globalLogsDirectory().path).map({$0.replacingOccurrences(of: ".log", with: "")})
    }
    
    func readRecords(label: String) async throws -> [String] {
        let filePath = globalLogsDirectory().appendingPathComponent(label + ".log", isDirectory: false)
        let key = KeyGenerator.key(for: label, passPhrase: encryptionKey)
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
}

@available(iOS 13.0, *)
class NetworkHandler {
    let isNetworkInterceptEnabled: () -> Bool
    
    private let encryptor: ChaCha20
    private let writeStream: OutputStream
    private let logName: String
    private let queue = DispatchQueue(label: "com.copper.networkWriter")
    private let interceptorQueue = DispatchQueue(label: "com.copper.interceptorQueue")
    private let sendSubject: PassthroughSubject<SwiftProtobuf.Message, Never>
    private var interceptorWaiter = [UUID: (URLResponse?, Data?, Error?) -> ()]()
    
    init(encryptor: ChaCha20, sendSubject: PassthroughSubject<SwiftProtobuf.Message, Never>, logName: String, logFilePath: URL, isNetworkInterceptEnabled: @escaping () -> Bool) {
        self.isNetworkInterceptEnabled = isNetworkInterceptEnabled
        self.sendSubject = sendSubject
        self.logName = logName
        self.encryptor = encryptor
        writeStream = OutputStream(toFileAtPath: logFilePath.path, append: true) ?? OutputStream(toMemory: ())
        writeStream.open()
    }
    
    func saveRequest(id: UUID, urlRequest: URLRequest) {
        let allHeaders = urlRequest.allHTTPHeaderFields?.reduce([NetworkRecord.HeaderValue]()) { partialResult, value in
            var newResult = partialResult
            newResult.append(NetworkRecord.HeaderValue(key: value.key, value: value.value))
            return newResult
        } ?? []
        let body: Data
        if let httpBody = urlRequest.httpBody {
            body = httpBody
        } else if let stream = urlRequest.httpBodyStream {
            var data = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
            stream.open()
            while stream.hasBytesAvailable {
                let length = stream.read(buffer, maxLength: 1024)
                if length == 0 {
                    break
                } else {
                    data.append(buffer, count: length)
                }
            }
            stream.close()
            buffer.deallocate()
            body = data
        } else {
            body = Data()
        }
        let logRecord = NetworkRecord(id: id, data: .request(.init(date: Date(), method: urlRequest.httpMethod ?? "UNKNOWN", url: urlRequest.url ?? URL(fileURLWithPath: ""), body: body, headers: allHeaders, cachePolicy: urlRequest.cachePolicy.rawValue)))

        let jsonEncoder = JSONEncoder()
        guard let data = try? jsonEncoder.encode(logRecord) else {
            assertionFailure("Can't encode log record")
            return
        }
        writeData(data: data)
    }
    
    func saveResponse(id: UUID, urlResponse: URLResponse?, data: Data?, error: Error?) {
        if let error = error {
            let logRecord = NetworkRecord(id: id, data: .error(.init(date: Date(), localizedError: "\(error)")))
            let jsonEncoder = JSONEncoder()
            guard let data = try? jsonEncoder.encode(logRecord) else {
                assertionFailure("Can't encode log record")
                return
            }
            writeData(data: data)
        }
        else if let response = urlResponse as? HTTPURLResponse, let data = data {
            let allHeaders = response.allHeaderFields.reduce([NetworkRecord.HeaderValue]()) { partialResult, value in
                var newResult = partialResult
                newResult.append(NetworkRecord.HeaderValue(key: (value.key as? String) ?? "\(value.key)", value: (value.value as? String) ?? "\(value.value)"))
                return newResult
            }
            let logRecord = NetworkRecord(id: id, data: .response(.init(date: Date(), code: response.statusCode, body: data, headers: allHeaders)))
            let jsonEncoder = JSONEncoder()
            guard let data = try? jsonEncoder.encode(logRecord) else {
                assertionFailure("Can't encode log record")
                return
            }
            writeData(data: data)
        } else {
            let logRecord = NetworkRecord(id: id, data: .error(.init(date: Date(), localizedError: "No response")))
            let jsonEncoder = JSONEncoder()
            guard let data = try? jsonEncoder.encode(logRecord) else {
                assertionFailure("Can't encode log record")
                return
            }
            writeData(data: data)
        }
    }
    
    func writeData(data: Data) {
        sendSubject.send(MessageData.NetworkLiveRecord.Response.with({ message in
            message.label = logName
            message.record = String(data: data, encoding: .utf8) ?? "Error encode"
        }))
        queue.async {[weak self] in
            guard let self = self else { return }
            synchronized(self.writeStream) {
                let encryptedData = try! self.encryptor.encrypt(data: .init(data: data.encodeCOBS() + [0]))
                _ = encryptedData.asData.withUnsafeBytes { self.writeStream.write($0, maxLength: encryptedData.count) }
            }
        }
    }
     
    func handleResponseOverInterceptor(id: UUID, response: InterceptorResponse) {
        let urlResponse = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(response.nsUrlResponse ?? Data()) as? URLResponse
        let error = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(response.nsError ?? Data()) as? NSError
        interceptorQueue.async {[weak self] in
            self?.interceptorWaiter[id]?(urlResponse, response.body, error as Error?)
            self?.interceptorWaiter[id] = nil
        }
    }
    
    func requestOverInterceptor(id: UUID, request: URLRequest, response: @escaping (URLResponse?, Data?, Error?) -> ()) {
        guard let keyArchiver = try? NSKeyedArchiver.archivedData(withRootObject: request, requiringSecureCoding: false) else {
            fatalError("Can't archive URLRequest")
        }
        let request = InterceptorRequest(nsUrlRequest: keyArchiver)
        let jsonEncoder = JSONEncoder()
        guard let data = try? jsonEncoder.encode(request) else {
            assertionFailure("Can't encode log record")
            return
        }
        interceptorQueue.async {[weak self] in
            self?.interceptorWaiter[id] = response
            self?.sendSubject.send(MessageData.NetworkInteceptRecord.Request.with({ message in
                message.id = id.data
                message.requestData = data
            }))
        }
        interceptorQueue.asyncAfter(deadline: .now() + 120, execute: {[weak self] in
            enum InterceptorError: Error {
                case iterceptorTimeout
            }
            self?.interceptorWaiter[id]?(nil, nil, InterceptorError.iterceptorTimeout)
        })
    }
}

@available(iOS 13.0, *)
public struct NetworkRecord: Codable {
    public struct HeaderValue: Codable, Identifiable {
        public var id: String { key }
        public let key: String
        public let value: String
    }
    public struct NetworkRequest: Codable {
        public let date: Date
        public let method: String
        public let url: URL
        public let body: Data
        public let headers: [HeaderValue]
        public var cachePolicy: UInt
    }
    public struct NetworkResponse: Codable {
        public let date: Date
        public let code: Int
        public let body: Data
        public let headers: [HeaderValue]
    }
    public struct NetworkError: Codable {
        public let date: Date
        public let localizedError: String
    }
    public enum NetworkData: Codable {
        case request(NetworkRequest)
        case response(NetworkResponse)
        case error(NetworkError)
    }
    public let id: UUID
    public let data: NetworkData
}

@available(iOS 13.0, *)
public struct InterceptorRequest: Codable {
    public let nsUrlRequest: Data
}

@available(iOS 13.0, *)
public struct InterceptorResponse: Codable {
    public let nsUrlResponse: Data?
    public let body: Data?
    public let nsError: Data?
    
    public init(nsUrlResponse: Data?, body: Data?, nsError: Data?) {
        self.nsUrlResponse = nsUrlResponse
        self.body = body
        self.nsError = nsError
    }
}
