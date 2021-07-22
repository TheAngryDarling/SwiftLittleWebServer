//
//  LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-12.
//

import Foundation
import Dispatch
import StringIANACharacterSetEncoding
import Nillable

public extension LittleWebServer {
    
    /// A Wrapper error that contains the original error, the file and line where this error object was created
    struct TrackableError: Swift.Error, CustomStringConvertible, CustomDebugStringConvertible {
        /// The file where this error was created from
        public let file: String
        /// The line where this error was created from
        public let line: Int
        /// The original error
        public let error: Swift.Error
        
        public var description: String {
            return "\(self.error)"
        }
        
        public var debugDescription: String {
            var rtn = "file: '\(self.file)',\n"
            rtn += "line: \(self.line),\n"
            rtn += "error: '\(self.error)'"
            return rtn
        }
        
        #if swift(>=5.3)
        public init(error: Swift.Error, file: String = #filePath, line: Int = #line) {
            self.error = error
            self.file = file
            self.line = line
        }
        #else
        public init(error: Swift.Error, file: String = #file, line: Int = #line ) {
            self.error = error
            self.file = file
            self.line = line
        }
        #endif
    }
}

public extension LittleWebServer {
    /// A file transfer limiter used to limit the transfer rate of files between the server and a client
    enum FileTransferSpeedLimiter {
        /// No ttransfer limit
        case unlimited
        /// Set the limit in Bytes/s
        case rated(bytes: UInt, per: TimeInterval)
        /// The byte size to write per interval
        internal var bufferSize: UInt? {
            guard case .rated(let rtn, _) = self else {
                return nil
            }
            return rtn
        }
        
        /// Pause for the interval period
        internal func doPuase() {
            guard case .rated(_, per: let p) = self else {
                return
            }
            Thread.sleep(forTimeInterval: p)
        }
        
    }
    
    /// Class representing a readable file on the file system
    class ReadableFile {
        public enum Error: Swift.Error {
            case fileTransferFileNotFound(path: String)
            case fileTransferUnableToGetFileSize(path: String)
            case fileTransferUnableToOpenFile(path: String)
        }
        /// The file handle used for reading file system resources
        private let handle: FileHandle
        /// The size of the open file
        public let size: UInt
        /// The current offset in the open file
        public private(set) var currentOffset: UInt = 0
        /// Open the provided file
        public init(path: String) throws {
            guard FileManager.default.fileExists(atPath: path) else {
                throw  Error.fileTransferFileNotFound(path: path)
            }
            
            guard let attr = try? FileManager.default.attributesOfItem(atPath: path) else {
                throw  Error.fileTransferUnableToGetFileSize(path: path)
            }
            
            guard let nsFileSize = attr[FileAttributeKey.size] as? NSNumber else {
                throw Error.fileTransferUnableToGetFileSize(path: path)
            }
            
            let fileSize = UInt(truncating: nsFileSize)
            
            guard let handle = FileHandle(forReadingAtPath: path) else {
                throw Error.fileTransferUnableToOpenFile(path: path)
            }
            self.handle = handle
            self.size = fileSize
        }
        
        deinit {
            self.close()
        }
        
        /// Close the open file
        public func close() {
            #if swift(>=4.2) && _runtime(_ObjC)
            try? self.handle.close()
            #else
            self.handle.closeFile()
            #endif
        }
        /// Change the current offset within the given file
        public func seek(to offset: UInt) throws {
            #if swift(>=4.2) && _runtime(_ObjC)
                if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
                    try self.handle.seek(toOffset: UInt64(offset))
                } else {
                    self.handle.seek(toFileOffset: UInt64(offset))
                }
            #else
                self.handle.seek(toFileOffset: UInt64(offset))
            #endif
            self.currentOffset = offset
        }
        
        /// Read data from the file starting at the current offset
        /// - Parameters:
        ///   - buffer: The buffer to write the data to
        ///   - count: The max number of bytes to read
        /// - Returns: The number of bytes actually read
        public func read(into buffer: UnsafeMutablePointer<UInt8>, upToCount count: Int) throws -> UInt {
            precondition(count >= 0, "Count must be >= 0")
            guard count > 0 else {
                return 0
            }
            
            #if os(Linux)
            let ret = Glibc.read(self.handle.fileDescriptor, buffer, count)
            #else
            let ret = Darwin.read(self.handle.fileDescriptor, buffer, count)
            #endif
            
            // validate error
            guard ret >= 0  else {
                throw LittleWebServerSocketSystemError.current()
            }
            
            self.currentOffset += UInt(ret)
            
            return UInt(ret)
        }
        
        /// Read data from the file starting at the current offset
        /// - Parameters:
        ///   - buffer: The buffer to write the data to
        ///   - count: The max number of bytes to read
        /// - Returns: The number of bytes actually read
        internal func read(into buffer: UnsafeMutablePointerContainer<UInt8>, upToCount count: Int) throws -> UInt {
            return try self.read(into: buffer.buffer, upToCount: count)
        }
    }
}

public extension LittleWebServer {
    /// Namespace for all Helper Objects/Logic
    struct Helpers { private init() { }
        /// An open ended Enum
        public enum OpenEnum<Enum>: LittleWebServerOpenRawRepresentable
            where Enum: RawRepresentable {
            /// A known value
            case known(Enum)
            /// An unknown value
            case unknown(Enum.RawValue)
            
            public var rawValue: Enum.RawValue {
                switch self {
                    case .known(let r): return r.rawValue
                    case .unknown(let r): return r
                }
            }
            
            public init(_ r: Enum) {
                self = .known(r)
            }
            public init(rawValue: Enum.RawValue) {
                if let r = Enum(rawValue: rawValue) {
                    self = .known(r)
                } else {
                    self = .unknown(rawValue)
                }
            }
        }
        
        #if swift(>=4.1)
        /// Open ended Equtable Enum
        public typealias OpenEquatableEnum<Enum> = OpenEnum<Enum> where Enum: RawRepresentable, Enum.RawValue: Equatable
        #else
        /// Open ended Equtable Enum
        public enum OpenEquatableEnum<Enum>: LittleWebServerOpenEquatableRawRepresentable
            where Enum: RawRepresentable,
                  Enum.RawValue: Equatable {
            /// A known value
            case known(Enum)
            /// An unknown value
            case unknown(Enum.RawValue)
            
            public var rawValue: Enum.RawValue {
                switch self {
                    case .known(let r): return r.rawValue
                    case .unknown(let r): return r
                }
            }
            
            public init(_ r: Enum) {
                self = .known(r)
            }
            public init(rawValue: Enum.RawValue) {
                if let r = Enum(rawValue: rawValue) {
                    self = .known(r)
                } else {
                    self = .unknown(rawValue)
                }
            }
        }
        #endif
        
    }
    /// Namespace for all HTTP Objects
    struct HTTP { private init() { }
        /// Namespace for all HTTP Communication Objects/Logic
        public struct Communicators { private init() { } }
        
        /// HTTP Version
        public struct Version: Comparable,
                               CustomStringConvertible,
                               LittleWebServerSimilarOperator {
            
            public static var v1_0: Version { return .init(major: 1) }
            public static var v1_1: Version { return .init(major: 1, minor: 1) }
            public static var v2_0: Version { return .init(major: 2) }
            public static var v2: Version { return self.v2_0 }
            
            /// Version Major
            public let major: UInt
            /// Vesion Minor
            public let minor: UInt
            
            
            /// Full version value eg. 1.1
            public var fullVersion: String {
                return "\(self.major).\(self.minor)"
            }
            /// Short Version value.  When version >= 2 and minor is 0, will only return major value
            public var shortVersion: String {
                var rtn: String = "\(self.major)"
                if self.minor > 0 || self.major == 1 {
                    rtn += ".\(self.minor)"
                }
                return rtn
            }
            
            /// The HTTP Response version value
            internal var httpRespnseValue: String {
                return "HTTP/\(self.fullVersion)"
            }
            
            public var description: String {
                return self.fullVersion
            }
            
            /// Create a new HTTP Version
            /// - Parameters:
            ///   - major: The major version number
            ///   - minor: The minor version number
            public init(major: UInt, minor: UInt = 0) {
                self.major = major
                self.minor = minor
            }
            
            public init?(rawValue: String) {
                guard !rawValue.isEmpty else { return nil }
                let components = rawValue.split(separator: ".")
                guard components.count >= 1 && components.count <= 2 else { return nil }
                
                var mn: UInt = 0
                guard let mj = UInt(components[0]) else { return nil }
                if components.count == 2 {
                    guard let m = UInt(components[0]) else { return nil }
                    mn = m
                }
                
                self.major = mj
                self.minor = mn
            }
            
            public static func ==(lhs: Version, rhs: Version) -> Bool {
                return lhs.major == rhs.major && lhs.minor == rhs.minor
            }
            public static func ~=(lhs: Version, rhs: Version) -> Bool {
                return lhs.major == rhs.minor
            }
            public static func ~=(lhs: Version, rhs: Version?) -> Bool {
                guard let rhs = rhs else { return false }
                return lhs ~= rhs
            }
            public static func <(lhs: Version, rhs: Version) -> Bool {
                if lhs.major < rhs.major { return true }
                else if lhs.major > rhs.major { return false }
                else { return lhs.minor < rhs.minor }
            }
        }
        /// HTTP Method
        public struct Method: RawRepresentable,
                              Hashable,
                              CustomStringConvertible,
                              ExpressibleByStringLiteral {
            public let rawValue: String
            
            public var description: String { return self.rawValue }
            
            #if !swift(>=4.2)
            public var hashValue: Int { return self.rawValue.hashValue }
            #endif
            
            /// HTTP 'HEAD' Method
            public static var head: Method { return "HEAD" }
            /// HTTP 'GET' Method
            public static var get: Method { return "GET" }
            /// HTTP 'POST' Method
            public static var post: Method { return "POST" }
            /// HTTP 'PUT' Method
            public static var put: Method { return "PUT" }
            /// HTTP 'DELETE' Method
            public static var delete: Method { return "DELETE" }
            /// HTTP 'CONNECT' Method
            /// The HTTP CONNECT method starts two-way communications with the requested resource. It can be used to open a tunnel.
            public static var connect: Method { return "CONNECT" }
            /// HTTP 'OPTIONS' Method
            public static var options: Method { return "OPTIONS" }
            /// HTTP 'TRACE' Method
            /// The HTTP TRACE method performs a message loop-back test along the path to the target resource, providing a useful debugging mechanism.
            public static var trace: Method { return "TRACE" }
            /// HTTP 'PATCH' Method
            /// The HTTP PATCH request method applies partial modifications to a resource.
            public static var patch: Method { return "PATCH" }
            
            /// A list of known basic HTTP Methods.  (HEAD, GET, POST, PUT, DELETE
            public static let basicKnownMethods: [Method] = [.head, .get, .post, .put, .delete]
            /// A list of known HTTP Methods (HEAD, GET, POST, PUT, DELETE, CONNECT, TRACE, PATCH)
            public static let allKnownMethods: [Method] = [.head, .get, .post, .put, .delete,
                                                           .connect, .trace, .patch]
            
            public init?(rawValue: String) {
                guard !rawValue.contains(" ") else { return nil }
                self.rawValue = rawValue.uppercased()
            }
            public init(stringLiteral value: String) {
                precondition(!value.contains(" "), "Spaces are not allowed in HTTP Method")
                self.rawValue = value.uppercased()
            }
            
            #if swift(>=4.2)
            public func hash(into hasher: inout Hasher) {
                self.rawValue.hash(into: &hasher)
            }
            #endif
            
            public static func ==(lhs: Method, rhs: Method) -> Bool {
                return lhs.rawValue == rhs.rawValue
            }
        }
        /// Namespace for all HTTP Header Objects
        public struct Headers { private init() { }
            /// HTTP LittleWebServer Session ID
            public static let SessionId: String = "LWSSESSION"
            /// Header Name Object (A Case Insensative Object)
            public struct Name: Hashable,
                                Comparable,
                                CustomStringConvertible,
                                LittleWebServerExpressibleByStringInterpolation {
                internal let rawValue: String
                internal let isProper: Bool
                
                public var description: String { return self.rawValue }
                
                #if !swift(>=4.1)
                public var hashValue: Int { return self.rawValue.lowercased().hashValue }
                #endif
                
                /// Create a new Header Name with the given string
                public init<S>(_ string: S) where S: StringProtocol {
                    self.rawValue = (string as? String) ?? String(string)
                    self.isProper = false
                }
                /// Create a new Header Name with the given proper string
                /// A proper string is one that won't be changed to camelcase
                /// when writing to the response
                public init(properString string: String) {
                    self.rawValue = string
                    self.isProper = true
                }
                
                public init(stringLiteral value: String) {
                    self.init(value)
                }
                
                #if swift(>=4.2)
                public func hash(into hasher: inout Hasher) {
                    self.rawValue.lowercased().hash(into: &hasher)
                }
                #endif
                
                public static func ==(lhs: Name, rhs: Name) -> Bool {
                    return lhs.rawValue.lowercased() == rhs.rawValue.lowercased()
                }
                
                public static func ==(lhs: Name, rhs: String) -> Bool {
                    return lhs.rawValue.lowercased() == rhs.lowercased()
                }
                
                public static func <(lhs: Name, rhs: Name) -> Bool {
                    return lhs.rawValue.lowercased() < rhs.rawValue.lowercased()
                }
                
                public static func <(lhs: Name, rhs: String) -> Bool {
                    return lhs.rawValue.lowercased() < rhs.lowercased()
                }
                /// 'Accept' HTTP Header
                public static var accept: Name { return .init(properString: "Accept") }
                /// 'Accept-Encoding' HTTP Header
                public static var acceptEncoding: Name { return .init(properString: "Accept-Encoding") }
                /// 'Accept-Language' HTTP Header
                public static var acceptLanguage: Name { return .init(properString: "Accept-Language") }
                /// 'Accept-Patch' HTTP Header
                public static var acceptPatch: Name { return .init(properString: "Accept-Patch") }
                /// 'Accept-Ranges' HTTP Header
                public static var acceptRanges: Name { return .init(properString: "Accept-Ranges") }
                /// 'Allow' HTTP Header
                public static var allow: Name { return .init(properString: "Allow") }
                /// 'Authorization' HTTP Header
                public static var authorization: Name { return .init(properString: "Authorization") }
                /// 'Connection' HTTP Header
                public static var connection: Name { return .init(properString: "Connection") }
                /// 'Content-Disposition' HTTP Header
                public static var contentDisposition: Name { return .init(properString: "Content-Disposition") }
                /// 'Content-Encoding' HTTP Header
                public static var contentEncoding: Name { return .init(properString: "Content-Encoding") }
                /// 'Content-Length' HTTP Header
                public static var contentLength: Name { return .init(properString: "Content-Length") }
                /// 'Content-Length' HTTP Header
                public static var contentLocation: Name { return .init(properString: "Content-Location") }
                /// 'Content-Range' HTTP Header
                public static var contentRange: Name { return .init(properString: "Content-Range") }
                /// 'Content-Type' HTTP Header
                public static var contentType: Name { return .init(properString: "Content-Type") }
                /// 'Cookie' HTTP Header
                public static var cookie: Name { return .init(properString: "Cookie") }
                /// 'Date' HTTP Header
                public static var date: Name { return .init(properString: "Date") }
                /// 'ETag' HTTP Header
                public static var eTag: Name { return .init(properString: "ETag") }
                /// 'Expect' HTTP Header
                public static var expect: Name { return .init(properString: "Expect") }
                /// 'Expires' HTTP Header
                public static var expires: Name { return .init(properString: "Expires") }
                /// 'Host' HTTP Header
                public static var host: Name { return .init(properString: "Host") }
                /// 'If-Match' HTTP Header
                public static var ifMatch: Name { return .init(properString: "If-Match") }
                /// 'If-Modified-Since' HTTP Header
                public static var ifModifiedSince: Name { return .init(properString: "If-Modified-Since") }
                /// 'If-None-Match' HTTP Header
                public static var ifNoneMatch: Name { return .init(properString: "If-None-Match") }
                /// 'If-Range' HTTP Header
                public static var ifRange: Name { return .init(properString: "If-Range") }
                /// 'If-Unmodified-Since' HTTP Header
                public static var ifUnmodifiedSince: Name { return .init(properString: "If-Unmodified-Since") }
                /// 'Location' HTTP Header
                public static var location: Name { return .init(properString: "Location") }
                /// 'Origin' HTTP Header
                public static var origin: Name { return .init(properString: "Origin") }
                /// 'Range' HTTP Header
                public static var range: Name { return .init(properString: "Range") }
                /// 'Referer' HTTP Header
                public static var referer: Name { return .init(properString: "Referer") }
                /// 'Upgrade' HTTP Header
                public static var upgrade: Name { return .init(properString: "Upgrade") }
                /// 'User-Agent' HTTP Header
                public static var userAgent: Name { return .init(properString: "User-Agent") }
                /// 'Keep-Alive' HTTP Header
                public static var keepAlive: Name { return .init(properString: "Keep-Alive") }
                /// 'Last-Modified' HTTP Header
                public static var lastModified: Name { return .init(properString: "Last-Modified") }
                /// 'Servers' HTTP Header
                public static var server: Name { return .init(properString: "Server") }
                /// 'Set-Cookie' HTTP Header
                public static var setCookie: Name { return .init(properString: "Set-Cookie") }
                /// 'Transfer-Encoding' HTTP Header
                public static var transferEncoding: Name { return .init(properString: "Transfer-Encoding") }
                /// 'Sec-WebScoket-Accept' HTTP Header
                public static var websocketSecurityAccept: Name { return .init(properString: "Sec-WebSocket-Accept") }
                /// 'Sec-WebSocket-Key' HTTP Header
                public static var websocketSecurityKey: Name { return .init(properString: "Sec-Websocket-Key") }
                /// 'WWW-Authenticate' HTTP Header
                public static var wwwAuthenticate: Name { return .init(properString: "WWW-Authenticate") }
                /// 'X-Forwarded-For' HTTP Header
                public static var xForwardedFor: Name { return .init(properString: "X-Forwarded-For") }
                /// 'X-Forwarded-Host' HTTP Header
                public static var xForwardedHost: Name { return .init(properString: "X-Forwarded-Host") }
                /// X-Forwarded-Proto' HTTP Header
                public static var xForwardedProto: Name { return .init(properString: "X-Forwarded-Proto") }
                
                
                
            }
            /// A Weighted header value (A value that can have ';q=' afterwards)
            public struct WeightedObject<T>: Comparable,
                                             CustomStringConvertible,
                                             RawRepresentable,
                                             LittleWebServerExpressibleByStringInterpolation
                where T: RawRepresentable, T.RawValue == String {
                /// The header value
                public let object: T
                private let _weight: String?
                /// The weight of the value
                public let weight: Float
                
                public var rawValue: String {
                    var rtn = self.object.rawValue
                    if let w = self._weight {
                        rtn += ";q=\(w)"
                    }
                    return rtn
                }
                
                public var description: String { return self.rawValue }
                
                public init(object: T) {
                    self.object = object
                    self.weight = 1.0
                    self._weight = nil
                }
                
                public init(object: T, weight: Float) {
                    self.object = object
                    self.weight = weight
                    self._weight = "\(weight)"
                }
                
                public init?(object: T, weight: String) {
                    guard let w = Float(weight) else {
                        return nil
                    }
                    self.object = object
                    self.weight = w
                    self._weight = weight
                }
                
                public init?(rawValue: String) {
                    let components = rawValue.split(separator: ";").map(String.init)
                    guard components.count >= 1 && components.count <= 2 else { return nil }
                    guard let obj = T(rawValue: components[0]) else { return nil }
                    
                    var weight: Float = 1.0
                    var sWeight: String? = nil
                    if components.count == 2 {
                        let weightComponents = components[1].split(separator: "=").map(String.init)
                        guard weightComponents.count == 2 && weightComponents[0] == "q" else { return nil }
                        guard let w = Float(weightComponents[1]) else { return nil }
                        weight = w
                        sWeight = weightComponents[1]
                    }
                    
                    
                    self.object = obj
                    self._weight = sWeight
                    self.weight = weight
                    
                }
                
                public init?<S>(_ value: S) where S: StringProtocol {
                    let string = (value as? String) ?? String(value)
                    guard let nv = WeightedObject<T>(rawValue: string) else {
                        return nil
                    }
                    self = nv
                }
                
                public init(stringLiteral value: String) {
                    guard let nv = WeightedObject<T>(rawValue: value) else {
                        fatalError("Invalid \(T.self) value '\(value)'")
                    }
                    self = nv
                }
                
                public static func ==(lhs: WeightedObject<T>, rhs: WeightedObject<T>) -> Bool {
                    return lhs.object.rawValue == rhs.object.rawValue && lhs._weight == rhs._weight
                }
                public static func <(lhs: WeightedObject<T>, rhs: WeightedObject<T>) -> Bool {
                    if lhs.weight > rhs.weight { return true }
                    else if lhs.weight < rhs.weight { return false }
                    else { return lhs.object.rawValue < rhs.object.rawValue }
                }
            }
            
            /// Content Dispostion Value
            public struct ContentDisposition {
                /// Content Disposition Type
                public enum DispositionType: String {
                    /// Form Data (form-data)
                    case formData = "form-data"
                    /// Attachment
                    case attachment = "attachment"
                    /// Inline
                    case inline = "inline"
                    
                    public init?(rawValue: String) {
                        let lowerValue = rawValue.lowercased()
                        switch lowerValue {
                            case DispositionType.formData.rawValue: self = .formData
                            case DispositionType.attachment.rawValue: self = .attachment
                            case DispositionType.inline.rawValue: self = .inline
                            default: return nil
                        }
                    }
                    
                    public init?<S>(_ string: S) where S: StringProtocol {
                        let value = (string as? String) ?? String(string)
                        guard let nv = DispositionType(rawValue: value) else {
                            return nil
                        }
                        self = nv
                    }
                    
                    public init(stringLiteral value: String) {
                        guard let nv = DispositionType(rawValue: value) else {
                            fatalError("Invalid value '\(value)'")
                        }
                        self = nv
                    }
                    
                    public static func ==(lhs: DispositionType, rhs: DispositionType) -> Bool {
                        return lhs.rawValue == rhs.rawValue
                    }
                }
                /// The content disposition type
                public let type: Helpers.OpenEquatableEnum<DispositionType>
                /// The content disposition name
                public let name: String
                /// The content disposition file name (If provided)
                public let filename: String?
                /// The content disposition file name * (If provided)
                public let filenameB: String?
                
                public var description: String {
                    var rtn: String = "Content-Disposition: \(self.type.rawValue); name=\"\(self.name)\""
                    if let f = self.filename {
                        rtn += "; filename=\"\(f)\""
                    }
                    if let f = self.filenameB {
                        rtn += "; filename*=\"\(f)\""
                    }
                    return rtn
                }
                
                public init?(_ value: String) {
                    guard value.hasPrefix("Content-Disposition:") else { return nil }
                    let components = value.split(separator: ";")
                    guard components.count >= 2 && components.count <= 4 else { return nil }
                    
                    let distTypeComponents = components[0].split(separator: ":").map(String.init)
                    guard distTypeComponents.count == 2 else { return nil }
                    var tp = distTypeComponents[1]
                    if tp.hasPrefix(" ") { tp.removeFirst() }
                    var nm: String? = nil
                    var fn: String? = nil
                    var fn2: String? = nil
                    
                    for i in 1..<components.count {
                        let fieldComponents = components[i].split(separator: "=").map(String.init)
                        guard fieldComponents.count == 2 else { return nil }
                        var value = fieldComponents[1]
                        value.removeFirst() // remove leading "
                        value.removeLast() // remove trailing "
                        
                        if fieldComponents[0] == " name" {
                            nm = value
                        } else if fieldComponents[0] == " filename" {
                            fn = value
                        } else if fieldComponents[0] == " filename*" {
                            fn2 = value
                        } else {
                            return nil
                        }
                    }
                    
                    
                    guard nm != nil else { return nil }
                    
                    self.type = Helpers.OpenEquatableEnum<DispositionType>(rawValue: tp)
                    self.name = nm!
                    self.filename = fn
                    self.filenameB = fn2
                    
                }
            }
        
            /// Connection Header Value
            public enum Connection: String {
                case close = "close"
                case keepAlive = "keep-alive"
                case upgrade = "upgrade"
                
                public init?(rawValue: String) {
                    let lowerValue = rawValue.lowercased()
                    if lowerValue == Connection.close.rawValue {
                        self = .close
                    } else if lowerValue == Connection.keepAlive.rawValue {
                        self = .keepAlive
                    } else if lowerValue == Connection.upgrade.rawValue {
                        self = .upgrade
                    } else {
                        return nil
                    }
                }
            }
            /// AcceptLanguage Header Value
            public enum AcceptLanguage: RawRepresentable,
                                        Comparable,
                                        CustomStringConvertible,
                                        LittleWebServerSimilarOperator,
                                        LittleWebServerExpressibleByStringInterpolation {
                case any
                case specific(String)
                
                public var rawValue: String {
                    switch self {
                        case .any: return "*"
                        case .specific(let rtn): return rtn
                    }
                }
                
                public var description: String { return self.rawValue }
                
                public var identity: String { return self.rawValue }
                
                public var isAnyLanguage: Bool {
                    guard case .any = self else { return false }
                    return true
                }
                public var locale: Locale? {
                    guard case .specific(let id) = self else { return nil }
                    return Locale(identifier: id)
                }
                
                public init?(rawValue: String) {
                    if rawValue == "*" {
                        self = .any
                    } else {
                        // Make sure language code is either XX or XX-XX like en or en-us
                        guard rawValue.count == 2 ||
                              (rawValue.count == 5 &&
                                rawValue[rawValue.index(rawValue.startIndex, offsetBy: 2)] == "-") else {
                            return nil
                        }
                        self = .specific(rawValue)
                    }
                }
                
                public init?<S>(_ string: S) where S: StringProtocol {
                    let value = (string as? String) ?? String(string)
                    guard let nv = AcceptLanguage(rawValue: value) else { return nil }
                    self = nv
                }
                
                public init(stringLiteral value: String) {
                    guard let nv = AcceptLanguage(rawValue: value) else {
                        fatalError("Invalid Langauge '\(value)'")
                    }
                    self = nv
                }
                
                public static func ==(lhs: AcceptLanguage, rhs: AcceptLanguage) -> Bool {
                    return lhs.rawValue == rhs.rawValue
                }
                public static func ~=(lhs: AcceptLanguage, rhs: AcceptLanguage) -> Bool {
                    switch (lhs, rhs) {
                        case (.any, .any): return true
                        case (.specific(let lhsId), .specific(let rhsId)):
                            let lhsL = Locale(identifier: lhsId)
                            let rhsL = Locale(identifier: rhsId)
                            return lhsL.languageCode == rhsL.languageCode
                        
                        default: return false
                    }
                }
                public static func ~=(lhs: AcceptLanguage, rhs: AcceptLanguage?) -> Bool {
                    guard let rhs = rhs else { return false }
                    return lhs ~= rhs
                }
                
                public static func < (lhs: AcceptLanguage, rhs: AcceptLanguage) -> Bool {
                    return lhs.rawValue < rhs.rawValue
                }
            }
            /// Weighted AcceptLanguage Header Value
            public typealias WeightedAcceptLanguage = WeightedObject<AcceptLanguage>
            
            /// Content-Encoding Header Value
            public enum ContentEncoding: String, LittleWebServerRawValueHashable, Comparable {
                case br
                case chunked
                case compress
                case deflate
                case gzip
                case identity
                
                public static func ==(lhs: ContentEncoding, rhs: ContentEncoding) -> Bool {
                    return lhs.rawValue == rhs.rawValue
                }
                
                public static func <(lhs: ContentEncoding, rhs: ContentEncoding) -> Bool {
                    return lhs.rawValue < rhs.rawValue
                }
            }
            
            /// Transfer-Encoding Header Value
            public enum TransferEncoding: RawRepresentable,
                                          LittleWebServerRawValueHashable,
                                          Comparable {
                case any
                case contentEncoding(ContentEncoding)
                
                public static var br: TransferEncoding { return .contentEncoding(.br) }
                public static var chunked: TransferEncoding { return .contentEncoding(.chunked) }
                public static var compress: TransferEncoding { return .contentEncoding(.compress) }
                public static var deflate: TransferEncoding { return .contentEncoding(.deflate) }
                public static var gzip: TransferEncoding { return .contentEncoding(.gzip) }
                public static var identity: TransferEncoding { return .contentEncoding(.identity) }
                
                
                public var rawValue: String {
                    switch self {
                    case .any: return "*"
                    case .contentEncoding(let cte): return cte.rawValue
                    }
                }
                
                public init?(rawValue: String) {
                    if rawValue == "*" { self = .any }
                    else if let cte = ContentEncoding(rawValue: rawValue) {
                        self = .contentEncoding(cte)
                    } else {
                        return nil
                    }
                }
                
                public static func ==(lhs: TransferEncoding, rhs: TransferEncoding) -> Bool {
                    return lhs.rawValue == rhs.rawValue
                }
                
                public static func <(lhs: TransferEncoding, rhs: TransferEncoding) -> Bool {
                    return lhs.rawValue < rhs.rawValue
                }
            }
            
            
            
            /// Open TransferEncoding Header Value
            public typealias OpenTransferEncoding = Helpers.OpenEquatableEnum<TransferEncoding>
            
            /// Content-Type Header Value
            public struct ContentType: Equatable,
                                       LittleWebServerSimilarOperator,
                                       LittleWebServerExpressibleByStringInterpolation {
                /// Content-Type Resource Type
                public struct ResourceType: Equatable,
                                         LittleWebServerSimilarOperator,
                                         LittleWebServerExpressibleByStringInterpolation {
                    
                    /// Media Type Group (This is like text, image, application, etc)
                    public struct Group: LittleWebServerCaseInsensativeCustomStringHashable,
                                         LittleWebServerExpressibleByStringInterpolation {
                        public let description: String
                        
                        public static let any: Group = "*"
                        public static let application: Group = "application"
                        public static let multipart: Group = "multipart"
                        public static let image: Group = "image"
                        public static let text: Group = "text"
                        
                        public init(_ value: String) {
                            self.description = value
                        }
                        public init(stringLiteral value: String) {
                            self.description = value
                        }
                        
                        public static func ==(lhs: Group, rhs: Group) -> Bool {
                            return lhs.description.lowercased() == rhs.description.lowercased()
                        }
                    }
                    /// Media Type Group Type (This is like plain, html, json)
                    public struct GroupType: LittleWebServerCaseInsensativeCustomStringHashable,
                                            LittleWebServerExpressibleByStringInterpolation {
                        public let description: String
                        
                        public static let any: GroupType = "*"
                        public static let plain: GroupType = "plain"
                        public static let html: GroupType = "html"
                        public static let xhtml: GroupType = "xhtml+xml"
                        public static let json: GroupType = "json"
                        
                        public static let formURLEncoded: GroupType = "x-www-form-urlencoded"
                        public static let formData: GroupType = "form-data"
                        public static let byteranges: GroupType = "byteranges"
                        
                        public init(_ value: String) {
                            self.description = value
                        }
                        public init(stringLiteral value: String) {
                            self.description = value
                        }
                        
                        public static func ==(lhs: GroupType, rhs: GroupType) -> Bool {
                            return lhs.description.lowercased() == rhs.description.lowercased()
                        }
                    }
                    
                    
                    public var group: Group
                    public var subGroup: GroupType
                    
                    public static var any: ResourceType {
                        return ResourceType(group: .any, subGroup: .any)
                    }
                    
                    public static var html: ResourceType {
                        return ResourceType(group: .text, subGroup: .html)
                    }
                    public static var xhtml: ResourceType {
                        return ResourceType(group: .application, subGroup: .xhtml)
                    }
                    public static var json: ResourceType {
                        return ResourceType(group: .application, subGroup: .json)
                    }
                    public static var plainText: ResourceType {
                        return ResourceType(group: .text, subGroup: .plain)
                    }
                    
                    public static var urlEncodedForm: ResourceType {
                        return ResourceType(group: .application, subGroup: .formURLEncoded)
                    }
                    public static var multiPartForm: ResourceType {
                        return ResourceType(group: .multipart, subGroup: .formData)
                    }
                    public static var multipartByteRanges: ResourceType {
                        return ResourceType(group: .multipart, subGroup: .byteranges)
                    }
                    
                    public var string: String {
                        return self.group.description + "/" + self.subGroup.description
                    }
                    
                    public var description: String {
                        return self.string
                    }
                    /// Indicator if this media type is a text type
                    public var isText: Bool {
                        return self.group == .text
                    }
                    /// Indicator if this media type is an application type
                    public var isApplication: Bool {
                        return self.group == .application
                    }
                    
                    public init(_ group: String, _ subGroup: String) {
                        self.group = Group(group)
                        self.subGroup = GroupType(subGroup)
                    }
                    
                    public init(group: Group, subGroup: GroupType) {
                        self.group = group
                        self.subGroup = subGroup
                    }
                    
                    public init?<S>(_ value: S) where S: StringProtocol {
                        let value: String = (value as? String) ?? String(value)
                        
                        guard !value.isEmpty else { return nil }
                        let components = value.components(separatedBy: "/")
                        guard components.count == 2 else { return nil }
                        self.group = Group(components[0])
                        self.subGroup = GroupType(components[1])
                    }
                    
                    public init(stringLiteral value: String) {
                        precondition(!value.isEmpty, "String can not be empty")
                        
                        let components = value.components(separatedBy: "/")
                        precondition(components.count == 2, "Media Type '\(value)' missing '/' separator")
                        self.group = Group(components[0])
                        self.subGroup = GroupType(components[1])
                    }
                    
                    public static func ==(lhs: ResourceType, rhs: ResourceType) -> Bool {
                        return lhs.group == rhs.group && lhs.subGroup == rhs.subGroup
                    }
                    public static func ~=(lhs: ResourceType, rhs: ResourceType) -> Bool {
                        return lhs.group == rhs.group
                    }
                    public static func ~=(lhs: ResourceType, rhs: ResourceType?) -> Bool {
                        guard let rhs = rhs else { return false }
                        return lhs ~= rhs
                    }
                    
                    public static func ==(lhs: ResourceType, rhs: String) -> Bool {
                        guard let rhs = ResourceType(rhs) else { return false }
                        return lhs == rhs
                    }
                    public static func ~=(lhs: ResourceType, rhs: String?) -> Bool {
                        guard let rh = rhs else { return false }
                        guard let r = ResourceType(rh) else { return false }
                        return lhs ~= r
                    }
                    
                    public static func ==(lhs: ResourceType, rhs: ContentType) -> Bool {
                        return lhs == rhs.resourceType
                    }
                    public static func ~=(lhs: ResourceType, rhs: ContentType) -> Bool {
                        return lhs ~= rhs.resourceType
                    }
                    
                }
                
                public static var urlEncodedForm: ContentType { return .init(.urlEncodedForm) }
                public static var multiPartForm: ContentType { return .init(.multiPartForm) }
                public static var multipartByteRanges: ContentType { return .init(.multipartByteRanges) }
                
                public static var html: ContentType { return .init(.html) }
                public static var xhtml: ContentType { return .init(.xhtml) }
                public static var json: ContentType { return .init(.json) }
                public static var plain: ContentType { return .init(.plainText) }
                
                
                public let resourceType: ResourceType
                public var details: [String]
                
               
                public var isText: Bool { return self.resourceType.isText }
                public var isHTML: Bool {
                    return self.resourceType == .html
                }
                public var isXHTML: Bool {
                    return self.resourceType == .xhtml
                }
                
                public var isAnyHTML: Bool { return self.isHTML || self.isXHTML }
                
                public var isJSON: Bool { return self.resourceType ~= .json }
                
                public var multiPartBoundary: String? {
                    guard let d = self.details.first(where: { return $0.lowercased().hasPrefix("boundary=") }) else {
                        return nil
                    }
                    let components =  d.components(separatedBy: "=")
                    guard components.count == 2 else { return nil }
                    return components[1]
                }
                
                public var charset: String? {
                    get {
                        guard let d = self.details.first(where: { return $0.lowercased().hasPrefix("charset=") }) else {
                            return nil
                        }
                        let components =  d.components(separatedBy: "=")
                        guard components.count == 2 else { return nil }
                        return components[1]
                    }
                    set {
                        if newValue == nil {
                            if let idx = self.details.firstIndex(where: { return $0.lowercased().hasPrefix("charset=") }) {
                                self.details.remove(at: idx)
                            }
                        } else {
                            if let idx = self.details.firstIndex(where: { return $0.lowercased().hasPrefix("charset=") }) {
                                self.details[idx] = "charset=\(newValue!)"
                            } else {
                                self.details.append("charset=\(newValue!)")
                                self.details.sort()
                            }
                        }
                    }
                }
                
                public var characterEncoding: String.Encoding? {
                    get {
                        guard let c = self.charset else { return nil }
                        return String.Encoding(IANACharSetName: c)
                    }
                    set {
                        let cs: String? = newValue?.IANACharSetName ?? nil
                        self.charset = cs
                    }
                }
                
                public var string: String {
                    var rtn = self.resourceType.description
                    for detail in self.details {
                        rtn += "; " + detail
                    }
                    return rtn
                }
                
                public var description: String {
                    return self.string
                }
                
                public init(_ resourceType: ResourceType, details: [String] = []) {
                    self.resourceType = resourceType
                    self.details = details
                }
                
                public init?(resourceType: ResourceType?, details: [String] = []) {
                    guard let r = resourceType else { return nil }
                    self.init(r, details: details)
                }
                
                
                
                public init?<S>(_ value: S) where S: StringProtocol {
                    let value: String = (value as? String) ?? String(value)
                    
                    guard !value.isEmpty else { return nil }
                    var contentTypeHeaderTokens = value.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
                    guard let mt = ResourceType(contentTypeHeaderTokens.first!) else { return nil }
                    self.resourceType = mt
                    contentTypeHeaderTokens.remove(at: 0)
                    self.details = contentTypeHeaderTokens
                }
                
                public init(stringLiteral value: String) {
                    precondition(!value.isEmpty, "String can not be empty")
                    
                    var contentTypeHeaderTokens = value.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
                    self.resourceType = ResourceType(stringLiteral: contentTypeHeaderTokens.first!)
                    contentTypeHeaderTokens.remove(at: 0)
                    self.details = contentTypeHeaderTokens
                }
                
                public static func multipartByteRanges(boundry: String) -> ContentType {
                    return ContentType(.multipartByteRanges, details: ["boundry=\(boundry)"])
                }
                
                public static func ==(lhs: ContentType, rhs: ContentType) -> Bool {
                    return lhs.resourceType == rhs.resourceType && lhs.details.sameElements(as: rhs.details)
                }
                public static func ~=(lhs: ContentType, rhs: ContentType) -> Bool {
                    return lhs.resourceType == rhs.resourceType
                }
                public static func ~=(lhs: ContentType, rhs: ContentType?) -> Bool {
                    guard let rhs = rhs else { return false }
                    return lhs ~= rhs
                }
                
                public static func ==(lhs: ContentType, rhs: ResourceType) -> Bool {
                    return lhs.resourceType == rhs
                }
                public static func ~=(lhs: ContentType, rhs: ResourceType) -> Bool {
                    return lhs.resourceType == rhs
                }
            }
            /// Host Header Value
            public struct Host: LittleWebServerStructCustomStringHashable,
                                LittleWebServerExpressibleByStringInterpolation,
                                LittleWebServerSimilarOperator,
                                Comparable {
                /// Host Name.  This excludes any port indicator of the host
                public struct Name: LittleWebServerStructCustomStringHashable,
                                    LittleWebServerExpressibleByStringInterpolation,
                                    Comparable {
                    public let description: String
                    
                    public init(_ value: String) {
                        self.description = value
                    }
                    
                    public init(stringLiteral value: String) {
                        self.description = value
                    }
                    
                    public static func ==(lhs: Name, rhs: Name) -> Bool {
                        return lhs.description == rhs.description
                    }
                    public static func <(lhs: Name, rhs: Name) -> Bool {
                        return lhs.description < rhs.description
                    }
                }
                /// Host Name
                public let name: Name
                /// Host Port
                public let port: Int?
                
                public var description: String {
                    var rtn: String = name.description
                    if let p = port {
                        rtn += ":\(p)"
                    }
                    
                    return rtn
                }
                
                public init?<S>(_ value: S) where S: StringProtocol {
                    let value: String = (value as? String) ?? String(value)
                    
                    let components: [String] = value.split(separator: ":").map(String.init)
                    guard components.count >= 1 && components.count <= 2 else {
                        return nil
                    }
                    self.name = Name(components[0])
                    if components.count == 2 {
                        guard let p = Int(components[1]) else {
                            return nil
                        }
                        self.port = p
                    } else {
                        self.port = nil
                    }
                }
                
                public init(stringLiteral value: String) {
                    let components: [String] = value.split(separator: ":").map(String.init)
                    guard components.count >= 1 && components.count <= 2 else {
                        fatalError("Invalid Host value '\(value)'")
                    }
                    self.name = Name(components[0])
                    if components.count == 2 {
                        guard let p = Int(components[1]) else {
                            fatalError("Invalid Host value '\(value)'.  Invalid Port Number '\(components[1])'")
                        }
                        self.port = p
                    } else {
                        self.port = nil
                    }
                }
                
                public static func ==(lhs: Host, rhs: Host) -> Bool {
                    return lhs.description == rhs.description
                }
                public static func <(lhs: Host, rhs: Host) -> Bool {
                    return lhs.description < rhs.description
                }
                public static func ~=(lhs: Host, rhs: Host) -> Bool {
                    return lhs.name == rhs.name
                }
                
            }
            /// Keep-Alive Header Value
            public struct KeepAlive: LittleWebServerStructCustomStringHashable,
                                     LittleWebServerExpressibleByStringInterpolation,
                                     Comparable {
                
                public let timeout: UInt?
                public let max: UInt?
                
                public var description: String {
                    var rtn: String = ""
                    if let v = self.timeout {
                        if !rtn.isEmpty { rtn += ", " }
                        rtn += "timeout: \(v)"
                    }
                    if let v = self.max {
                        if !rtn.isEmpty { rtn += ", " }
                        rtn += "max: \(v)"
                    }
                    return rtn
                }
                
                public init(timeout: UInt, max: UInt) {
                    self.timeout = timeout
                    self.max = max
                }
                public init(timeout: UInt) {
                    self.timeout = timeout
                    self.max = nil
                }
                public init(max: UInt) {
                    self.timeout = nil
                    self.max = max
                }
                
                public init?<S>(_ value: S) where S: StringProtocol {
                    let string = (value as? String) ?? String(value)
                    let components = string.split(separator: ",").map(String.init)
                    var tmo: UInt? = nil
                    var mx: UInt? = nil
                    for var component in components {
                        if component.hasPrefix(" ") { component.removeFirst() }
                        let itemComponents = component.split(separator: "=").map(String.init)
                        guard itemComponents.count == 2 else { return nil }
                        guard let val = UInt(itemComponents[1]) else { return nil }
                        let key = itemComponents[0].lowercased()
                        if key == "timeout" {
                            tmo = val
                        } else if key == "max" {
                            mx = val
                        } else {
                            return nil
                        }
                    }
                    self.timeout = tmo
                    self.max = mx
                }
                
                public init(stringLiteral value: String) {
                    guard let nv = KeepAlive(value) else {
                        fatalError("Invalid Value '\(value)'")
                    }
                    self = nv
                }
                
                #if swift(>=4.2)
                public func hash(into hasher: inout Hasher) {
                    self.description.hash(into: &hasher)
                }
                #endif
                
                public static func ==(lhs: KeepAlive, rhs: KeepAlive) -> Bool {
                    return lhs.description == rhs.description
                }
                public static func <(lhs: KeepAlive, rhs: KeepAlive) -> Bool {
                    return lhs.description < rhs.description
                }
            }
        }
        /// HTTP Rquest Object
        public class Request {
            
            public enum Error: Swift.Error {
                case unableToDecodeBodyParameters
                case unableToFindBoundaryIdentifier(String)
                case noMoreDataAvailableInStream
                case unexpectedDataAfterBoundary(Data, wasEndBoundary: Bool)
                case invalidContentDispositionLine(String)
                case expectingNewLine(found: Data)
                case unableToCreateFile(URL)
            }
            /// Represents an HTTP Request Head.
            /// This contains the HTTP Method, Context Path, and Client HTTP Version
            public struct Head: CustomStringConvertible {
                /// The HTTP Method for the request
                public var method: Method
                /// THe HTTP Path requested (The context path and any query string)
                public var path: String
                /// The HTTP Response version
                public var version: Version
                
                /// The request context path (This does not include any query string passed along with it)
                public var contextPath: String {
                    var rtn: String = self.path
                    if let r = rtn.range(of: "?") {
                        rtn = String(rtn[rtn.startIndex..<r.lowerBound])
                    }
                    return rtn
                }
                /// Any query string appended to the context path
                public var query: String? {
                    guard let r = self.path.range(of: "?") else { return nil }
                    return String(self.path[r.upperBound..<self.path.endIndex])
                }
                /// The query Items from the query property
                public var queryItems: [URLQueryItem] {
                    
                    guard let q = self.query else { return [] }
                    
                    return Array<URLQueryItem>(urlQuery: q)
                    /*
                    var rtn: [URLQueryItem] = []
                    let items = q.split(separator: "&")
                    for item in items {
                        guard !item.isEmpty else { continue }
                        let query = item.split(separator: "=")
                        guard query.count >= 1 && !query[0].isEmpty else { continue }
                        let name: String = query[0].removingPercentEncoding ?? String(query[0])
                        var val: String? = nil
                        if query.count > 1 {
                            val = query[1].removingPercentEncoding ?? String(query[1])
                        }
                        rtn.append(URLQueryItem(name: name, value: val))
                    }
                    
                    return rtn*/
                }
                
                public var description: String {
                    return "\(self.method.rawValue) \(self.path) \(self.version.httpRespnseValue)"
                }
                
                /// Parse the HTTP Requet Head
                ///
                /// - Parameter headString: The HTTP Request Head String to parse
                /// - Returns: Returns a parsed HTTPHead object  or nil of could not parse
                public static func parse(_ headString: String) -> Head? {
                    let requestComponents = headString.split(separator: " ").map(String.init)
                    guard requestComponents.count == 3 else { return nil }
                    guard let method = Method(rawValue: requestComponents[0]) else { return nil }
                    let path = requestComponents[1].removingPercentEncoding ?? requestComponents[1]
                    var httpVer = requestComponents[2]
                    guard httpVer.hasPrefix("HTTP/") else { return nil }
                    httpVer.removeFirst("HTTP/".count)
                    guard let ver = Version(rawValue: httpVer) else { return nil }
                    
                    return .init(method: method,
                                 path: path,
                                 version: ver)
                }
                
                /// Parse the HTTP Requet Head
                ///
                /// - Parameter data: The HTTP Request Head data to parse
                /// - Returns: Returns a parsed HTTPHead object  or nil of could not parse
                public static func parse(_ data: Data) -> Head? {
                    guard let string = String(data: data, encoding: .utf8) else {
                        return nil
                    }
                    return self.parse(string)
                }
            }
            /// Container for all HTTP Request Headedrs
            public struct Headers: _LittleWebServerCommonHeaders {
                /// HTTP Request Cookie Header
                public struct Cookies: CustomStringConvertible,
                                       LittleWebServerExpressibleByStringInterpolation,
                                       Collection {
                    private var data: [String: [String]]
                    
                    public typealias Index = Dictionary<String, [String]>.Index
                    
                    public var string: String {
                        var rtn: String = ""
                        for (key, vals) in self.data {
                            for val in vals {
                                if !rtn.isEmpty { rtn += "; " }
                                rtn += key
                                if !val.isEmpty {
                                    rtn += "=" + val
                                }
                            }
                        }
                        return rtn
                    }
                    
                    public var description: String { return self.string }
                    public var startIndex: Index { return self.data.startIndex }
                    public var endIndex: Index { return self.data.endIndex }
                    /// Web Server Session Id's
                    public var sessionIds: [String] {
                        get { return self[HTTP.Headers.SessionId] ?? [] }
                        set {
                            guard newValue.count > 0 else {
                                self[HTTP.Headers.SessionId] = nil
                                return
                            }
                            self[HTTP.Headers.SessionId] = newValue
                        }
                    }
                    /// Get/Set a list of values for the given cookie id
                    public subscript(key: String) -> [String]? {
                        get { return self.data[key] }
                        set { self.data[key] = newValue }
                    }
                    public subscript(index: Index) -> (key: String, value: [String]) {
                        get { return self.data[index] }
                    }
                    
                    
                    
                    public init() { self.data = [:] }
                    public init?(rawValue: String) {
                        
                        self.data = [:]
                        let objects = rawValue.replacingOccurrences(of: "; ", with: ";").split(separator: ";")
                        for object in objects {
                            let keyValuePair = object.splitFirst(separator: "=").map(String.init)
                            guard keyValuePair.count >= 1 && keyValuePair.count <= 2 else {
                                return nil
                            }
                            if keyValuePair.count == 2 {
                                var vals = self.data[keyValuePair[0]] ?? Array<String>()
                                vals.append(keyValuePair[1])
                                self.data[keyValuePair[0]] = vals
                            } else {
                                var vals = self.data[keyValuePair[0]] ?? Array<String>()
                                vals.append("")
                                self.data[keyValuePair[0]] = vals
                            }
                        }
                    }
                    public init?<S>(_ value: S?) where S: StringProtocol {
                        guard let value = value else { return nil }
                        let string = (value as? String) ?? String(value)
                        guard let nv = Cookies(rawValue: string) else {
                            return nil
                        }
                        self = nv
                    }
                    
                    public init(stringLiteral value: String) {
                        guard let nv = Cookies(rawValue: value) else {
                            fatalError("Invalid Cookie value '\(value)'")
                        }
                        self = nv
                    }
                    
                    public func index(after index: Index) -> Index {
                        return self.data.index(after: index)
                    }
                }
                
                /// Contains a list of weighted transfer encodings
                public struct TransferEncodings: Equatable,
                                                 Collection,
                                                 LittleWebServerSimilarOperator,
                                                 LittleWebServerStructCustomStringHashable,
                                                 LittleWebServerExpressibleByStringInterpolation {
                    
                    
                    public typealias TransferEncoding = HTTP.Headers.TransferEncoding
                    public typealias OpenTransferEncoding = HTTP.Headers.OpenTransferEncoding
                    public typealias WeightedObject<T> = HTTP.Headers.WeightedObject<T> where T: RawRepresentable, T.RawValue == String
                    
                    private let encodings: [WeightedObject<OpenTransferEncoding>]
                    
                    public var startIndex: Int { return self.encodings.startIndex }
                    public var endIndex: Int { return self.encodings.endIndex }
                    
                    public var description: String {
                        return self.encodings.map({ return $0.rawValue }).joined(separator: ", ")
                    }
                    
                    public subscript(index: Int) -> WeightedObject<OpenTransferEncoding> {
                        get { return self.encodings[index] }
                    }
                    
                    public init(_ values: [WeightedObject<OpenTransferEncoding>] = []) {
                        if values.count > 1 {
                            for i in 0..<(values.count-1) {
                                for x in (i+1)..<values.count {
                                    if values[i].object == values[x].object {
                                        preconditionFailure("Duplicate TransferEncoding ('\(values[x].object)') found at \(i) and \(x)")
                                    }
                                }
                            }
                        }
                        self.encodings = values
                    }
                    
                    public init(_ values: OpenTransferEncoding...) {
                        self.init(values.map(WeightedObject<OpenTransferEncoding>.init(object:)))
                    }
                    public init(_ values: TransferEncoding...) {
                        self.init(values.map(WeightedObject<OpenTransferEncoding>.init))
                    }
                    public init(_ value: [String]) {
                        self.init(value.compactMap(WeightedObject<OpenTransferEncoding>.init(rawValue:)))
                    }
                    
                    public init?<S>(_ value: S?) where S: StringProtocol {
                        guard let value = value else { return nil }
                        let string = (value as? String) ?? String(value)
                        self.init(string.replacingOccurrences(of: ", ", with: ",").split(separator: ",").map(String.init))
                    }
                    
                    public init(stringLiteral value: String) {
                        self.init(value)!
                    }
                    
                    public func index(after index: Int) -> Int {
                        return self.encodings.index(after: index)
                    }
                    
                    public func contains(_ value: TransferEncoding) -> Bool {
                        for encoding in self.encodings {
                            if encoding.object.rawValue == value.rawValue {
                                return true
                            }
                        }
                        return false
                    }
                    
                    public func contains(_ value: TransferEncoding.RawValue) -> Bool {
                        for encoding in self.encodings {
                            if encoding.object.rawValue == value {
                                return true
                            }
                        }
                        return false
                    }
                    
                    public static func ==(lhs: TransferEncodings, rhs: TransferEncodings) -> Bool {
                        return lhs.encodings.sameElements(as: rhs.encodings)
                    }
                    
                    public static func ~=(lhs: TransferEncodings, rhs: TransferEncodings) -> Bool {
                        guard rhs.encodings.count <= lhs.encodings.count else { return false }
                        for element in rhs.encodings {
                            if !lhs.encodings.contains(element) { return false }
                        }
                        return true
                    }
                    
                    public static func +(lhs: TransferEncodings, rhs: TransferEncodings) -> TransferEncodings {
                        var encodings: [HTTP.Headers.WeightedObject<OpenTransferEncoding>] = lhs.encodings
                        for element in rhs.encodings {
                            if !encodings.contains(where: { $0.object == element.object }) {
                                encodings.append(element)
                            }
                        }
                        return .init(encodings)
                    }
                    
                    public static func +=(lhs: inout TransferEncodings, rhs: TransferEncodings) {
                        lhs = lhs + rhs
                    }
                    
                    public static func +(lhs: TransferEncodings, rhs: TransferEncoding) -> TransferEncodings {
                        return lhs + TransferEncodings(rhs)
                    }
                    
                    public static func +=(lhs: inout TransferEncodings, rhs: TransferEncoding) {
                        lhs = lhs + rhs
                    }
                }
                
                /// Content-Type Header Value
                public typealias ContentType = HTTP.Headers.ContentType
                /// Host Header Value
                public typealias Host = HTTP.Headers.Host
                
                public typealias Index = Dictionary<HTTP.Headers.Name, String>.Index
                
                private var data: Dictionary<HTTP.Headers.Name, String>
                
                public var startIndex: Index { return self.data.startIndex }
                public var endIndex: Index { return self.data.endIndex }
                
                public init() { self.data = [:] }
                
                public init(dictionaryLiteral elements: (HTTP.Headers.Name, String)...) {
                    self.data = [:]
                    for element in elements {
                        self.data[element.0] = element.1
                    }
                }
                /// Get/Set a single value header.  This is a case insensative key
                public subscript(key: HTTP.Headers.Name) -> String? {
                    get {
                        guard let kv = self.data.first(where: { return $0.key.rawValue.caseInsensitiveCompare(key.rawValue) == .orderedSame }) else {
                            return nil
                        }
                        return kv.value
                        
                        
                        //return self.data[key]
                    }
                    set {
                        if let k = self.data.keys.first(where: { return $0.rawValue.caseInsensitiveCompare(key.rawValue) == .orderedSame }) {
                            self.data[k] = newValue
                        } else {
                            self.data[key] = newValue
                        }
                        
                    }
                }
                
                public subscript(position: Index) -> (key: HTTP.Headers.Name, value: String) {
                    return self.data[position]
                }
                
                public func index(after i: Index) -> Index {
                    return self.data.index(after: i)
                }
                /// Get the header cookies
                public var cookies: Cookies {
                    get {
                        guard let rtn = Cookies(self[.cookie]) else {
                            return Cookies()
                        }
                        return rtn
                    }
                    set {
                        let string = newValue.string
                        guard !string.isEmpty else {
                            self[.cookie] = nil
                            return
                        }
                        self[.cookie] = string
                    }
                }
                /// Get the header transfer encodings
                public var transferEncodings: TransferEncodings {
                    get {
                        return TransferEncodings(self[.transferEncoding]) ?? TransferEncodings()
                    }
                    set {
                        guard newValue.count > 0 else {
                            self[.transferEncoding] = nil
                            return
                        }
                        self[.transferEncoding] = newValue.description
                    }
                }
                /// Get the header acceptable transfer encodings
                public var acceptEncodings: TransferEncodings? {
                    get {
                        guard let val = self[.acceptEncoding] else { return nil }
                        return TransferEncodings(val)
                    }
                    set {
                        self[.acceptEncoding] = newValue?.description
                    }
                }
                /// Get the header accpetable Content-Types
                public var accept: [HTTP.Headers.ContentType]? {
                    get {
                        guard let val = self[.accept] else { return nil }
                        let ary = val.split(separator: ",").compactMap(HTTP.Headers.ContentType.init)
                        guard ary.count > 0 else { return nil }
                        return ary
        
                    }
                    set {
                        let str = newValue?.map({ return $0.description }).joined(separator: ",") ?? ""
                        if str.isEmpty { self[.accept] = nil }
                        else { self[.accept] = str }
                    }
                }
                /// Get the header acceptable Languages
                public var acceptLanguages: [HTTP.Headers.WeightedAcceptLanguage]? {
                    get {
                        guard let val = self[.acceptLanguage] else { return nil }
                        return val.split(separator: ",").compactMap(HTTP.Headers.WeightedAcceptLanguage.init).sorted()
                    }
                    set {
                        self[.acceptLanguage] = newValue?.map({ return $0.rawValue }).joined(separator: ",")
                    }
                }
                /// Get the header User-Agent
                public var userAgent: String? {
                    get { return self[.userAgent] }
                    set { self[.userAgent] = newValue }
                }
                /// Get the header if-Modified-Since
                public var ifModifiedSince: Date? {
                    get {
                        guard let val = self[.ifModifiedSince] else { return nil }
                        return LittleWebServer.dateHeaderFormatter.date(from: val)
                    }
                    set {
                        if let newVal = newValue {
                            self[.ifModifiedSince] = LittleWebServer.dateHeaderFormatter.string(from: newVal)
                        } else {
                            self[.ifModifiedSince] = nil
                        }
                    }
                }
                /// Get the header if-Unmodified-Since
                public var ifUnmodifiedSince: Date? {
                    get {
                        guard let val = self[.ifUnmodifiedSince] else { return nil }
                        return LittleWebServer.dateHeaderFormatter.date(from: val)
                    }
                    set {
                        if let newVal = newValue {
                            self[.ifUnmodifiedSince] = LittleWebServer.dateHeaderFormatter.string(from: newVal)
                        } else {
                            self[.ifUnmodifiedSince] = nil
                        }
                    }
                }
                /// Get the header if-Match
                public var ifMatch: String? {
                    get { return self[.ifMatch] }
                    set { self[.ifMatch] = newValue }
                }
                /// Get the header if-Not-Match
                public var ifNoneMatch: String? {
                    get { return self[.ifNoneMatch] }
                    set { self[.ifNoneMatch] = newValue }
                }
                /// Get the header if-Range
                public var ifRange: String? {
                    get { return self[.ifRange] }
                    set { self[.ifRange] = newValue }
                }
                /// Get the header if-Range Date
                public var ifRangeDate: Date? {
                    get {
                        guard let val = self.ifRange else { return nil }
                        return LittleWebServer.dateHeaderFormatter.date(from: val)
                    }
                    set {
                        if let newVal = newValue {
                            self.ifRange = LittleWebServer.dateHeaderFormatter.string(from: newVal)
                        } else {
                            self.ifRange = nil
                        }
                    }
                }
                
            }
            
            /// Reference to a form post file
            public struct UploadedFileReference {
                /// The form path of the file that was posted
                public let path: String
                /// The local location of the file that was posted
                public let location: URL
                /// The content type repotrted of the file that was posted
                public let contentType: HTTP.Headers.ContentType?
            }
            /// The protocol scheme
            public let scheme: String
            /// The HTTP Method for the request
            public let method: Method
            /// THe HTTP Path requested
            public let contextPath: String
            /// The HTTP URL Query Parameters
            public let urlQuery: String?
            /// The HTTP Request version
            public let version: Version
            /// Any HTTP Request Headers
            public let headers: Headers
            /// HTTP Request Query Items (From context path and form post)
            public let queryItems: [URLQueryItem]
            /// HTTP Form Post files
            public let uploadedFiles: [UploadedFileReference]
            /// The request input stream
            public let inputStream: LittleWebServerInputStream
            /// The session for the request
            private var session: LittleWebServerSession?
            
            private var _isNewSession: Bool
            /// Indicator if this is a new session
            internal var isNewSession: Bool {
                if let req = self.originalRequest {
                    return req.isNewSession
                } else {
                    return self._isNewSession
                }
            }
            
            /// The original request if the current request isn't it
            public let originalRequest: Request?
            
            /// Path identities
            public internal(set) var identities: [String: Any] = [:]
            /// Property Transformations.  Any property that was required
            /// to be transformed into a different object type
            public internal(set) var propertyTransformations: [String: Any] = [:]
            
            /// Gets the absolute URL String of the request
            public var fullPath: String {
                var rtn: String = scheme + "://"
                if let h = self.headers.host {
                    rtn += h.name
                    if let p = h.port,
                       !(h.port == Int(LittleWebServerDefaultSchemePort.default(for: self.scheme)?.port ?? 0)) {
                        rtn += ":\(p)"
                    }
                }
                rtn += self.contextPath
                if let q = self.urlQuery {
                    rtn += "?" + q
                }
                
                return rtn
            }
            /*
            /// Gets the URL Query String
            public var urlQuery: String? {
                guard !self.queryItems.isEmpty else { return nil }
                var rtn: String = ""
                for q in self.queryItems {
                    if !rtn.isEmpty { rtn += "&" }
                    rtn += q.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q.name
                    rtn += "="
                    if let v = q.value {
                        rtn += (v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v)
                    }
                }
                return rtn
            }
            */
            
            private var urlQueryItems: [URLQueryItem] {
                guard let uq = self.urlQuery else { return [] }
                return Array<URLQueryItem>(urlQuery: uq)
                
            }
            public var bodyQuery: String? {
                guard !self.queryItems.isEmpty else { return nil }
                let urlQueryItems = self.urlQueryItems
                var rtn: String = ""
                for q in self.queryItems {
                    // If the current query Item is in the urlQueryItems
                    // then we skip it because it came from the URL not the body
                    guard !urlQueryItems.contains(q) else {
                        continue
                    }
                    if !rtn.isEmpty { rtn += "&" }
                    rtn += q.name + "="
                    if let v = q.value {
                        rtn += v.replacingOccurrences(of: " ", with: "+")
                    }
                }
                return rtn
            }
            
            internal var string: String {
                var rtn: String = "\(self.method.rawValue) \(self.contextPath)"
                
                if let q = self.urlQuery {
                    rtn += "?" + q
                }
                
                rtn += " \(self.version.httpRespnseValue)\r\n"
                
                rtn += self.headers.http1xContent
                
                if self.headers.contentType == .urlEncodedForm,
                   let q = self.bodyQuery {
                    rtn += "\r\n\r\n" + q
                }
                
                return rtn
                
            }
            
            internal var rawValue: Data {
                var rtn = Data()
                let req = self.string
                rtn.append(req.data(using: .utf8)!)
                
                if self.headers.contentType == .urlEncodedForm,
                   let q = self.bodyQuery {
                    
                    rtn.append(LittleWebServer.CRLF_DATA)
                    
                    let enc = self.headers.contentType?.characterEncoding ?? .utf8
                    let dta = q.data(using: enc)!
                    //if !self.isChunked {
                        rtn.append(dta)
                        rtn.append(LittleWebServer.CRLF_DATA)
                    //} else {
                        let hexSize = String(dta.count, radix: 16)
                        rtn.append(hexSize.data(using: .utf8)!)
                        rtn.append(LittleWebServer.CRLF_DATA)
                        rtn.append("0".data(using: .utf8)!)
                        rtn.append(LittleWebServer.CRLF_DATA)
                    //}
                } else if self.headers.contentType == .multiPartForm {
                    rtn.append(LittleWebServer.CRLF_DATA)
                }
                
                rtn.append(LittleWebServer.CRLF_DATA)
                return rtn
            }
            
            /// Indicator if the response has Chunked body data
            public var isChunked: Bool {
                return self.headers.transferEncodings.contains(.chunked)
            }
            /// Returns the body content legnth IF the reponse is not chunked
            public var contentLength: UInt? {
                return self.headers.contentLength
            }
            public var contentType: HTTP.Headers.ContentType? {
                return self.headers.contentType
            }
            
            public var description: String { return self.string }
            
            /// Create a new Request Object
            /// - Parameters:
            ///   - scheme: The request scheme
            ///   - method: The request method
            ///   - contextPath: The request context path
            ///   - urlQuery: The request url Query
            ///   - version: The request HTTP version
            ///   - headers: The request HTTP Headers
            ///   - queryItems: The request Query Items
            ///   - uploadedFiles: Any Request Form Post file references
            ///   - inputStream: The request input stream
            internal init(scheme: String,
                          method: Method,
                          contextPath: String,
                          urlQuery: String?,
                          version: Version,
                          headers: Headers,
                          queryItems: [URLQueryItem],
                          uploadedFiles: [UploadedFileReference] = [],
                          inputStream: LittleWebServerInputStream = LittleWebServerEmptyInputStream()) {
                self.scheme = scheme
                self.method = method
                self.contextPath = contextPath
                self.urlQuery = urlQuery
                self.version = version
                self.headers = headers
                self.queryItems = queryItems
                self.uploadedFiles = uploadedFiles
                self.inputStream = inputStream
                self.originalRequest = nil
                self.session = nil
                self._isNewSession = true
                //self.server = server
            }
            
            /// Create a new request based on an existing request
            /// - Parameters:
            ///   - originalRequest: The original request this request is based on
            ///   - method: The new HTTP method (Default: Use existing)
            ///   - contextPath: The new context path (Default: Use existing)
            ///   - urlQuery: The new url query items (Default: Use existing)
            ///   - headers: The new HTTP Headers (Default: Use existing)
            ///   - queryItems: The new URLQuery Items (Default: Use existing)
            public init(_ originalRequest: Request,
                        newMethod method: Method? = nil,
                        newContextPath contextPath: String? = nil,
                        newUrlQuery urlQuery: String? = nil,
                        newHeaders headers: Headers? = nil,
                        newQueryItem queryItems: [URLQueryItem]? = nil) {
                self.scheme = originalRequest.scheme
                self.method = method ?? originalRequest.method
                self.contextPath = contextPath ?? originalRequest.contextPath
                self.urlQuery = urlQuery ?? originalRequest.urlQuery
                self.version = originalRequest.version
                self.headers = headers ?? originalRequest.headers
                self.queryItems = queryItems ?? originalRequest.queryItems
                self.uploadedFiles = originalRequest.uploadedFiles
                self.inputStream = originalRequest.inputStream
                self.identities = originalRequest.identities
                self.propertyTransformations = originalRequest.propertyTransformations
                self.originalRequest = originalRequest
                self.session = originalRequest.session
                self._isNewSession = originalRequest.isNewSession
            }
            
            /// Get the session for the current request
            /// - Parameter create: Indicator if a session should be created if not already exists
            /// - Returns: Returns the session for the given request if one exists or was created otherwise nil
            public func getSession(_ create: Bool = true) -> LittleWebServerSession? {
                if let rq = self.originalRequest {
                    return rq.getSession(create)
                } else {
                    if self.session == nil && create {
                        //guard let server = Thread.current.currentLittleWebServer else {
                        guard let server = Thread.current.littleWebServerDetails.webServer else {
                            return nil
                        }
                        
                        if let s = server.sessionManager.findSession(withIds: self.headers.cookies.sessionIds) {
                            self.session = s
                            self._isNewSession = false
                        } else {
                            self.session = server.sessionManager.createSession()
                            self._isNewSession = true
                        }
                    }
                    return self.session
                }
            }
            
            /// Invalidates the current session and removes all data associated with it
            public func invalidateSession() {
                if let req = self.originalRequest {
                    req.invalidateSession()
                } else if let s = self.session {
                    //if let server = Thread.current.currentLittleWebServer {
                    if let server = Thread.current.littleWebServerDetails.webServer {
                        server.sessionManager.removeSession(s)
                    }
                }
            }
            /// Get the first value of a query item with the given name
            public func queryParameter(for name: String) -> String? {
                guard let q = self.queryItems.first(where: { return $0.name == name }) else {
                    return nil
                }
                return q.value
            }
            /// Get all values for a query item with the given name
            public func queryParameters(for name: String) -> [String] {
                var rtn: [String] = []
                for q in self.queryItems {
                    if q.name == name && q.value != nil {
                        rtn.append(q.value!)
                    }
                }
                return rtn
            }
            
            
            /// Parse a request
            /// - Parameters:
            ///   - scheme: The HTTP Request Scheme
            ///   - head: The HTTP Request Head Line
            ///   - headers: The HTTP Request Headers
            ///   - bodyStream: The HTTP Request  Body Input Stream
            ///   - uploadedFiles: Refernece to any form post files that were parsed
            ///   - tempLocation: The location to save uplaoded files
            /// - Returns: Returns a new HTTP Request
            internal static func parse(scheme: String,
                                       head: Head,
                                       headers: Headers,
                                       bodyStream: _LittleWebServerInputStream,
                                       uploadedFiles: inout  [UploadedFileReference],
                                       tempLocation: URL) throws -> Request {
                var queryItems = head.queryItems
                //let headers = try client.readRequestHeaders()
                //let uploadedFiles: [UploadedFileReference] = []
                
                
                // Parse form post here
                if headers.contentType ~= .urlEncodedForm {
                    let queryString: String
                    if let ctl = headers.contentLength {
                        let dta = try bodyStream.read(exactly: Int(ctl))
                        let enc = headers.contentType?.characterEncoding ?? .utf8
                        guard var s = String(data: dta, encoding: enc) else {
                            throw Error.unableToDecodeBodyParameters
                        }
                        while s.hasSuffix("\r\n") { s.removeLast(2) }
                        queryString = s
                    } else {
                        var dta = Data()
                        while !dta.hasSuffix(LittleWebServer.CRLF_DATA) {
                            let b = try bodyStream.readByte()
                            dta.append(b)
                        }
                        
                        let enc = headers.contentType?.characterEncoding ?? .utf8
                        guard let s = String(data: dta, encoding: enc) else {
                            throw Error.unableToDecodeBodyParameters
                        }
                        queryString = s
                    }
                    
                    let qItems = queryString.split(separator: "&").map(String.init)
                    for qItem in qItems {
                        guard let r = qItem.range(of: "=") else {
                            queryItems.append(URLQueryItem(name: qItem, value: ""))
                            continue
                        }
                        
                        let qName = String(qItem[qItem.startIndex..<r.lowerBound])
                        let qValue: String = String(qItem[r.upperBound..<qItem.endIndex])
                        
                        queryItems.append(URLQueryItem(name: qName, value: qValue.replacingOccurrences(of: "+", with: " ")))
                        
                    }
                /*} else if let boundary = headers.contentType?.multiPartBoundary,
                          headers.contentType?.mediaType == .multiPartForm {*/
                    } else if headers.contentType ~= .multiPartForm,
                              let boundary = headers.contentType?.multiPartBoundary {
                    
                    let expectedBoundaryIdentifier = "--" + boundary
                    
                    var boundaryLine = try bodyStream.readUTF8Line()
                    guard boundaryLine == expectedBoundaryIdentifier else {
                        throw Error.unableToFindBoundaryIdentifier(boundary)
                    }
                    let boundaryLineBytes = Array(expectedBoundaryIdentifier.utf8)
                    
                    func processRestOfPartBlock(_ onReadBytes: ([UInt8]) throws -> Void = { _ in return }) throws {
                        
                        func matchingSequence(lookingAt: [UInt8], lookingFor: [UInt8]) -> Int? {
                            precondition(lookingAt.count == lookingFor.count,
                                         "Arrays must be same size")
                            
                            
                            guard lookingAt != lookingFor else { return nil }
                            
                            guard let firstByteIndex = lookingAt.firstIndex(of: lookingFor[0]) else {
                                return lookingAt.count
                            }
                            
                            guard lookingAt.count > 1 else {
                                // if we are down to one byte and they didn't match, then
                                // we report we need to replace it
                                return 1
                            }
                            
                            let innerAt = Array(lookingAt.suffix(from: firstByteIndex + 1))
                            
                            let innerFor = Array(lookingFor[0..<innerAt.count])
                            
                            let subCount = matchingSequence(lookingAt: innerAt, lookingFor: innerFor)
                            
                            let rtn = firstByteIndex + (subCount ?? 0)
                            guard rtn != 0 else {
                                return nil
                            }
                            
                            return rtn
                            
                        }
                        //try autoreleasepool {
                            var buffer = Array<UInt8>(repeating: 0, count: boundaryLineBytes.count)
                            try bodyStream.read(&buffer, exactly: buffer.count)
                            
                        
                            
                            // In the end this should old the \r\n from the end of the bock
                            var lastTwoBytes = Array<UInt8>(repeating: 0, count: 2)
                            var lastTwoBytesSet: Bool = false
                            while let needToRead = matchingSequence(lookingAt: buffer,
                                                                    lookingFor: boundaryLineBytes) {
                                if lastTwoBytesSet {
                                    try onReadBytes(lastTwoBytes)
                                }
                                if needToRead < buffer.count {
                                    try onReadBytes(Array(buffer[0..<needToRead-2]))
                                    lastTwoBytes = Array(buffer[(needToRead-2)..<needToRead])
                                    for i in needToRead..<buffer.count {
                                        buffer[i - needToRead] = buffer[i]
                                    }
                                    for i in (buffer.count - needToRead)..<buffer.count {
                                        buffer[i] = 0
                                    }
                                    try bodyStream.read(&buffer[(buffer.count - needToRead)], exactly: needToRead)
                                    
                                } else {
                                    try onReadBytes(Array(buffer[0..<buffer.count-2]))
                                    lastTwoBytes = Array(buffer.suffix(2))
                                    
                                    try bodyStream.read(&buffer, exactly: buffer.count)
                                    
                                    
                                }
                                lastTwoBytesSet = true
                                
                            }
                            /*
                            /*var outerBuffer = Array<UInt8>(repeating: 0, count: 2)
                            var outCount: Int = 0*/
                            while buffer != boundaryLineBytes {
                                /*outCount += 1
                                if outCount > 2 {
                                    try onByteRead(outerBuffer[0])
                                }
                                outerBuffer[0] = outerBuffer[1]
                                outerBuffer[1] = buffer[0]*/
                                try onByteRead(buffer[0])
                                for i in 1..<buffer.count {
                                    
                                    buffer[i-1] = buffer[i] // shift everything to the left one byte
                                }
                                // Read next byte
                                let ret = try bodyStream.readBuffer(into: &buffer[buffer.count - 1], count: 1)
                                guard ret == 1 else {
                                    throw Error.noMoreDataAvailableInStream
                                }
                            }
                            */
                            // signal last bytes of block
                            /*for i in 0..<outerBuffer.count {
                                try onByteRead(outerBuffer[i])
                            }*/
                            
                            var wasEndBoundary: Bool = false
                            var trail = try bodyStream.read(exactly: 2) // trying to read either -- or \r\n
                            if trail == Data(Array("--".utf8)) {
                                wasEndBoundary = true
                                trail = try bodyStream.read(exactly: 2) // trying to read \r\n
                            }
                            
                            guard trail == LittleWebServer.CRLF_DATA else {
                                throw Error.unexpectedDataAfterBoundary(trail, wasEndBoundary: wasEndBoundary)
                            }
                            
                        //}
                        
                    }
                    
                    
                    while boundaryLine == expectedBoundaryIdentifier &&
                          !(bodyStream.endOfStream ?? false) {
                        try autoreleasepool {
                            let contentDispositionString = try bodyStream.readUTF8Line()
                            
                            guard let contentDisposition = HTTP.Headers.ContentDisposition(contentDispositionString) else {
                                throw Error.invalidContentDispositionLine(contentDispositionString)
                            }
                            var partContentType: HTTP.Headers.ContentType? = nil
                            var nextLine = try bodyStream.readUTF8Line()
                            while !nextLine.isEmpty {
                                if nextLine.hasPrefix("Content-Type: ") {
                                    nextLine.removeFirst("Content-Type: ".count)
                                    partContentType = HTTP.Headers.ContentType(nextLine)
                                    nextLine = try bodyStream.readUTF8Line()
                                }
                            }
                            /*// Read new line
                            guard nextLine.isEmpty else {
                                throw Error.expectingNewLine(found: bytes)
                            }*/
                            
                            if contentDisposition.type == .formData {
                                if contentDisposition.filename == nil &&
                                   contentDisposition.filenameB == nil {
                                    var fieldValue: String = ""
                                    var currentLine = try bodyStream.readUTF8Line()
                                    while currentLine != expectedBoundaryIdentifier &&
                                          currentLine != "\(expectedBoundaryIdentifier)--" &&
                                          !(bodyStream.endOfStream ?? false) {
                                        if !fieldValue.isEmpty { fieldValue += "\n" }
                                        fieldValue += currentLine
                                        currentLine = try bodyStream.readUTF8Line()
                                    }
                                    boundaryLine = currentLine
                                } else if let filePath = (contentDisposition.filenameB ?? contentDisposition.filename) {
                                    let fileURL = tempLocation.appendingPathComponent(UUID().uuidString)
                                    guard FileManager.default.createFile(atPath: fileURL.path, contents: nil) else {
                                        throw Error.unableToCreateFile(fileURL)
                                    }
                                    let fileHandle = try FileHandle(forWritingTo: fileURL)
                                    
                                    uploadedFiles.append(.init(path: filePath,
                                                               location: fileURL,
                                                               contentType: partContentType))
                                    var removeFile: Bool = false
                                    defer {
                                        try? fileHandle.closeHandle()
                                        if removeFile {
                                            try? FileManager.default.removeItem(at: fileURL)
                                        }
                                    }
                                    
                                    do {
                                        // Copy each byte processed into the file
                                        try processRestOfPartBlock {
                                            try fileHandle.write($0, count: $0.count)
                                        }
                                    } catch {
                                        removeFile = true
                                        throw error
                                    }
                                    
                                    
                                    //print("Processed file '\(fileURL.path)'")
                                    
                                    
                                }
                                
                            
                            } else {
                                
                                // Skipping over this part since we don't know how to handle it
                                try processRestOfPartBlock()
                                
                            }
                            
                        }
                        
                        
                    }
                    
                    
                }
                
                let usableInputStream: LittleWebServerInputStream = bodyStream
                
                /*if ["GET", "DELETE", "TRACE", "OPTIONS", "HEAD"].contains(head.method.rawValue.uppercased()) {
                    usableInputStream = LittleWebServerEmptyInputStream()
                }*/
                
                return .init(scheme: scheme,
                             method: head.method,
                             contextPath: head.contextPath,
                             urlQuery: head.query,
                             version: head.version,
                             headers: headers,
                             queryItems: queryItems,
                             uploadedFiles: uploadedFiles,
                             inputStream: usableInputStream)
                
            }
            
        }
        
        public class Response {
            /// Transfer-Encoding Header Value
            public typealias TransferEncoding = HTTP.Headers.TransferEncoding
            /// Content-Type Header Value
            public typealias ContentType = HTTP.Headers.ContentType
            /// Host Header Value
            public typealias Host = HTTP.Headers.Host
            
            /// The option used to indicate which worker queue to use when processing the response
            public enum ProcessQueue {
                /// Process the response on the main request/response processing queue
                case current
                /// Process the response on a different queue
                case other(AnyHashable)
                
                /// Process the resposne on the WebSocket queue (.other("websocket"))
                public static var websocket: ProcessQueue { return .other("websocket") }
                /// Indicator if this queue is .current
                internal var isCurrent: Bool {
                    guard case .current = self else { return false }
                    return true
                }
                /// Worker queue used by the Communicator
                internal var workerQueue: LittleWebServer.WorkerQueue {
                    switch self {
                        case .current: return .request
                        //case .websocket: return .websocket
                        case .other(let obj): return .other(obj)
                    }
                }
                
            }
            /// The HTTP Resposne Head (Status and Headers)
            public struct Head {
                /// HTTP Resposne Code
                public let responseCode: Int
                /// HTTP Response Message
                public let message: String?
                /// HTTP Response Headers
                public var headers: Headers
                
                /// Create a new HTTP Response Head
                /// - Parameters:
                ///   - responseCode: HTTP Resposne Code
                ///   - message: HTTP Response Message
                ///   - headers: HTTP Response Headers
                public init(responseCode: Int,
                            message: String,
                            headers: Headers = .init()) {
                    self.responseCode = responseCode
                    self.message = message
                    self.headers = headers
                }
            }
            /// HTTP Resposne Headers
            public struct Headers: _LittleWebServerCommonHeaders {
                public typealias HeaderValue = [String]
                /*
                /// HTTP Response Header Value
                public enum HeaderValue {
                    case value(String)
                    case array([String])
                    
                    internal var values: [String] {
                        switch self {
                            case .value(let rtn): return [rtn]
                            case .array(let rtn): return rtn
                        }
                    }
                    
                    internal var stringValue: String? {
                        guard case .value(let rtn) = self else { return nil }
                        return rtn
                    }
                    
                    internal var arrayValue: [String]? {
                        guard case .array(let rtn) = self else { return nil }
                        return rtn
                    }
                    
                    public init<N>(_ numeric: N) where N: Numeric {
                        self = .value("\(numeric)")
                    }
                    public init(_ bool: Bool) {
                        self = .value("\(bool)")
                    }
                    public init(gmtDate: Date) {
                        self = .value(LittleWebServer.dateHeaderFormatter.string(from: gmtDate))
                    }
                    public init?<S>(_ string: S?) where S: StringProtocol {
                        guard let s = string else { return nil }
                        let string = (s as? String) ?? String(s)
                        self = .value(string)
                    }
                    public init?<SC>(_ strings: SC?) where SC: Collection, SC.Element: StringProtocol {
                        guard let strings = strings else { return nil }
                        guard strings.count > 0 else { return nil }
                        let array = (strings as? [String]) ?? strings.map({ return String($0) })
                        self = .array(array)
                    }
                }
                */
                public typealias ContentEncoding = Helpers.OpenEquatableEnum<HTTP.Headers.ContentEncoding>
                
                public struct TransferEncodings: Equatable,
                                                 Collection,
                                                 LittleWebServerStructCustomStringHashable,
                                                 LittleWebServerExpressibleByStringInterpolation {
                    
                    
                    public typealias TransferEncoding = HTTP.Headers.TransferEncoding
                    
                    private let encodings: [TransferEncoding]
                    
                    public var description: String {
                        return self.encodings.map({ return $0.rawValue }).joined(separator: ", ")
                    }
                    
                    public var startIndex: Int { return self.encodings.startIndex }
                    public var endIndex: Int { return self.encodings.endIndex }
                    public subscript(index: Int) -> TransferEncoding {
                        get { return self.encodings[index] }
                    }
                    
                    public init(_ values: [TransferEncoding] = []) {
                        if values.count > 1 {
                            for i in 0..<(values.count-1) {
                                for x in (i+1)..<values.count {
                                    if values[i] == values[x] {
                                        preconditionFailure("Duplicate TransferEncoding ('\(values[x])') found at \(i) and \(x)")
                                    }
                                }
                            }
                        }
                        self.encodings = values
                    }
                    public init(_ value: [String]) {
                        self.init(value.compactMap(TransferEncoding.init(rawValue:)))
                    }
                    
                    public init?<S>(_ value: S?) where S: StringProtocol {
                        guard let value = value else { return nil }
                        let string = (value as? String) ?? String(value)
                        
                        self.init(string.replacingOccurrences(of: ", ", with: ",").split(separator: ",").map(String.init))
                    }
                    
                    public init(stringLiteral value: String) {
                        self.init(value)!
                    }
                    
                    public func index(after index: Int) -> Int {
                        return self.encodings.index(after: index)
                    }
                    
                    public func contains(_ value: TransferEncoding) -> Bool {
                        for encoding in self.encodings {
                            if encoding == value {
                                return true
                            }
                        }
                        return false
                    }
                    
                    public static func ==(lhs: TransferEncodings, rhs: TransferEncodings) -> Bool {
                        return lhs.encodings.sameElements(as: rhs.encodings)
                    }
                    
                    public static func ~=(lhs: TransferEncodings, rhs: TransferEncodings) -> Bool {
                        guard rhs.encodings.count <= lhs.encodings.count else { return false }
                        for element in rhs.encodings {
                            if !lhs.encodings.contains(element) { return false }
                        }
                        return true
                    }
                    
                    public static func +(lhs: TransferEncodings, rhs: TransferEncodings) -> TransferEncodings {
                        var encodings: [TransferEncoding] = lhs.encodings
                        for element in rhs.encodings {
                            if !encodings.contains(where: { $0 == element }) {
                                encodings.append(element)
                            }
                        }
                        return .init(encodings)
                    }
                    
                    public static func +=(lhs: inout TransferEncodings, rhs: TransferEncodings) {
                        lhs = lhs + rhs
                    }
                    
                    public static func +(lhs: TransferEncodings, rhs: TransferEncoding) -> TransferEncodings {
                        return lhs + TransferEncodings([rhs])
                    }
                    
                    public static func +=(lhs: inout TransferEncodings, rhs: TransferEncoding) {
                        lhs = lhs + rhs
                    }
                }
                
                public struct Cookies: Collection {
                    public struct Cookie: CustomStringConvertible {
                        public enum SameSite: String {
                            case strict = "Strict"
                            case lax = "Lax"
                            case none = "none"
                            
                            public init?(rawValue: String) {
                                switch rawValue.lowercased() {
                                    case "strict": self = .strict
                                    case "lax": self = .lax
                                    case "none": self = .none
                                    default: return nil
                                }
                            }
                        }
                        public let name: String
                        public let value: String
                        public let comment: String?
                        public let expires: Date?
                        public let maxAge: Int?
                        public let domain: HTTP.Headers.Host.Name?
                        public let path: String?
                        public let sameSite: SameSite?
                        public let version: Int?
                        public let secure: Bool
                        public let httpOnly: Bool
                        
                        public var string: String {
                            var rtn: String = "\(self.name)=\(self.value)"
                            if let c = self.comment {
                                if c.hasPrefix("\"") && c.hasSuffix("\"") {
                                    rtn += "; Comment=\(c)"
                                } else {
                                    rtn += "; Comment=\"\(c)\""
                                }
                            }
                            if let exp = self.expires {
                                rtn += "; Expires=\(LittleWebServer.dateHeaderFormatter.string(from: exp))"
                            }
                            if let mxA = self.maxAge {
                                rtn += "; Max-Age=\(mxA)"
                            }
                            if let dm = self.domain {
                                rtn += "; Domain=\(dm.description)"
                            }
                            if let p = self.path {
                                rtn += "; Path=\(p)"
                            }
                            if let ss = self.sameSite {
                                rtn += "; SameSite=\(ss.rawValue)"
                            }
                            if let v = self.version {
                                rtn += "; Version=\(v)"
                            }
                            if self.secure {
                                rtn += "; Secure"
                            }
                            if self.httpOnly {
                                rtn += "; HttpOnly"
                            }
                            return rtn
                        }
                        
                        public var description: String { return self.string }
                        
                        public init(name: String, value: String, comment: String? = nil,
                                    expires: Date? = nil,
                                    maxAge: Int? = nil, domain: HTTP.Headers.Host.Name? = nil,
                                    path: String? = nil, sameSite: SameSite? = nil,
                                    version: Int? = nil,
                                    secure: Bool = false, httpOnly: Bool = false) {
                            self.name = name
                            self.value = value
                            self.comment = comment
                            self.expires = expires
                            self.maxAge = maxAge
                            self.domain = domain
                            self.path = path
                            self.sameSite = sameSite
                            self.version = version
                            var sec: Bool = secure
                            if let ss = sameSite,
                                ss == .none {
                                sec = true
                            }
                            self.secure = sec
                            self.httpOnly = httpOnly
                            
                        }
                        
                        public init(sessionId: String, comment: String? = nil,
                                    expires: Date? = nil,
                                    maxAge: Int? = nil, domain: HTTP.Headers.Host.Name? = nil,
                                    path: String? = nil, sameSite: SameSite? = nil,
                                    version: Int? = nil, secure: Bool = false,
                                    httpOnly: Bool = false) {
                            self.init(name: LittleWebServer.HTTP.Headers.SessionId,
                                      value: sessionId,
                                      comment: comment,
                                      expires: expires,
                                      maxAge: maxAge,
                                      domain: domain,
                                      path: path,
                                      sameSite: sameSite,
                                      version: version,
                                      secure: secure,
                                      httpOnly: httpOnly)
                        }
                        
                        public init(expiredSessionId sessionId: String,
                                    comment: String? = nil,
                                    domain: HTTP.Headers.Host.Name? = nil,
                                    path: String? = nil, sameSite: SameSite? = nil,
                                    version: Int? = nil,
                                    secure: Bool = false, httpOnly: Bool = false) {
                            self.init(name: LittleWebServer.HTTP.Headers.SessionId,
                                      value: sessionId,
                                      comment: comment,
                                      expires: Date.yesterday,
                                      maxAge: -1,
                                      domain: domain,
                                      path: path,
                                      sameSite: sameSite,
                                      version: version,
                                      secure: secure,
                                      httpOnly: httpOnly)
                        }
                        
                        public init?<S>(_ string: S?) where S: StringProtocol {
                            guard let string = string else { return nil }
                            let s = (string as? String) ?? String(string)
                           
                            guard !s.isEmpty else { return nil }
                            let components = s.replacingOccurrences(of: "; ", with: ";").split(separator: ";")
                            var values: [[String]] = []
                            for component in components {
                                values.append(component.splitFirst(separator: "=").map(String.init))
                            }
                            guard values.count > 0 else {
                                return nil
                            }
                            let keyNames: [String] = ["comment",
                                                      "expires",
                                                      "max-age",
                                                      "domain",
                                                      "path",
                                                      "samesite",
                                                      "version",
                                                      "secure",
                                                      "httponly"]
                            guard values[0].count == 2 else {
                                debugPrint("Invalid cookie name/value in '\(components[0])' from '\(s)'")
                                return nil
                            }
                            guard !keyNames.contains(values[0][0].lowercased()) else {
                                debugPrint("Cookie name '\(values[0][0])' can not be used as its a reserved property name")
                                return nil
                            }
                            
                            let sName = values[0][0]
                            let sValue = values[0][1]
                            values.removeFirst()
                            
                            var comment: String? = nil
                            var expires: Date? = nil
                            var maxAge: Int? = nil
                            var domain: HTTP.Headers.Host.Name? = nil
                            var path: String? = nil
                            var sameSite: SameSite? = nil
                            var version: Int? = nil
                            var secure: Bool = false
                            var httpOnly: Bool = false
                            
                            
                            
                            for prop in values {
                                let propNameLowered = prop[0].lowercased()
                                switch propNameLowered {
                                    case "comment":
                                        guard prop.count == 2 else {
                                            debugPrint("Missing Comment property value")
                                            return nil
                                        }
                                        var val = prop[1]
                                        if val.hasPrefix("\"") && val.hasSuffix("\"") {
                                            val.removeFirst()
                                            val.removeLast()
                                        } else if val.hasPrefix("'") && val.hasSuffix("'") {
                                            val.removeFirst()
                                            val.removeLast()
                                        }
                                        
                                        comment = val
                                    case "expires":
                                        guard prop.count == 2 else {
                                            debugPrint("Missing Expires property value")
                                            return nil
                                        }
                                        guard let val = LittleWebServer.dateHeaderFormatter.date(from: prop[1]) else {
                                            debugPrint("Invalid Expires date '\(prop[1])'")
                                            return nil
                                        }
                                        expires = val
                                    case "max-age":
                                        guard prop.count == 2 else {
                                            debugPrint("Missing Max-Age property value")
                                            return nil
                                        }
                                        guard let val = Int(prop[1]) else {
                                            debugPrint("Invalid Max-Age value '\(prop[1])'")
                                            return nil
                                        }
                                        maxAge = val
                                    case "domain":
                                        guard prop.count == 2 else {
                                            debugPrint("Missing Domain property value")
                                            return nil
                                        }
                                        guard !prop[1].isEmpty else {
                                            debugPrint("Invalid Domain value '\(prop[1])'")
                                            return nil
                                        }
                                        domain = HTTP.Headers.Host.Name(prop[1])
                                    case "path":
                                        guard prop.count == 2 else {
                                            debugPrint("Missing Path property value")
                                            return nil
                                        }
                                        guard !prop[1].isEmpty else {
                                            debugPrint("Invalid Path value '\(prop[1])'")
                                            return nil
                                        }
                                        path = prop[1]
                                    case "samesite":
                                        guard prop.count == 2 else {
                                            debugPrint("Missing SameSite property value")
                                            return nil
                                        }
                                        guard let val = SameSite(rawValue: prop[1]) else {
                                            debugPrint("Invalid SameSite value '\(prop[1])'")
                                            return nil
                                        }
                                        sameSite = val
                                    case "version":
                                        guard prop.count == 2 else {
                                            debugPrint("Missing Version property value")
                                            return nil
                                        }
                                        guard let val = Int(prop[1]) else {
                                            debugPrint("Invalid Version value '\(prop[1])'")
                                            return nil
                                        }
                                        version = val
                                    case "secure":
                                        guard prop.count == 1 else {
                                            debugPrint("Property Secure should not have a value")
                                            return nil
                                        }
                                        secure = true
                                    case "httponly":
                                        guard prop.count == 1 else {
                                            debugPrint("Property HttpOnly should not have a value")
                                            return nil
                                        }
                                        httpOnly = true
                                    default:
                                        debugPrint("Invalid property name '\(prop[0])'")
                                        return nil
                                }
                                
                            }
                            
                            self.name = sName
                            self.value = sValue
                            self.comment = comment
                            self.expires = expires
                            self.maxAge = maxAge
                            self.domain = domain
                            self.path = path
                            self.sameSite = sameSite
                            self.version = version
                            self.secure = secure
                            self.httpOnly = httpOnly
                        }
                    }
                    
                    private var data: [Cookie] = []
                    
                    public var startIndex: Int { return self.data.startIndex }
                    public var endIndex: Int { return self.data.endIndex }
                    
                    public subscript(index: Int) -> Cookie {
                        get { return self.data[index] }
                        set { self.data[index] = newValue }
                    }
                    
                    public init() { }
                    
                    public init(_ values: [String]) {
                        for value in values {
                            if let cookie = Cookie(value) {
                                self.data.append(cookie)
                            }
                        }
                    }
                    
                    public mutating func append(_ newElement: Cookie) {
                        self.data.append(newElement)
                    }
                    
                    public func index(after index: Int) -> Int {
                        return self.data.index(after: index)
                    }
                }
                
                public typealias Index = Dictionary<HTTP.Headers.Name, HeaderValue>.Index
                
                private var data: Dictionary<HTTP.Headers.Name, HeaderValue>
                
                
                public var startIndex: Index { return self.data.startIndex }
                public var endIndex: Index { return self.data.endIndex }
                
                public init() { self.data = [:] }
                
                public init(_ headers: [(String, String)]) {
                    self.data = [:]
                    for kv in headers {
                        if let k = self.data.keys.first(where: { $0.rawValue.caseInsensitiveCompare(kv.0) == .orderedSame }),
                           let v = self.data[k] {
                            /*
                            var nv: [String] = []
                            switch v {
                                case .value(let v):
                                    nv.append(v)
                                case .array(let v):
                                    nv.append(contentsOf: v)
                            }
                            nv.append(kv.1)
                            self.data[k] = .array(nv)*/
                            self.data[k] = v.appending(kv.1)
                            
                        } else {
                            //self.data[.init(kv.0)] = .value(kv.1)
                            self.data[.init(kv.0)] = [kv.1]
                        }
                        
                    }
                }
                
                public init(dictionaryLiteral elements: (HTTP.Headers.Name, HeaderValue)...) {
                    self.data = [:]
                    for element in elements {
                        self.data[element.0] = element.1
                    }
                }
                
                public subscript(key: HTTP.Headers.Name) -> String? {
                    /*get { return self.data[key]?.stringValue  }
                    set { self.data[key] = HeaderValue(newValue) }*/
                    get {
                        guard let kv = self.data.first(where: { return $0.key.rawValue.caseInsensitiveCompare(key.rawValue) == .orderedSame }) else {
                            return nil
                        }
                        //return kv.value.stringValue
                        guard kv.value.count == 1 else { return nil }
                        return kv.value[0]
                        
                        
                        //return self.data[key]
                    }
                    set {
                        if let k = self.data.keys.first(where: { return $0.rawValue.caseInsensitiveCompare(key.rawValue) == .orderedSame }) {
                            //self.data[k] = HeaderValue(newValue)
                            if let nv = newValue {
                                self.data[k] = [nv]
                            } else {
                                self.data.removeValue(forKey: k)
                            }
                        } else {
                            //self.data[key] = HeaderValue(newValue)
                            guard let nv = newValue else { return }
                            self.data[key] = [nv]
                        }
                        
                    }
                }
                
                public subscript(position: Index) -> (key: HTTP.Headers.Name, value: HeaderValue) {
                    return self.data[position]
                }
                
                public func index(after i: Index) -> Index {
                    return self.data.index(after: i)
                }
                
                public var transferEncodings: TransferEncodings {
                    get {
                        return TransferEncodings(self[.transferEncoding]) ?? TransferEncodings()
                    }
                    set {
                        guard newValue.count > 0 else {
                            self[.transferEncoding] = nil
                            return
                        }
                        self[.transferEncoding] = newValue.description
                    }
                }
                
                public var contentEncoding: ContentEncoding? {
                    get {
                        guard let v = self[.contentEncoding] else { return nil }
                        return ContentEncoding(rawValue: v)
                    }
                    set {
                        guard let nv = newValue else {
                            self[.contentEncoding] = nil
                            return
                        }
                        self[.contentEncoding] = nv.rawValue
                    }
                }
                
                public var keepAlive: HTTP.Headers.KeepAlive? {
                    get {
                        guard let val = self[.keepAlive] else { return nil }
                        return HTTP.Headers.KeepAlive(val)
                    }
                    set {
                        self[.keepAlive] = newValue?.description ?? nil
                        if newValue != nil { self.connection = .keepAlive }
                    }
                }
                
                public var allow: [HTTP.Method]? {
                    get {
                        guard let val = self[.allow] else { return nil }
                        let strVals = val.replacingOccurrences(of: ", ", with: ",").split(separator: ",").map(String.init)
                        return strVals.compactMap(HTTP.Method.init(rawValue:))
                    }
                    set {
                        guard let nv = newValue else {
                            self[.allow] = nil
                            return
                        }
                        self[.allow] = nv.map({ return $0.rawValue }).joined(separator: ", ")
                    }
                }
                
                
                public var lastModified: Date? {
                    get {
                        guard let val = self[.lastModified] else { return nil }
                        return LittleWebServer.dateHeaderFormatter.date(from: val)
                    }
                    set {
                        guard let newVal = newValue else {
                            self[.lastModified] = nil
                            return
                        }
                        self[.lastModified] = LittleWebServer.dateHeaderFormatter.string(from: newVal)
                    }
                }
                internal var lastModifiedString: String? { return self[.lastModified] }
                
                public var cookies: Cookies {
                    get {
                        /*
                        guard let value = self.data[.setCookie],
                              let values = value.arrayValue else {
                            return Cookies()
                        }
                        
                        return Cookies(values)*/
                        guard let value = self.data[.setCookie] else {
                            return Cookies()
                        }
                        return Cookies(value)
                    }
                    set {
                        /*let stringValues = newValue.map { return $0.string }
                        self.data[.setCookie] = HeaderValue(stringValues)*/
                        self.data[.setCookie] = newValue.map { return $0.string }
                    }
                }
                
            }
            
            public struct Details {
                public let responseCode: Int
                public let message: String?
                public var headers: Headers
                
                internal init(_ response: Response) {
                    self.responseCode = response.responseCode
                    self.message = response.message
                    self.headers = response.headers
                }
            }
            
            public enum Body {
                public enum TextComponent {
                    case text(String)
                    case include(contextPath: String, queryItems: [URLQueryItem])
                }
                public struct FileRange {
                    public let lowerBound: UInt
                    public let count: UInt
                    
                    public init(_ count: UInt) {
                        self.lowerBound = 0
                        self.count = count
                    }
                    public init(_ range: Range<UInt>) {
                        self.lowerBound = range.lowerBound
                        self.count = UInt(range.count)
                    }
                    public init(_ range: ClosedRange<UInt>) {
                        self.lowerBound = range.lowerBound
                        self.count = UInt(range.count)
                    }
                }
                case empty
                case data(Data, contentType: ContentType?)
                case file(String,
                          contentType: ContentType?,
                          fileSize: UInt,
                          range: FileRange?,
                          speedLimit: LittleWebServer.FileTransferSpeedLimiter)
                case text([TextComponent],
                          contentType: ContentType,
                          encoding: String.Encoding)
                case custom((LittleWebServerInputStream, LittleWebServerOutputStream) throws -> Void)
                
                
                public var isEmpty: Bool {
                    guard case .empty = self else { return false }
                    return true
                }
                
                public var filePath: String? {
                    guard case .file(let rtn, contentType: _, fileSize: _, range: _, speedLimit: _) = self else { return nil }
                    return rtn
                }
                
                public var fileRange: FileRange? {
                    guard case .file(_, contentType: _, fileSize: _, range: let rtn, speedLimit: _) = self else { return nil }
                    return rtn
                }
                
                public var fileSize: UInt? {
                    guard case .file(_, contentType: _, fileSize: let rtn, range: _, speedLimit: _) = self else { return nil }
                    return rtn
                }
                public var fileTransferSpeedLimit: FileTransferSpeedLimiter? {
                    guard case .file(_, contentType: _, fileSize: _, range: _, speedLimit: let rtn) = self else { return nil }
                    return rtn
                }
                
                public var customBody: ((LittleWebServerInputStream, LittleWebServerOutputStream) throws -> Void)? {
                    guard case .custom(let rtn) = self else { return nil }
                    return rtn
                }
                
                public var contentType: ContentType? {
                    switch self {
                    case .data(_, contentType: let rtn):
                        return rtn
                    case .text(_, contentType: let rtn, encoding: _):
                        return rtn
                    case .file(_, let rtn, fileSize: _, range: _, speedLimit: _):
                        return rtn
                    default:
                        return nil
                    }
                }
                
                internal func content(in controller: Routing.Requests.RouteController,
                                      on server: LittleWebServer) throws -> (content: Data?, length: UInt)? {
                    switch self {
                    case.custom(_): return nil
                    case .empty: return (content: Data(), length: 0)
                    case .data(let dta, contentType: _):
                        return (content: dta, length: UInt(dta.count))
                    case .text(let components, contentType: let ctType, encoding: let enc):
                        var length: UInt = 0
                        var content = Data()
                        
                        for component in components {
                            switch component {
                            case .text(var txt):
                                if ctType.isAnyHTML {
                                    // Change all \r\n to \r so that when we try and do
                                    // a general fix of replacing \r to \r\n it won't
                                    // break any proper \r\n
                                    txt = txt.replacingOccurrences(of: "\r\n", with: "\n")
                                    txt = txt.replacingOccurrences(of: "\n", with: "\r\n")
                                }
                                guard let dta = txt.data(using: enc) else {
                                    throw WebServerError.invalidStringToDataEncoding(txt, encoding: enc)
                                }
                                content.append(dta)
                                length += UInt(dta.count)
                            case .include(contextPath: let pth, queryItems: let query):
                                //let currentRequest = Thread.current.currentLittleWebServerRequest!
                                let currentRequest = Thread.current.littleWebServerDetails.request!
                                let includeRequest = HTTP.Request.init(currentRequest,
                                                                       newMethod: .get,
                                                                       newContextPath: pth,
                                                                       newUrlQuery: nil,
                                                                       newQueryItem: query)
                                /*let includeRequest = HTTP.Request.init(scheme: currentRequest.scheme,
                                                                  method: .get,
                                                                  contextPath: pth,
                                                                  queryPath: nil,
                                                                  version: currentRequest.version,
                                                                  headers: currentRequest.headers,
                                                                  queryItems: query,
                                                                  session: currentRequest.getSession(),
                                                                  isNewSession: currentRequest.isNewSession)*/
                                
                                
                                let resp = try controller.processRequest(for: includeRequest,
                                                                     on: server)
                                  
                                if let ct = try resp.body.content(in: controller, on: server) {
                                    if let dt = ct.content {
                                        content.append(dt)
                                        length += ct.length
                                    } else if (resp.headers.contentType?.isText ?? false)  {
                                        fatalError("Current including files is not supported.")
                                    } else {
                                        fatalError("Current including files is not supported")
                                    }
                                }
                               
                            }
                        }
                        
                        return (content: content, length: length)
                        
                    case .file(_ , contentType: _, fileSize: let fileSize, range: let rng, speedLimit: _):
                        if let range = rng {
                            return (content: nil, length: UInt(range.count))
                        } else {
                            return (content: nil, length: fileSize)
                        }
                    }
                }
            }
        
            public let writeQueue: ProcessQueue
            public var head: Head
            public var body: Body
            
            public var responseCode: Int {
                get { return self.head.responseCode }
            }
            public var message: String? {
                get { return self.head.message }
            }
            public var headers: Headers {
                get { return self.head.headers }
                set { self.head.headers = newValue }
            }
            
            public init(writeQueue: ProcessQueue = .current,
                        head: Head,
                        body: Body = .empty) {
                self.writeQueue = writeQueue
                self.head = head
                self.body = body
            }
            
            
        }
    }
}

public extension LittleWebServer {
    struct Routing {
        private init() { }
        
        public typealias HTTPMethod = LittleWebServer.HTTP.Method
        public typealias HTTPRequest = LittleWebServer.HTTP.Request
        public typealias HTTPResponse = LittleWebServer.HTTP.Response
        
        internal class Route<Handler> where Handler: LittleWebServerRouteHandler {
            public let condition: LittleWebServerRoutePathConditions.RoutePathConditionComponent
            public var handler: Handler
            public var childRoutes: [Route] = []
            
            public init(condition: LittleWebServerRoutePathConditions.RoutePathConditionComponent,
                        handler: Handler = .init()) {
                self.condition = condition
                self.handler = handler
            }
            
            internal var hasHandlers: Bool {
                if self.handler.hasRouteHandler {
                    return true
                }
                for child in self.childRoutes {
                    if child.hasHandlers { return true }
                }
                return false
            }
            
            public func getRoute(for components: [LittleWebServerRoutePathConditions.RoutePathConditionComponent]) -> Route? {
                var components = components
                guard components.count > 0 else { return self }
                guard let route = self.childRoutes.first(where: { return $0.condition == components.first! }) else {
                    return  nil
                }
                
                components.remove(at: 0)
                guard components.count > 0 else {
                    return route
                }
                
                return route.getRoute(for: components)
                
            }
            
            public func getRouteForPathOrCreate(_ components: [LittleWebServerRoutePathConditions.RoutePathConditionComponent]) -> Route {
                var components = components
                guard components.count > 0 else { return self }
                
                let route = self.childRoutes.first(where: { return $0.condition == components.first! }) ?? {
                   let rtn = Route(condition: components.first!)
                    self.childRoutes.append(rtn)
                    
                    
                    self.childRoutes.sort(by: { return $0.condition.pathCondition < $1.condition.pathCondition })
                    //print("Child Routes sorted '\(self.condition.string)'\n\(self.childRoutes.map({ return $0.condition.string }))")
                    
                    
                    return rtn
                }()
                
                components.remove(at: 0)
                return route.getRouteForPathOrCreate(components)
            }
            
            
            
            internal func getHandler(for request: HTTPRequest,
                                     pathComponents: [String],
                                     atPathIndex pathIndex: Int = 0,
                                     on server: LittleWebServer) throws -> (handler: Handler,
                                                                            transformedIdentifiers: [String: Any],
                                                                            transformedParameters: [String: Any])? {
                //print("Getting handler for '/\(pathComponents[pathIndex...].joined(separator: "/"))' - '\(self.condition.pathCondition)'")
                guard let r = try self.condition.test(pathComponents: pathComponents,
                                                      atPathIndex: pathIndex,
                                                      in: request,
                                                      using: server) else {
                    return nil
                }
                //print("Got handler for '/\(pathComponents[pathIndex...].joined(separator: "/"))' - '\(self.condition.pathCondition)'")
                
                var transformablePathComponent = pathComponents[pathIndex]
                if self.condition.pathCondition == .anythingHereafter {
                    transformablePathComponent = pathComponents.suffix(from: pathIndex).joined(separator: "/")
                }
                
                var transformedIdentifiers: [String: Any] = [:]
                var transformedParameters: [String: Any] = r.transformedParameters
                if let identifier = r.identifier,
                   let transformedIdentifier = r.transformedValue {
                    transformedIdentifiers[identifier] = transformedIdentifier
                } else if let identifier = r.identifier {
                    transformedIdentifiers[identifier] = transformablePathComponent
                }
                
                if pathIndex == pathComponents.count - 1 ||
                   self.condition.pathCondition == .anythingHereafter  {
                    guard self.handler.hasRouteHandler else { return nil }
                    //print("Returning handler for '\(pathComponents[pathIndex...].joined(separator: "/"))'")
                    return (handler: self.handler,
                            transformedIdentifiers: transformedIdentifiers,
                            transformedParameters: transformedParameters)
                }
                
                let nextPathIndex = pathIndex + 1
                for child in self.childRoutes {
                    if let r2 = try child.getHandler(for: request,
                                                     pathComponents: pathComponents,
                                                     atPathIndex: nextPathIndex,
                                                     on: server),
                       r2.handler.hasRouteHandler {
                        
                        //print("Returning child handler for '\(pathComponents[pathIndex...].joined(separator: "/"))'")
                    
                        transformedIdentifiers.merge(r2.transformedIdentifiers, uniquingKeysWith: { return $1})
                        transformedParameters.merge(r2.transformedParameters, uniquingKeysWith: { return $1})
                        
                        return (handler: r2.handler,
                                transformedIdentifiers: transformedIdentifiers,
                                transformedParameters: transformedParameters)
                        
                    }
                }
                
                return nil
                
            }
            
            public func getHandler(for request: HTTPRequest,
                                   on server: LittleWebServer) throws -> (handler: Handler,
                                                                          transformedIdentifiers: [String: Any],
                                                                          transformedParameters: [String: Any])? {
                
                var pathComponents = request.contextPath.split(separator: "/").map(String.init)
                /*if pathComponents.count == 0 {
                    pathComponents.append("")
                }*/
                if request.contextPath.hasSuffix("/") {
                    pathComponents.append("")
                }
                
                return try self.getHandler(for: request,
                                           pathComponents: pathComponents,
                                           on: server)
            }
        }
        
        public class Middleware {
            
            public enum Response {
                case stop
                case `continue`
                case response(HTTPResponse)
            }
            public typealias IndividualHandler = (inout HTTPRequest) -> Response
            public typealias IndividualHalfHandler = (inout HTTPRequest) -> Void
            public typealias Handler = [IndividualHandler]
            
            private var routes: [Route<Handler>] = []
            
            public subscript(path: LittleWebServerRoutePathConditions) -> Handler {
                get {
                    guard let r = self.getRoute(for: path) else {
                        return []
                    }
                    return r.handler
                }
                set {
                    let r = self.getRouteForPathOrCreate(path)
                    r.handler = newValue
                }
            }
            
            public init() { }
            
            private func getRoute(for components: [LittleWebServerRoutePathConditions.RoutePathConditionComponent]) -> Route<Handler>? {
                var components = components
                guard components.count > 0 else { return nil }
                guard let route = self.routes.first(where: { return $0.condition == components.first! }) else {
                    return  nil
                }
                
                components.remove(at: 0)
                return route.getRoute(for: components)
                
            }
            
            private func getRoute(for path: LittleWebServerRoutePathConditions) -> Route<Handler>? {
                return self.getRoute(for: path.components)
            }
            
            private func getRouteForPathOrCreate(_ components: [LittleWebServerRoutePathConditions.RoutePathConditionComponent]) -> Route<Handler> {
                var components = components
                precondition(components.count > 0, "Invalid Component Paths")
                
                
                let route = self.routes.first(where: { return $0.condition == components.first! }) ?? {
                    let rtn = Route<Handler>(condition: components.first!)
                    self.routes.append(rtn)
                    return rtn
                }()
                
                components.remove(at: 0)
                return route.getRouteForPathOrCreate(components)
                
            }
            private func getRouteForPathOrCreate(_ path: LittleWebServerRoutePathConditions) -> Route<Handler> {
                return self.getRouteForPathOrCreate(path.components)
            }
            
            internal var hasHandlers: Bool {
                for route in self.routes {
                    if route.hasHandlers { return true }
                }
                return false
            }
            
            public func appendGlobalHandler(_ action: @escaping IndividualHandler) {
                self.getRouteForPathOrCreate(.anythingHereafter()).handler.append(action)
            }
            
            public func appendSimpleGlobalHandler(_ action: @escaping IndividualHalfHandler) {
                self.appendGlobalHandler {
                    action(&$0)
                    return .continue
                }
            }
            
            internal func processRequest(for request: inout HTTPRequest,
                                         in controller: Requests.RouteController,
                                         on server: LittleWebServer) throws -> HTTPResponse? {
               
                var rtn: HTTPResponse? = nil
                var workingRequest = request
                
                var wasStopped: Bool = false
                
                // Execute all global middleware handlers
                for m in self.routes where (rtn == nil && !wasStopped) {
                    guard m.condition.pathCondition == .anythingHereafter else {
                        continue
                    }
                    // Loop through each action in the handler list
                    for action in m.handler {
                    
                        let r = action(&workingRequest)
                        switch r {
                            case .stop:
                                wasStopped = true
                                break
                            case .response(let r):
                                rtn = r
                                break
                            default:
                                continue
                        }
                    }
                }
                
                // Execute all specific middleware handlers
                for m in self.routes where (rtn == nil && !wasStopped) {
                    guard m.condition.pathCondition != .anythingHereafter else {
                        continue
                    }
                    
                    if let r = try m.getHandler(for: workingRequest, on: server) {
                        // Loop through each action in the handler list
                        for action in r.handler {
                        
                            let r = action(&workingRequest)
                            switch r {
                                case .stop:
                                    wasStopped = true
                                    break
                                case .response(let r):
                                    rtn = r
                                    break
                                default:
                                    continue
                            }
                        }
                    }
                }
                
                
                request = workingRequest
                
                
                return rtn
            }
        }
        
        
        public struct Requests {
            private init() { }
            
            public class BaseRoutes {
                public let method: HTTPMethod
                
                public required init(method: HTTPMethod) {
                    self.method = method
                }
                
                internal var hasHandlers: Bool {
                    return false
                }
                
                
                public subscript(paths: LittleWebServerRoutePathConditions...) -> Any? {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set { fatalError("Must be overridden by child class") }
                }
                
                /*
                internal func validateRouteHandler(_ handler: Any?) -> Bool {
                    fatalError("Must be overridden by child class")
                }
                */
                
                internal func canHandleRequest(for request: HTTPRequest,
                                               in controller: RouteController,
                                                on server: LittleWebServer) throws -> Bool {
                    fatalError("Must be implemented in child class")
                }
                
                internal func processRequest(for request: HTTPRequest,
                                             in controller: RouteController,
                                             on server: LittleWebServer) throws -> HTTPResponse? {
                    fatalError("Must be implemented in child class")
                }
                
            }
            
            public class Routes<Response>: BaseRoutes {
                public typealias RouteResponse = Response
                public typealias FullHandler = (HTTPRequest, RouteController, LittleWebServer) -> RouteResponse?
                public typealias LockedFullHandler = (HTTPRequest,RouteController, LittleWebServer) -> RouteResponse
                public typealias RequestHandler = (HTTPRequest) -> RouteResponse?
                public typealias LockedRequestHandler = (HTTPRequest) -> RouteResponse
                public typealias RequestRouteControllerHandler = (HTTPRequest, RouteController) -> RouteResponse?
                public typealias LockedRequestRouteControllerHandler = (HTTPRequest, RouteController) -> RouteResponse
                public typealias RequestServerHandler = (HTTPRequest, LittleWebServer) -> RouteResponse?
                public typealias LockedRequestServerHandler = (HTTPRequest, LittleWebServer) -> RouteResponse
                public typealias Handler = Optional<FullHandler>
                
                private let routesSync = DispatchQueue(label: "LittleWebServer.Routing.Requests.Routes.routes.sync")
                private var routes: [Route<Handler>] = []
                //private var folderRoute: Route<Handler> = Route<Handler>.init(condition: .anything())
                
                
                // Setter for setting request handler for the given path
                public subscript(paths: LittleWebServerRoutePathConditions...) -> FullHandler {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            let r = self.getRouteForPathOrCreate(path)
                        
                            r.handler = newValue
                        }
                    }
                }
                
                // Setter for setting request handler for the given path
                public subscript(paths: LittleWebServerRoutePathConditions...) -> LockedFullHandler {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            let r = self.getRouteForPathOrCreate(path)
                            
                            r.handler = {r, c, s in
                                return newValue(r,c,s)
                            }
                        }
                    }
                }
                
                // Setter for setting request handler for the given path
                public subscript(paths: LittleWebServerRoutePathConditions...) -> RequestHandler {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            let r = self.getRouteForPathOrCreate(path)
                            
                            r.handler = { r, _, _ in
                                return newValue(r)
                            }
                        }
                    }
                }
                
                // Setter for setting request handler for the given path
                public subscript(paths: LittleWebServerRoutePathConditions...) -> LockedRequestHandler {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            let r = self.getRouteForPathOrCreate(path)
                        
                            r.handler = { r, _, _ in
                                return newValue(r)
                            }
                        }
                    }
                }
                
                // Setter for setting request handler for the given path
                public subscript(paths: LittleWebServerRoutePathConditions...) -> RequestRouteControllerHandler {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            let r = self.getRouteForPathOrCreate(path)
                        
                            r.handler = { r, c, _ in
                                return newValue(r, c)
                            }
                        }
                    }
                }
                
                // Setter for setting request handler for the given path
                public subscript(paths: LittleWebServerRoutePathConditions...) -> LockedRequestRouteControllerHandler {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            let r = self.getRouteForPathOrCreate(path)
                        
                            r.handler = { r, c, _ in
                                return newValue(r, c)
                            }
                        }
                    }
                }
                
                // Setter for setting request handler for the given path
                public subscript(paths: LittleWebServerRoutePathConditions...) -> RequestServerHandler {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            let r = self.getRouteForPathOrCreate(path)
                        
                            r.handler = { r, _, s in
                                return newValue(r, s)
                            }
                        }
                    }
                }
                
                // Setter for setting request handler for the given path
                public subscript(paths: LittleWebServerRoutePathConditions...) -> LockedRequestServerHandler {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            let r = self.getRouteForPathOrCreate(path)
                        
                            r.handler = { r, _, s in
                                return newValue(r, s)
                            }
                        }
                    }
                }
                
                // Setter for setting / removing request handler for the given path
                public override subscript(paths: LittleWebServerRoutePathConditions...) -> Any? {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            let r = self.getRouteForPathOrCreate(path)
                        
                            guard let v = newValue else {
                                r.handler = nil
                                return
                            }
                            
                            if let hdlr = v as? FullHandler {
                                r.handler = hdlr
                            } else if let hdlr = v as? LockedFullHandler {
                                r.handler = {r, c, s in
                                    return hdlr(r,c,s)
                                }
                            } else if let hdlr = v as? RequestHandler {
                                r.handler = { r, _, _ in
                                    return hdlr(r)
                                }
                            } else if let hdlr = v as? LockedRequestHandler {
                                r.handler = { r, _, _ in
                                    return hdlr(r)
                                }
                            } else if let hdlr = v as? RequestRouteControllerHandler {
                                r.handler = { r, c, _ in
                                    return hdlr(r, c)
                                }
                            } else if let hdlr = v as? LockedRequestRouteControllerHandler {
                                r.handler = { r, c, _ in
                                    return hdlr(r, c)
                                }
                            } else if let hdlr = v as? RequestServerHandler {
                                r.handler = { r, _, s in
                                    return hdlr(r, s)
                                }
                            } else if let hdlr = v as? LockedRequestServerHandler {
                                r.handler = { r, _, s in
                                    return hdlr(r, s)
                                }
                            } else {
                                preconditionFailure("Invalid handler type '\(type(of: v))'")
                            }
                        }
                    }
                }
                
                
                /*
                internal override func validateRouteHandler(_ handler: Any?) -> Bool {
                    if let _ = handler as? FullHandler {
                        return true
                    } else if let _ = handler as? RequestHandler {
                        return true
                    } else if let _ = handler as? RequestRouteControllerHandler {
                        return true
                    } else if let _ = handler as? RequestServerHandler {
                        return true
                    } else {
                        return false
                    }
                }
                */
                /*
                public subscript(path: RoutePathConditions) -> Handler {
                    get {
                        guard let r = self.getRoute(for: path) else {
                            return nil
                        }
                        return r.handler
                    }
                    set {
                        let r = self.getRouteForPathOrCreate(path)
                        r.handler = newValue
                    }
                }
                */
                private func getRoute(for components: [LittleWebServerRoutePathConditions.RoutePathConditionComponent]) -> Route<Handler>? {
                    //guard components.count > 0 else { return self.folderRoute }
                    
                    var components = components
                    guard components.count > 0 else { return nil }
                    // Find the first route
                    guard let route = self.routesSync.sync(execute: { return self.routes.first(where: { return $0.condition == components.first! }) }) else {
                        return  nil
                    }
                    
                    components.remove(at: 0)
                    return route.getRoute(for: components)
                    
                }
                
                private func getRoute(for path: LittleWebServerRoutePathConditions) -> Route<Handler>? {
                    return self.getRoute(for: path.components)
                }
                
                private func getRouteForPathOrCreate(_ components: [LittleWebServerRoutePathConditions.RoutePathConditionComponent]) -> Route<Handler> {
                    //guard components.count > 0 else { return self.folderRoute }
                    
                    var components = components
                    precondition(components.count > 0, "Invalid Component Paths")
                    
                    
                    let route = self.routesSync.sync {
                        return self.routes.first(where: { return $0.condition == components.first! }) ?? {
                            let rtn = Route<Handler>(condition: components.first!)
                            self.routes.append(rtn)
                            // sort routes so * and ** will be at the bottom
                            // giving way for more specific routes to test first
                            self.routes.sort(by: { return $0.condition.pathCondition < $1.condition.pathCondition })
                            //print("Routes sorted\n\(self.routes.map({ return $0.condition.string }))")
                            return rtn
                        }()
                    }
                    
                    components.remove(at: 0)
                    return route.getRouteForPathOrCreate(components)
                    
                }
                private func getRouteForPathOrCreate(_ path: LittleWebServerRoutePathConditions) -> Route<Handler> {
                    return self.getRouteForPathOrCreate(path.components)
                }
                
                internal override var hasHandlers: Bool {
                    return self.routesSync.sync {
                        return self.routes.contains(where: { return $0.hasHandlers })
                    }
                }
                
                internal override func canHandleRequest(for request: HTTPRequest,
                                                        in controller: RouteController,
                                                        on server: LittleWebServer) throws -> Bool {
                    
                    for r in self.routes {
                        if try r.getHandler(for: request, on: server) != nil {
                            return true
                        }
                    }
                    return false
                }
                
                internal override func processRequest(for request: HTTPRequest,
                                                      in controller: RouteController,
                                                      on server: LittleWebServer) throws -> HTTPResponse? {
                    for r in self.routes {
                        //let a = try r.getHandler(for: request, on: server)
                        //print("Checking route '\(r.condition.string)' for '\(request.contextPath)': \(a)")
                        if let h = try r.getHandler(for: request, on: server),
                           h.handler.hasRouteHandler {
                            //print("Found route '\(r.condition.string)' for '\(request.contextPath)'")
                            let oldIdentities = request.identities
                            let oldProps = request.propertyTransformations
                            defer {
                                request.identities = oldIdentities
                                request.propertyTransformations = oldProps
                            }
                            
                            request.identities.merge(h.transformedIdentifiers, uniquingKeysWith: { return $1 })
                            request.propertyTransformations.merge(h.transformedParameters, uniquingKeysWith: { return $1 })
                            
                            let resp = h.handler!(request, controller, server)
                            
                            if let hResp = resp as? HTTP.Response.Head {
                                return HTTP.Response.init(head: hResp)
                            } else if let fResp = resp as? HTTP.Response {
                                return fResp
                            } else {
                                fatalError("Unknown Handler Response Type '\(type(of: resp))'")
                            }
                            
                        }
                    }
                    return nil
                }
            }
            
            
            public typealias HTTPResponseRoute = Routes<HTTPResponse>
            public typealias HTTPResponseHeadRoute = Routes<HTTPResponse.Head>
            
            public class RouteController {
                
                public typealias FullHandler = (HTTPRequest, RouteController, LittleWebServer) -> HTTPResponseRoute.RouteResponse?
                public typealias LockedFullHandler = (HTTPRequest,RouteController, LittleWebServer) -> HTTPResponseRoute.RouteResponse
                public typealias RequestHandler = (HTTPRequest) -> HTTPResponseRoute.RouteResponse?
                public typealias LockedRequestHandler = (HTTPRequest) -> HTTPResponseRoute.RouteResponse
                public typealias RequestRouteControllerHandler = (HTTPRequest, RouteController) -> HTTPResponseRoute.RouteResponse?
                public typealias LockedRequestRouteControllerHandler = (HTTPRequest, RouteController) -> HTTPResponseRoute.RouteResponse
                public typealias RequestServerHandler = (HTTPRequest, LittleWebServer) -> HTTPResponseRoute.RouteResponse?
                public typealias LockedRequestServerHandler = (HTTPRequest, LittleWebServer) -> HTTPResponseRoute.RouteResponse
                public typealias Handler = Optional<FullHandler>
                
                
                private var routesSyncLock = DispatchQueue(label: "LittleWebServer.Routing.Requests.RouteController.routes.sync")
                private var routes: [HTTP.Method: BaseRoutes] = [:]
                
                public var head: HTTPResponseHeadRoute {
                    return self.getOrCreateRoute(for: .head, ofType: HTTPResponseHeadRoute.self)
                }
                public var get: HTTPResponseRoute {
                    return self.getOrCreateRoute(for: .get, ofType: HTTPResponseRoute.self)
                }
                public var post: HTTPResponseRoute {
                    return self.getOrCreateRoute(for: .post, ofType: HTTPResponseRoute.self)
                }
                public var put: HTTPResponseRoute {
                    return self.getOrCreateRoute(for: .put, ofType: HTTPResponseRoute.self)
                }
                public var delete: HTTPResponseRoute {
                    return self.getOrCreateRoute(for: .delete, ofType: HTTPResponseRoute.self)
                }
                public var connect: HTTPResponseRoute {
                    return self.getOrCreateRoute(for: .connect, ofType: HTTPResponseRoute.self)
                }
                // Options returns what other methods are supported for the request
                //public let options: Router<HTTPResponse>
                public var trace: HTTPResponseRoute {
                    return self.getOrCreateRoute(for: .trace, ofType: HTTPResponseRoute.self)
                }
                public var patch: HTTPResponseRoute {
                    return self.getOrCreateRoute(for: .patch, ofType: HTTPResponseRoute.self)
                }
                
                public let middleware = Middleware()
                
                public var resourceNotFoundHandler: (HTTPRequest) -> HTTPResponse = { _ in
                    return .notFound(body: .html("""
                                                 <html>
                                                 <head><title>404 Not Found</title></head>
                                                 <body>
                                                 <center><h1>404 Not Found</h1></center>
                                                 </body>
                                                 </html>
                                                 """
                    ))
                }
                public typealias InternalErrorHandler = (_ request: HTTPRequest,
                                                         _ error: Swift.Error?,
                                                         _ message: String?) -> HTTPResponse
                public var internalErrorHandler: (_ request: HTTPRequest,
                                                  _ error: Swift.Error?,
                                                  _ message: String?) -> HTTPResponse = { _, error, message in
                    var err: String = ""
                    if let e = error {
                        err = "\(e)"
                    }
                    var m: String = ""
                    if let msg = message {
                        m = "<br/><center><b>Message: </b>\(msg)</center>"
                    }
                    return .internalError(body: .html("""
                                                      <html>
                                                      <head><title>Internal Server Error</title></head>
                                                      <body>
                                                      <center><h1>There was an internal server error</h1></center>
                                                      \(m)
                                                      <!--\(err)-->
                                                      </body>
                                                      </html>
                                                      """
                    ))
                }
                
                public var allRouters: [BaseRoutes] {
                    return Array(self.routes.values)
                }
                
                private let defaultRouter: HTTPResponseRoute = .init(method: .get)
                
                
                public subscript(paths: LittleWebServerRoutePathConditions...) -> (LittleWebServerRoutePathConditions, RouteController) -> Void {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            newValue(path, self)
                        }
                    }
                }
                
                public subscript(paths: LittleWebServerRoutePathConditions...) -> [HTTPMethod: (LittleWebServerRoutePathConditions.RoutePathConditionSlice?, Any)] {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            for (method, subPathValue) in newValue {
                                var pth = path
                                if let sub = subPathValue.0 {
                                    pth += sub
                                }
                                
                                self.setRouteValue(method: method,
                                                   path: pth,
                                                   newValue: subPathValue.1)
                            }
                        }
                    }
                }
                
                public subscript(paths: LittleWebServerRoutePathConditions...) -> [HTTPMethod: (LittleWebServerRoutePathConditions.RoutePathConditionSlice, Any)] {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        var nv: [HTTPMethod: (LittleWebServerRoutePathConditions.RoutePathConditionSlice?, Any)] = [:]
                        for (k,v) in newValue {
                            let nkv: (LittleWebServerRoutePathConditions.RoutePathConditionSlice?, Any) = (v.0, v.1)
                            nv[k] = nkv
                        }
                        
                        
                        for path in paths {
                            self[path] = nv
                        }
                    }
                }
                
                public subscript(paths: LittleWebServerRoutePathConditions...) -> [HTTPMethod: Any] {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            for (method, v) in newValue {
                                if let subPathValue = v as? (LittleWebServerRoutePathConditions.RoutePathConditionSlice,
                                                             Any) {
                                    
                                    
                                    self[path] = [method: subPathValue]
                                    
                                } else if let subPathValue = v as? (LittleWebServerRoutePathConditions.RoutePathConditionComponent,
                                                                    Any) {
                                    self[path] = [method: subPathValue]
                                } else {
                                    self.setRouteValue(method: method,
                                                       path: path,
                                                       newValue: v)
                                }
                            }
                        }
                    }
                }
                
                public subscript(paths: LittleWebServerRoutePathConditions...) -> [(HTTPMethod, LittleWebServerRoutePathConditions.RoutePathConditionSlice?, Any)] {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            for (method, subPathValue, val) in newValue {
                                var pth = path
                                if let sub = subPathValue {
                                    pth += sub
                                }
                                
                                self.setRouteValue(method: method,
                                                   path: pth,
                                                   newValue: val)
                            }
                        }
                    }
                }
                
                public subscript(paths: LittleWebServerRoutePathConditions...) -> [(HTTPMethod, LittleWebServerRoutePathConditions.RoutePathConditionSlice, Any)] {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        
                        let nv: [(HTTPMethod, LittleWebServerRoutePathConditions.RoutePathConditionSlice, Any)]  = newValue.map({ return ($0.0, $0.1, $0.2) })
                        for path in paths {
                            self[path] = nv
                        }
                    }
                }
                
                public subscript(paths: LittleWebServerRoutePathConditions...) -> [(HTTPMethod, LittleWebServerRoutePathConditions.RoutePathConditionComponent?, Any)] {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            for (method, subPathValue, val) in newValue {
                                var pth = path
                                if let sub = subPathValue {
                                    pth += sub
                                }
                                
                                self.setRouteValue(method: method,
                                                   path: pth,
                                                   newValue: val)
                            }
                        }
                    }
                }
                
                public subscript(paths: LittleWebServerRoutePathConditions...) -> [(HTTPMethod, LittleWebServerRoutePathConditions.RoutePathConditionComponent, Any)] {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        
                        let nv: [(HTTPMethod, LittleWebServerRoutePathConditions.RoutePathConditionComponent, Any)]  = newValue.map({ return ($0.0, $0.1, $0.2) })
                        for path in paths {
                            self[path] = nv
                        }
                    }
                }
                
                public subscript(paths: LittleWebServerRoutePathConditions...) -> [(HTTPMethod, Any)] {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            for (method, v) in newValue {
                                if let subPathValue = v as? (LittleWebServerRoutePathConditions.RoutePathConditionSlice,
                                                             Any) {
                                    
                                    
                                    self[path] = [(method, subPathValue)]
                                    
                                } else if let subPathValue = v as? (LittleWebServerRoutePathConditions.RoutePathConditionComponent,
                                                                    Any) {
                                    self[path] = [(method, subPathValue)]
                                } else {
                                    self.setRouteValue(method: method,
                                                       path: path,
                                                       newValue: v)
                                }
                            }
                        }
                    }
                }
                
                public subscript(paths: LittleWebServerRoutePathConditions...) -> Any {
                    get { fatalError("Getter unsupported.  Please only use setter") }
                    set {
                        for path in paths {
                            if let fnc = newValue as? (LittleWebServerRoutePathConditions, RouteController) -> Void {
                                fnc(path, self)
                            } else if let group = newValue as? [HTTPMethod: Any] {
                                self[path] = group
                            } else if let group = newValue as? [(HTTPMethod, Any)] {
                                self[path] = group
                            } else {
                                self.defaultRouter[path] = newValue
                            }
                        }
                    }
                }
                
                
                private func setRouteValue(method: HTTPMethod,
                                           path: LittleWebServerRoutePathConditions,
                                           newValue: Any) {
                    
                    let routes: BaseRoutes
                    if method == .head {
                        routes = self.getOrCreateRoute(for: method,
                                                       ofType: HTTPResponseHeadRoute.self)
                    } else {
                        routes = self.getOrCreateRoute(for: method,
                                                       ofType: HTTPResponseRoute.self)
                    }
                    
                    routes[path] = newValue
                }
                /*
                public subscript(path: RoutePathConditions) -> HTTPResponseRoute.Handler {
                    get { return self.defaultRouter[path] }
                    set { self.defaultRouter[path] = newValue }
                }
                */
                
                private weak var server: LittleWebServer?
                public init(server: LittleWebServer) {
                    self.server = server
                }
                
                #if swift(>=5.3)
                public func internalError(for request: HTTP.Request,
                                          error: Swift.Error? = nil,
                                          message: String? = nil,
                                          signalServerErrorHandler: Bool = true,
                                          file: String = #filePath,
                                          line: Int = #line) -> HTTP.Response {
                    var err = error
                    if let e = err {
                        if let tErr = e as? TrackableError {
                            err = tErr
                        } else {
                            err = TrackableError(error: e, file: file, line: line)
                        }
                        if signalServerErrorHandler {
                            self.server?.signalServerError(err as! TrackableError)
                        }
                    }
                    
                    return self.internalErrorHandler(request, err, message)
                }
                #else
                public func internalError(for request: HTTP.Request,
                                          error: Swift.Error? = nil,
                                          message: String? = nil,
                                          signalServerErrorHandler: Bool = true,
                                          file: String = #file,
                                          line: Int = #line) -> HTTP.Response {
                    var err = error
                    if let e = err {
                        if let tErr = e as? TrackableError {
                            err = tErr
                        } else {
                            err = TrackableError(error: e, file: file, line: line)
                        }
                        if signalServerErrorHandler {
                            self.server?.signalServerError(err as! TrackableError)
                        }
                    }
                    
                    return self.internalErrorHandler(request, err, message)
                }
                #endif
                
                private func getRoute(for method: HTTP.Method) -> BaseRoutes? {
                    return self.routesSyncLock.sync {
                        return self.routes[method]
                    }
                }
                
                private func getOrCreateRoute<T>(for method: HTTP.Method, ofType: T.Type) -> T where T: BaseRoutes {
                    precondition(method != .options, "Routes for method 'OPTIONS' are handled automatically")
                    if method == .head && T.self != HTTPResponseHeadRoute.self {
                        preconditionFailure("Method '\(method.rawValue)' requires route type of '\(HTTPResponseHeadRoute.self)'")
                    } else if method != .head && T.self != HTTPResponseRoute.self {
                        preconditionFailure("Method '\(method.rawValue)' requires route type of '\(HTTPResponseRoute.self)'")
                    }
                    return self.routesSyncLock.sync {
                        var rt = self.routes[method]
                        if rt == nil {
                            rt = T(method: method)
                            self.routes[method] = rt!
                        }
                        
                        guard let rtn = rt! as? T else {
                            preconditionFailure("Could not cast \(type(of: rt!)) to \(T.self)")
                        }
                        return rtn
                    }
                }
                
                
                internal func _processRequest(for request: HTTP.Request,
                                             on server: LittleWebServer) throws -> HTTP.Response? {
                    
                    //let oldController = Thread.current.currentLittleWebServerRouteController
                    let oldController = Thread.current.littleWebServerDetails.routeController
                    //let oldCurrentRequest = Thread.current.currentLittleWebServerRequest
                    let oldCurrentRequest = Thread.current.littleWebServerDetails.request
                    defer {
                        //Thread.current.currentLittleWebServerRequest = oldCurrentRequest
                        Thread.current.littleWebServerDetails.request = oldCurrentRequest
                        //Thread.current.currentLittleWebServerRouteController = oldController
                        Thread.current.littleWebServerDetails.routeController = oldController
                    }
                    //Thread.current.currentLittleWebServerRouteController = self
                    Thread.current.littleWebServerDetails.routeController = self
                    //Thread.current.currentLittleWebServerRequest = request
                    Thread.current.littleWebServerDetails.request = request
                    
                    guard request.method != .options else {
                        var possible: [HTTP.Method] = []
                        
                        if request.contextPath == "*" {
                            for route in self.allRouters {
                                if route.hasHandlers {
                                    possible.append(route.method)
                                }
                            }
                        } else {
                        
                            var foundHandler: Bool = false
                            for route in self.allRouters {
                                if try route.canHandleRequest(for: request, in: self, on: server) {
                                    foundHandler = true
                                    possible.append(route.method)
                                }
                            }
                            if !foundHandler {
                                if try self.defaultRouter.canHandleRequest(for: request, in: self, on: server) {
                                    possible.append(contentsOf: HTTPMethod.basicKnownMethods)
                                    if !HTTPMethod.basicKnownMethods.contains(request.method) {
                                        possible.append(request.method)
                                    }
                                }
                            }
                            
                        }
                        
                        guard possible.count > 0 else {
                            return self.resourceNotFoundHandler(request)
                        }
                        
                        var headers = HTTPResponse.Headers()
                        headers.allow = possible
                        return .ok(headers: headers)
                    }
                    
                    var workingRequest = request
                    var rtn: HTTPResponse? = try self.middleware.processRequest(for: &workingRequest,
                                                                                in: self,
                                                                                on: server)
                    
                    
                    // we update current request as middleware could change it
                    //Thread.current.currentLittleWebServerRequest = workingRequest
                    Thread.current.littleWebServerDetails.request = workingRequest
                    // If middleware gave a valid response then we wont go looking
                    // for one through the routes
                    if rtn == nil {
                        if let route = self.allRouters[workingRequest.method],
                           let r = try route.processRequest(for: workingRequest, in: self, on: server) {
                            rtn = r
                        } else if let r = try self.defaultRouter.processRequest(for: workingRequest,
                                                                                in: self,
                                                                                on: server) {
                            rtn = r
                        }
                    }
                    
                    if rtn == nil &&
                       !request.contextPath.hasSuffix("/") &&
                       workingRequest.method == .get {
                        let folderRequest = HTTP.Request.init(request, newContextPath: request.contextPath + "/")
                        
                        
                        if let folderResp = try self._processRequest(for: folderRequest, on: server) {
                            if folderResp.head.responseCode != 404 {
                                rtn = .permanentlyMoved(location: folderRequest.fullPath)
                            }
                        }
                    }
                    
                    return rtn
                }
                
                internal func processRequest(for request: HTTP.Request,
                                             on server: LittleWebServer) throws -> HTTP.Response {
                    
                    return try self._processRequest(for: request, on: server) ?? self.resourceNotFoundHandler(request)
                }
                
            }
            
            public class HostRoutes {
                private let syncLock = DispatchQueue(label: "LittleWebServer.HostRoutes.routes")
                private var routes: [String: Requests.RouteController] = [:]
                private weak var server: LittleWebServer?
                
                public subscript(host: HTTP.Headers.Host) -> Requests.RouteController {
                    get {
                        return self.syncLock.sync {
                            if !self.routes.keys.contains(host.name.description) {
                                precondition(self.server != nil, "Server has been lost")
                                self.routes[host.name.description] = .init(server: self.server!)
                            }
                            return self.routes[host.name.description]!
                        }
                    }
                    set {
                        self.syncLock.sync {
                            self.routes[host.name.description] = newValue
                        }
                    }
                }
                
                public var `default`: Requests.RouteController {
                    get {
                        return self["*"]
                    }
                    set {
                        self["*"] = newValue
                    }
                }
                
                public init(server: LittleWebServer) {
                    self.server = server
                    self.routes["*"] = .init(server: server)
                }
                
                internal func getRoutes(for host: HTTP.Headers.Host?,
                                        withDefault defaultRoutes: @autoclosure () -> Requests.RouteController) -> Requests.RouteController {
                    guard let host = host else {
                        return defaultRoutes()
                    }
                    
                    return self.syncLock.sync(execute: { return self.routes[host.name.description] }) ??  defaultRoutes()
                }
                
                internal func getRoutes(for request: HTTP.Request?,
                                        withDefault defaultRoutes: @autoclosure () -> Requests.RouteController) -> Requests.RouteController {
                    
                    return self.getRoutes(for: request?.headers.host, withDefault: defaultRoutes())
                }
            }
        }
        
        
        
    }
}

internal extension LittleWebServer {
    class ListenerControl: Comparable {
        
        let listener: LittleWebServerListener
        var queue: DispatchQueue? = nil
        let webserver: LittleWebServer
        public private(set) var running: Bool = false
        
        public init(_ listener: LittleWebServerListener,
                    webserver: LittleWebServer) {
            self.listener = listener
            self.webserver = webserver
        }
        
        public func start() throws {
            guard self.queue == nil else { return }
            if !self.listener.isListening {
                try self.listener.startListening()
            }
            
            
            self.queue = DispatchQueue(label: "LittleWebServer.ListenerControl[\(self.listener.uid)]")
            
            self.queue!.async {
                repeat {
                    do {
                        
                        // Wait until we have an available worker to use to process the request
                        self.webserver.httpCommunicator.waitForQueueToBeAvailable(queue: .request, on: self.webserver)
                        // Ensure we haven't stopped
                        guard !self.webserver.isStoppingOrStopped &&
                                !Thread.current.isCancelled else { return }
                        //print("Waiting for client")
                        let client = try self.listener.accept()
                        //
                        guard self.webserver.allowConnection(client) else {
                            continue
                        }
                        self.webserver.onAcceptedClient(client, from: self.listener)
                        
                    } catch {
                        if !self.webserver.isStoppingOrStopped &&
                            !Thread.current.isCancelled {
                            // only signal error if we are not shutting down
                            // In that case error is probably because the connection
                            // is now closed
                            self.webserver.signalServerError(error: error)
                        }
                    }
                } while !self.webserver.isStoppingOrStopped &&
                        !Thread.current.isCancelled &&
                        self.listener.isListening
                    
            }
            
            self.queue = nil
            
        }
        
        public func stop() {
            self.listener.close()
        }
        
        static func == (lhs: LittleWebServer.ListenerControl,
                        rhs: LittleWebServer.ListenerControl) -> Bool {
            return lhs.listener.uid == rhs.listener.uid
        }
        
        static func < (lhs: LittleWebServer.ListenerControl,
                       rhs: LittleWebServer.ListenerControl) -> Bool {
            return lhs.listener.uid < rhs.listener.uid
        }
    }
}



public class LittleWebServer {
    
    internal static let CR: UInt8 = 13
    internal static let LF: UInt8 = 10
    internal static let CRLF_BYTES: [UInt8] = [CR, LF]
    internal static let CRLF_DATA: Data = Data(CRLF_BYTES)
    internal static let END_SEGMENT_BLOCK_BYTES: [UInt8] = CRLF_BYTES + CRLF_BYTES
    internal static let END_SEGMENT_BLOCK_DATA: Data = Data(END_SEGMENT_BLOCK_BYTES)
    internal static let HTTP_REQUEST_HEAD_MAX_LENGTH: Int = 2048
    
    public enum WebServerError: Swift.Error {
        case startError(listener: LittleWebServerListener, error: Swift.Error)
        case compoundError([Error])
        case serverNotStopped
        case invalidStringToDataEncoding(String, encoding: String.Encoding)
    }
    
    public enum WebRequestIdentifier {
        case connectionId(String)
        case requestHead(HTTP.Request.Head, HTTP.Request.Headers?, connectionId: String)
        case request(HTTP.Request, connectionId: String)
        
        public var connectionId: String {
            switch self {
                case .connectionId(let rtn): return rtn
                case .requestHead(_, _, connectionId: let rtn): return rtn
                case .request(_, connectionId: let rtn): return rtn
            }
        }
    }
    
    public enum WebRequestError: Swift.Error {
        case connectionTimedOut(WebRequestIdentifier)
        case requestHeadReadFailure(WebRequestIdentifier, Swift.Error)
        case processRequestFailure(WebRequestIdentifier,
                                   serverIdentifier: String,
                                   clientIdentifier: String,
                                   error: Swift.Error)
        case badRequest(WebRequestIdentifier, Swift.Error?)
        case queueProcessError(HTTP.Response.ProcessQueue, WebRequestIdentifier, Swift.Error)
    }
    
    
    public enum State: Equatable {
        case starting
        case running
        case paused
        case stopping
        case stopped
        
        public static func ==(lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
                case (.starting, .starting): return true
                case (.running, .running): return true
                case (.paused, .paused): return true
                case (.stopping, .stopped): return true
                case (.stopped, .stopped): return true
                default: return false
            }
        }
    }
    
    public enum WorkerQueue: Hashable {
        case request
        //case websocket
        case other(AnyHashable)
        
        public static var websocket: WorkerQueue { return .other("websocket") }
        
        #if !swift(>=4.1)
        public var hashValue: Int {
            switch self {
                case .request: return 1.hashValue
                //case .websocket: return 2.hashValue
                case .other(let obj): return (3 + obj.hashValue)
            }
        }
        #endif
        
        #if swift(>=4.2)
        public func hash(into hasher: inout Hasher) {
            switch self {
            case .request: 1.hash(into: &hasher)
            //case .websocket: 2.hash(into: &hasher)
            case .other(let obj):
                hasher.combine(3)
                hasher.combine(obj)
            }
        }
        #endif
        
        public static func ==(lhs: WorkerQueue, rhs: WorkerQueue) -> Bool {
            switch (lhs, rhs) {
                case (.request, .request): return true
                //case (.websocket, .websocket): return true
                case (.other(let lhsO), .other(let rhsO)): return lhsO == rhsO
                default: return false
            }
        }
    }
    
    public enum RequestResponseEvent {
        case incomminRequest(HTTP.Request)
        case outgoingResposne(HTTP.Response.Details, for: HTTP.Request?)
    }
    
    private let httpCommunicator: LittleWebServerHTTPCommunicator
    //public var httpVersion: HTTP.Version { return self.httpCommunicator.httpVersion }
    public var serverHeader: String?
    
    internal static let dateHeaderFormatter: DateFormatter = {
        var rtn = DateFormatter()
        rtn.timeZone = TimeZone(identifier:"GMT")
        //Thu, 11 Aug 2016 15:23:13 GMT
        rtn.dateFormat = "E, d MMM yyyy HH:mm:ss z"
        
        return rtn
    }()
    
    
    internal var dateHeaderFormatter: DateFormatter { return LittleWebServer.dateHeaderFormatter }
    
    private let stateSyncLock = DispatchQueue(label: "LittleWebServer.state.sync")
    /// The current state of the web server
    public private(set) var state: State = .stopped
    
    private let listenerControlsSyncLock = DispatchQueue(label: "LittleWebServer.listeners.sync")
    private var listenerControls: [ListenerControl] = []
    
    public var initialRequestTimeoutInSeconds: Double = 7.0
    public static let DEFAULT_WORKER_COUNT: Int = -1
    
    private var waitStoppedSyncLock = DispatchSemaphore(value: 0)
    
    public var keepAliveDetails: HTTP.Headers.KeepAlive?
    
    private let serverErrorHandlerQueue = DispatchQueue(label: "LittleWebServer.serverErrorHandler.sync")
    public var serverErrorHandler: ((TrackableError) -> Void)? = nil
    
    public var allowConnection: ((_ connection: LittleWebServerClient) -> Bool) = { _ in return true }
    
    private let requestResponseEventHandlerQueue = DispatchQueue(label: "LittleWebServer.requestResponseEventHandler.async")
    public var requestResponseEventHandler: ((RequestResponseEvent) -> Void)? = nil
    
    internal lazy var stringTransformers: [String: (String) -> Any?] = {
        var rtn: [String: (String) -> Any?] = [:]
        
        rtn["String"] = { s -> Any? in
            return s
        }
        rtn["Bool"] = { s -> Any? in
            return Bool(s)
        }
        rtn["Float"] = { s -> Any? in
            return Float(s)
        }
        rtn["Double"] = { s -> Any? in
            return Double(s)
        }
        
        rtn["Int"] = { s -> Any? in
            return Int(s)
        }
        rtn["Int8"] = { s -> Any? in
            return Int8(s)
        }
        rtn["Int16"] = { s -> Any? in
            return Int16(s)
        }
        rtn["Int32"] = { s -> Any? in
            return Int32(s)
        }
        rtn["Int64"] = { s -> Any? in
            return Int64(s)
        }
        
        rtn["IntX"] = { s -> Any? in
            return Int(s, radix: 16)
        }
        rtn["IntX8"] = { s -> Any? in
            return Int8(s, radix: 16)
        }
        rtn["IntX16"] = { s -> Any? in
            return Int16(s, radix: 16)
        }
        rtn["IntX32"] = { s -> Any? in
            return Int32(s, radix: 16)
        }
        rtn["IntX64"] = { s -> Any? in
            return Int64(s, radix: 16)
        }
        
        rtn["IntB"] = { s -> Any? in
            return Int(s, radix: 2)
        }
        rtn["IntB8"] = { s -> Any? in
            return Int8(s, radix: 2)
        }
        rtn["IntB16"] = { s -> Any? in
            return Int16(s, radix: 2)
        }
        rtn["IntB32"] = { s -> Any? in
            return Int32(s, radix: 2)
        }
        rtn["IntB64"] = { s -> Any? in
            return Int64(s, radix: 2)
        }
        
        
        rtn["UInt"] = { s -> Any? in
            return UInt(s)
        }
        rtn["UInt8"] = { s -> Any? in
            return UInt8(s)
        }
        rtn["UInt16"] = { s -> Any? in
            return UInt16(s)
        }
        rtn["UInt32"] = { s -> Any? in
            return UInt32(s)
        }
        rtn["UInt64"] = { s -> Any? in
            return UInt64(s)
        }
        
        rtn["UIntX"] = { s -> Any? in
            return UInt(s, radix: 16)
        }
        rtn["UIntX8"] = { s -> Any? in
            return UInt8(s, radix: 16)
        }
        rtn["UIntX16"] = { s -> Any? in
            return UInt16(s, radix: 16)
        }
        rtn["UIntX32"] = { s -> Any? in
            return UInt32(s, radix: 16)
        }
        rtn["UIntX64"] = { s -> Any? in
            return UInt64(s, radix: 16)
        }
        
        rtn["UIntB"] = { s -> Any? in
            return UInt(s, radix: 2)
        }
        rtn["UIntB8"] = { s -> Any? in
            return UInt8(s, radix: 2)
        }
        rtn["UIntB16"] = { s -> Any? in
            return UInt16(s, radix: 2)
        }
        rtn["UIntB32"] = { s -> Any? in
            return UInt32(s, radix: 2)
        }
        rtn["UIntB64"] = { s -> Any? in
            return UInt64(s, radix: 2)
        }
        
        
        return rtn
        
    }()
    
    
    private var _extensionResourceTypes: [String: HTTP.Headers.ContentType.ResourceType] = [
        "aac": "audio/aac",
        "abw": "application/x-abiword",
        "arc": "application/x-freearc",
        "avi": "video/x-msvideo",
        "azw": "application/vnd.amazon.ebook",
        "bin": "application/octet-stream",
        "bmp": "image/bmp",
        "bz": "application/x-bzip",
        "bz2": "application/z-bzip2",
        "cda": "application/x-cdf",
        "csh": "application/x-csh",
        "css": "text/css",
        "csv": "text/csv",
        "doc": "application/msword",
        "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "eot": "application/vnd.ms-fontobject",
        "epub": "application/epub+zip",
        "gz": "application/gzip",
        "gif": "imaeg/gif",
        "htm": "text/html",
        "html": "text/html",
        "ico": "image/vnd.microsoft.icon",
        "ics": "text/calendar",
        "jar": "application/java-archive",
        "jpeg": "image/jpeg",
        "jpg": "image/jpeg",
        "js": "text/javascript",
        "json": "application/json",
        "jsonld": "application/ld+json",
        "mid": "audio/midi",
        "midi": "audio/midi",
        "mjs": "text/javascript",
        "mp3": "audio/mpeg",
        "mp4": "video/mp4",
        "mpeg": "video/mpeg",
        "mpkg": "application/vnd.apple.installer+xml",
        "odp": "application/vnd.oasis.opendocument.presentation",
        "ods": "application/vnd.oasis.document.spreadsheet",
        "odt": "application/vnd.oasis.opendocument.text",
        "oga": "audio/ogg",
        "ogv": "video/ogg",
        "ogx": "application/ogg",
        "opus": "audio/opus",
        "otf": "font/otf",
        "png": "image/png",
        "pdf": "application/pdf",
        "php": "application/x-httpd-php",
        "ppt": "application/vnd.ms-powerpoint",
        "pptx": "application/vnd.openxmlformats-officedocument.presentational.presentation",
        "rar": "application/vnd.rar",
        "rtf": "application/rtf",
        "sh": "application/x-sh",
        "svg": "image/svg+xml",
        "swf": "application/x-shockwave-flash",
        "tar": "application/x-tar",
        "tif": "image/tiff",
        "tiff": "image/tiff",
        "ts": "video/mp2t",
        "ttf": "font/ttf",
        "txt": "text/plaain",
        "vsd": "application/vnd.visio",
        "wav": "audio/wav",
        "weba": "audio/webm",
        "webm": "video/webm",
        "webp": "image/webp",
        "woff": "font/woff",
        "woff2": "font/woff2",
        "xhtml": "application/xhtml+xml",
        "xls": "application/vnd.ms-excel",
        "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "xml": "text/xml",
        "xul": "application/vnd.mozilla.xul+xml",
        "zip": "application/zip",
        "3gp": "video/3gpp",
        "3g2": "video/3gpp2",
        "7z": "application/x-7z-compressed"
        
        
    ]
    /// Dictionary of all content resource types
    public var extensionResourceTypes: [String: HTTP.Headers.ContentType.ResourceType] {
        get { return _extensionResourceTypes }
        set {
            var fixedNewValue: [String: HTTP.Headers.ContentType.ResourceType] = [:]
            for (k,v) in newValue {
                fixedNewValue[k.lowercased()] = v
            }
            _extensionResourceTypes = fixedNewValue
        }
    }


    /// Indicator if the server is in running state
    public var isRunning: Bool {
        return self.stateSyncLock.sync {
            return self.state == .running
        }
    }
    /// Indicator if the server is in starting or running states
    public var isStartingOrRunning: Bool {
        return self.stateSyncLock.sync {
            return self.state == .starting || self.state == .running
        }
    }
    /// Indicator if the server is in stopped state
    public var isStopped: Bool {
        return self.stateSyncLock.sync {
            return self.state == .stopped
        }
    }
    /// Indicator if the server is in stopping or stopped states
    public var isStoppingOrStopped: Bool {
        return self.stateSyncLock.sync {
            return self.state == .stopping || self.state == .stopped
        }
    }
    /// A list of the listenres being used by the web server
    public var listeners: [LittleWebServerListener] {
        get {
            return self.listenerControlsSyncLock.sync {
                return self.listenerControls.map({ return $0.listener })
            }
        }
    }
    /// The maximum workers allowed for the generate requests
    public var maxRequestWorkerCount: Int {
        get {
            return self.httpCommunicator.maxWorkerCounts[.request] ?? 0
        }
        set {
            precondition(newValue >= 0, "Max Request worker count must be >= 0")
            self.httpCommunicator.maxWorkerCounts[.request] = newValue
        }
    }
    /// The total maximun workers allowed for all queue types together
    public var maxTotalWorkerCount: Int {
        get { return self.httpCommunicator.maxTotalWorkerCount }
        set { self.httpCommunicator.maxTotalWorkerCount = newValue }
    }
    /// The current total worker count
    public var totalWorkerCount: UInt { return self.httpCommunicator.totalWorkerCount }
    /// Dictionary containing all max worker counts for the worker queues
    public var maxWorkerCounts: [LittleWebServer.WorkerQueue: Int] {
        get { return self.httpCommunicator.maxWorkerCounts }
        set {
            guard let requestCount = newValue[.request] else {
                preconditionFailure("Missing Count for  worker queue Request")
            }
            precondition(requestCount == -1 || requestCount > 0,
                         "Max '\(LittleWebServer.WorkerQueue.request)' Worker Queue Count must be -1 or greater than 0")
            
            for (key, val) in newValue {
                guard key != .request else {
                    continue
                }
                
                precondition(requestCount >= -1,
                             "Max '\(val)' Worker Queue Count must be >= -1")
                
            }
            
            self.httpCommunicator.maxWorkerCounts = newValue
        }
    }
    
    private var sessionManager: LittleWebServerSessionManager
    /// Routing based on a specific host
    public private(set) lazy var hosts: Routing.Requests.HostRoutes = .init(server: self)
    /// The default host routing.  Requests get routed here if the host value of the request is not within the hosts list
    public var defaultHost: Routing.Requests.RouteController {
        get { return self.hosts.default }
        set { self.hosts.default = newValue }
    }
    /// The defalut resource not found handler (defaultHost.resourceNotFoundHandler)
    public var resourceNotFoundHandler: (HTTP.Request) -> HTTP.Response {
        get { return self.defaultHost.resourceNotFoundHandler }
        set { self.defaultHost.resourceNotFoundHandler = newValue }
    }
    /// The default internal error handler (defaultHost.internalErrorHandler)
    public var internalErrorHandler: Routing.Requests.RouteController.InternalErrorHandler {
        get { return self.defaultHost.internalErrorHandler }
        set { self.defaultHost.internalErrorHandler = newValue }
    }
    /// The session Time Out Limit.
    public var sessionTimeOutLimit: TimeInterval {
        get { return self.sessionManager.sessionTimeOutLimit }
        set { self.sessionManager.sessionTimeOutLimit = newValue }
    }
    /// The queue to use when signaling session events
    public var sessionEventHandlersQueue: DispatchQueue {
        get { return self.sessionManager.eventHandlersQueue }
        set { self.sessionManager.eventHandlersQueue = newValue }
    }
    /// The event handler for when a session expires
    public var sessionExpiredEventHandler: ((LittleWebServerSession) -> Void)? {
        get { return self.sessionManager.sessionExpiredEventHandler }
        set { self.sessionManager.sessionExpiredEventHandler = newValue }
    }
    /// The event handler for when a session is invalidated
    public var invalidatingSessionEventHandler: ((LittleWebServerSession) -> Void)? {
        get { return self.sessionManager.invalidatingSessionEventHandler }
        set { self.sessionManager.invalidatingSessionEventHandler = newValue }
    }
    
    
    /// Create a new Web Server
    /// - Parameters:
    ///   - listeners: The list of listeners the server will acppet connections on
    ///   - maxRequestWorkerCount: The max number of works allowed for the general request queue
    ///   - maxWorkerQueueCounts: A dictionary containing all other Worker Queue max worker counts
    ///   - sessionManager: The session manager used to manage all session within the web server
    ///   - httpCommunicator: The communicator used for the communication between the server and the client
    public init(_ listeners: [LittleWebServerListener] = [],
                maxRequestWorkerCount: Int = LittleWebServer.DEFAULT_WORKER_COUNT,
                maxWorkerQueueCounts: [LittleWebServer.WorkerQueue: Int] = [:],
                sessionManager: LittleWebServerSessionManager,
                httpCommunicator: LittleWebServerHTTPCommunicator) {
        
        //precondition(maxRequestWorkerCount > 0, "Max Request Worker Queue Count must be greater than 0")
        
        var mxWorkerCounts = maxWorkerQueueCounts
        mxWorkerCounts[.request] = maxRequestWorkerCount
        
        httpCommunicator.maxWorkerCounts = mxWorkerCounts
        
        self.httpCommunicator = httpCommunicator
        self.sessionManager = sessionManager
        
        self.listenerControls = listeners.map {
            return try! self.createListenerControl(for: $0)
        }
        
    }
    
    /// Create a new Web Server
    /// - Parameters:
    ///   - listeners: The list of listeners the server will acppet connections on
    ///   - maxRequestWorkerCount: The max number of works allowed for the general request queue
    ///   - maxWorkerQueueCounts: A dictionary containing all other Worker Queue max worker counts
    ///   - sessionManager: The session manager used to manage all session within the web server
    ///   - httpCommunicator: The communicator used for the communication between the server and the client
    public convenience init(_ listeners: LittleWebServerListener...,
                            maxRequestWorkerCount: Int = LittleWebServer.DEFAULT_WORKER_COUNT,
                            maxWorkerQueueCounts: [LittleWebServer.WorkerQueue: Int] = [:],
                            sessionManager: LittleWebServerSessionManager,
                            httpCommunicator: LittleWebServerHTTPCommunicator) {
        
        self.init(listeners,
                  maxRequestWorkerCount: maxRequestWorkerCount,
                  maxWorkerQueueCounts: maxWorkerQueueCounts,
                  sessionManager: sessionManager,
                  httpCommunicator: httpCommunicator)
    }
    
    /// Register a Route String Transformer
    /// - Parameters:
    ///   - key: The transformer identifier
    ///   - transformer: The transforming function
    public func registerStringTransformer(_ key: String,
                                          transformer: @escaping (String) -> Any?) {
        self.stringTransformers[key] = transformer
    }
    
    /// Find a Route String Transformer
    /// - Parameter key: The transformer identifier
    /// - Returns: Returns the string transformer function if found or nil if not
    public func getStringTransformer(forKey key: String) -> ((String) -> Any?)? {
        return self.stringTransformers[key]
    }
    
    /// Create a new Listener Controller.  The controller manages the listener and monitors for incomming connections
    /// - Parameter listener: The listener to control
    /// - Returns: Returns the new Listener Controller
    private func createListenerControl(for listener: LittleWebServerListener) throws -> ListenerControl {
        let rtn = ListenerControl(listener,
                                  webserver: self)
        if self.isStartingOrRunning {
            try rtn.start()
        }
        return rtn
    }
    
    /// Add a new listener to the web server after the server has been created
    /// - Parameter listener: The new listener to add
    public func addListener(_ listener: LittleWebServerListener) throws {
        try self.listenerControlsSyncLock.sync {
            guard !self.listenerControls.contains(where: { $0.listener.uid == listener.uid }) else { return }
            let controller = try self.createListenerControl(for: listener)
            self.listenerControls.append(controller)
            self.listenerControls.sort()
        }
    }
    
    /// Remove the listener from the web server
    /// - Parameter listener: The listener to remove
    public func removeListener(_ listener: LittleWebServerListener) throws {
        self.listenerControlsSyncLock.sync {
            var index: Int? = nil
            for (i, value) in self.listenerControls.enumerated() {
                if value.listener.uid == listener.uid {
                    index = i
                    break
                }
            }
            guard let idx = index else {
                return
            }
            
            let controller = self.listenerControls.remove(at: idx)
            
            controller.stop()
            
        }
    }
    
    /// General event handler that gets called when a listener / Listener Controller has accepted a connection from a client
    private func onAcceptedClient(_ client: LittleWebServerClient,
                                  from listener: LittleWebServerListener) {
        
        self.httpCommunicator.onAcceptedClient(client,
                                               from: listener,
                                               server: self,
                                               sessionManager: self.sessionManager,
                                               signalRequestResponseEvent: self.signalRequestResponseEvent(_:),
                                               signalServerError: self.signalServerError(error:file:line:))
    }
    
    /// Signals a server error to be passed to the serverErrorHandler
    internal func signalServerError(_ error: TrackableError) {
        self.serverErrorHandlerQueue.async {
            self.serverErrorHandler?(error)
        }
    }
    
    #if swift(>=5.3)
    /// Signals a server error to be passed to the serverErrorHandler
    internal func signalServerError(error: Swift.Error, file: String = #filePath, line: Int = #line) {
        let tError: TrackableError = (error as? TrackableError) ?? TrackableError(error: error,
                                                                                  file: file,
                                                                                  line: line)
        signalServerError(tError)
    }
    
    #else
    /// Signals a server error to be passed to the serverErrorHandler
    internal func signalServerError(error: Swift.Error, file: String = #file, line: Int = #line ) {
        let tError: TrackableError = (error as? TrackableError) ?? TrackableError(error: error,
                                                                                  file: file,
                                                                                  line: line)
        signalServerError(tError)
    }
    #endif
    /// Signals a request response event calling requestResponseEventHandler
    internal func signalRequestResponseEvent(_ event: RequestResponseEvent) {
        self.requestResponseEventHandlerQueue.async {
            self.requestResponseEventHandler?(event)
        }
    }
    
    
    
    /// Get the content type of a resource with the given extension
    public func contentResourceType(forExtension ext: String) -> HTTP.Headers.ContentType.ResourceType? {
        return self._extensionResourceTypes[ext.lowercased()]
    }
    
    /// Start the server
    public func start() throws {
        try self.stateSyncLock.sync {
            guard self.state == .stopped else {
                throw WebServerError.serverNotStopped
            }
            
            self.state = .starting
            
            var startErrors: [WebServerError] = []
            
            for controller in self.listenerControls {
                do {
                    try controller.start()
                } catch {
                    startErrors.append(.startError(listener: controller.listener, error: error))
                }
            }
            
            if startErrors.count == self.listenerControls.count {
                self.state = .stopped
            } else {
            
                self.state = .running
            }
            
            if startErrors.count > 1 {
                throw WebServerError.compoundError(startErrors)
            } else if startErrors.count == 1 {
                throw startErrors.first!
            }
        }
    }
    /// Stop the server
    public func stop() {
        self.stateSyncLock.sync {
            guard self.state == .starting || self.state == .running else {
                return
            }
            
            for controller in self.listenerControls {
                controller.stop()
            }
            
            
            self.state = .stopped
            
            self.waitStoppedSyncLock.signal()
            
        }
    }
    /// Wait for the running server to stop
    public func waitUntilStopped() {
        guard self.isStartingOrRunning else { return }
        self.waitStoppedSyncLock.wait()
    }
    
}

internal extension LittleWebServer {
    static func basicHTMLBodyMessage(title: String? = nil,
                                     message: String) -> LittleWebServer.HTTP.Response.Body {
        var html: String = "<html>\n"
        if let t = title {
            html += "<title>\(t)</title>\n"
        }
        html += "<center><h1>\(message)</h1></center>\n"
        html += "</html>"
        
        return .html(html)
    }
    
    static func basicHTMLBodyMessageResponder(title: String? = nil,
                                              message: String) -> ((_ request: HTTP.Request) -> LittleWebServer.HTTP.Response.Body) {
        return { _ in
            return self.basicHTMLBodyMessage(title: title, message: message)
        }
    }
}

public extension LittleWebServer.HTTP.Response.Head {
    /// HTTP Continue (100)
    static func `continue`(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 100, message: "Continue", headers: headers)
    }
    /// HTTP Switching Protocol (101)
    static func switchProtocol(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 101, message: "Switching Protocol", headers: headers)
    }
    /// HTTP OK (200)
    static func ok(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 200, message: "OK", headers: headers)
    }
    /// HTTP Created (201)
    static func created(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 201, message: "Created", headers: headers)
    }
    /// HTTP Accepted (202)
    static func accepted(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 202, message: "Accepted", headers: headers)
    }
    /// HTTP No Content (204)
    static func noContent(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 204, message: "No Content", headers: headers)
    }
    /// HTTP Partial Content (206)
    static func partialContent(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 206, message: "Partial Content", headers: headers)
    }
    /// HTTP Moved Permanently (301)
    static func permanentlyMoved(location: String,
                                 headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        // Moved Permanently
        var headers = headers
        headers[.location] = location
        return .init(responseCode: 301, message: "Moved Permanently", headers: headers)
    }
    /// HTTP Temporarily Movied (302)
    static func temporarilyMoved(location: String,
                                 headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        var headers = headers
        headers[.location] = location
        return .init(responseCode: 302, message: "Temporarily Moved", headers: headers)
        
    }
    /// HTTP Not Modified (304)
    static func notModified(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 304, message: "Not Modified", headers: headers)
    }
    /// HTTP Temporarily Redirected (307)
    static func temporarilyRedirected(location: String,
                                      headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        var headers = headers
        headers[.location] = location
        return .init(responseCode: 307, message: "Temporarily Redirected", headers: headers)
        
    }
    /// HTTP Permanently Redirected (308)
    static func permanentlyRedirected(location: String,
                                       headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        // Moved Permanently
        var headers = headers
        headers[.location] = location
        return .init(responseCode: 308, message: "Permanently Redirected", headers: headers)
    }
    /// HTTP Bad Request (400)
    static func badRequest(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 400, message: "Bad Request", headers: headers)
    }
    /// HTTP Forbidden (403)
    static func forbidden(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 403, message: "Forbidden", headers: headers)
    }
    /// HTTP Not Found (404)
    static func notFound(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 404, message: "Not Found", headers: headers)
    }
    /// HTTP Not Allowed (405)
    static func notAllowed(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 405, message: "Not Allowed", headers: headers)
    }
    /// HTTP Not Accepted (406)
    static func notAccepted(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 406, message: "Not Accepted", headers: headers)
    }
    /// HTTP Request Timeout (408)
    static func requestTimeout(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 408, message: "Request Timeout", headers: headers)
    }
    /// HTTP Length Required (411)
    static func lengthRequired(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 411, message: "Length Required", headers: headers)
    }
    /// HTTP Precondition Failed (412)
    static func preconditionFailed(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 412, message: "Precondition Failed", headers: headers)
    }
    /// HTTP Unsupported Media Type (415)
    static func unsupportedMediaType(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 415, message: "Unsupported Media Type", headers: headers)
    }
    /// HTTP Range Not Satisfiable (416)
    static func rangeNotSatisfiable(fileSize: UInt,
                                    headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        var headers = headers
        headers[.contentRange] = "bytes */\(fileSize)"
        return .init(responseCode: 416, message: "Range Not Satisfiable", headers: headers)
    }
    /// HTTP Internal Error (500)
    static func internalError(headers: LittleWebServer.HTTP.Response.Headers = .init()) -> LittleWebServer.HTTP.Response.Head {
        return .init(responseCode: 500, message: "Internal Server Error", headers: headers)
    }
}

public extension LittleWebServer.HTTP.Response.Body {
    /// Create new plain text Response Body
    /// - Parameters:
    ///   - content: The body content
    ///   - encoding: The text encoding
    /// - Returns: Returns a new plain text Response Body
    static func plainText(_ content: String,
                          encoding: String.Encoding = .utf8) -> LittleWebServer.HTTP.Response.Body {
        return .text([.text(content)],
                     contentType: .plain,
                     encoding: encoding)
    }
    
    /// Create new HTML Response Body
    /// - Parameters:
    ///   - content: The body content
    ///   - encoding: The text encoding
    /// - Returns: Returns a new HTML Response Body
    static func html(_ content: String,
                     encoding: String.Encoding = .utf8) -> LittleWebServer.HTTP.Response.Body {
        return .text([.text(content)],
                     contentType: .html,
                     encoding: encoding)
    }
    
    /// Create new JSON String Response Body
    /// - Parameters:
    ///   - content: The body content
    ///   - encoding: The text encoding
    /// - Returns: Returns a new JSON Response Body
    static func jsonString(_ content: String,
                           encoding: String.Encoding = .utf8) -> LittleWebServer.HTTP.Response.Body {
        return .text([.text(content)],
                     contentType: .json,
                     encoding: encoding)
    }
    /// Create new JSON Response Body
    /// - Parameters:
    ///   - encodable: The encodable object to encode into JSON
    ///   - encoder: The encoder used to encode the object
    /// - Returns: Returns a new JSON Response Body
    static func json<T: Encodable>(_ encodable: T,
                                   encoder: JSONEncoder? = nil) throws -> LittleWebServer.HTTP.Response.Body {
        let enc = encoder ?? JSONEncoder()
        let dta = try enc.encode(encodable)
        return .data(dta, contentType: .json)
    }
}

public extension LittleWebServer.HTTP.Response {
    /// HTTP OK (200)
    static func ok(writeQueue: ProcessQueue = .current,
                          headers: Headers = .init(),
                          body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .ok(headers: headers),
                     body: body)
    }
    /// HTTP Created (201)
    static func created(writeQueue: ProcessQueue = .current,
                               headers: Headers = .init(),
                               body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .created(headers: headers),
                     body: body)
    }
    /// HTTP Accepted (202)
    static func accepted(writeQueue: ProcessQueue = .current,
                               headers: Headers = .init(),
                               body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .accepted(headers: headers),
                     body: body)
    }
    /// HTTP No Content (204)
    static func noContent(writeQueue: ProcessQueue = .current,
                          headers: Headers = .init()) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .noContent(headers: headers),
                     body: .empty)
    }
    /// HTTP Partial Content (206)
    static func partialContent(writeQueue: ProcessQueue = .current,
                                      headers: Headers = .init(),
                                      body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .partialContent(headers: headers),
                     body: body)
    }
    /// HTTP Not Modified (304)
    static func notModified(writeQueue: ProcessQueue = .current,
                                   headers: Headers = .init(),
                                   body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .notModified(headers: headers),
                     body: body)
    }
    /// HTTP Range Not Satisfiable (416)
    static func rangeNotSatisfiable(writeQueue: ProcessQueue = .current,
                                   fileSize: UInt,
                                   headers: Headers = .init(),
                                   body: Body = .empty) -> LittleWebServer.HTTP.Response {
           return .init(writeQueue: writeQueue,
                        head: .rangeNotSatisfiable(fileSize: fileSize, headers: headers),
                        body: body)
    }
    /// HTTP Forbidden (403)
    static func forbidden(writeQueue: ProcessQueue = .current,
                                headers: Headers = .init(),
                                body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .forbidden(headers: headers),
                     body: body)
    }
    /// HTTP Not Found (404)
    static func notFound(writeQueue: ProcessQueue = .current,
                                headers: Headers = .init(),
                                body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .notFound(headers: headers),
                     body: body)
    }
    /// HTTP Not Accepted (406)
    static func notAccepted(writeQueue: ProcessQueue = .current,
                                   headers: Headers = .init(),
                                   body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                        head: .notAccepted(headers: headers),
                        body: body)
    }
    /// HTTP Request Timeout (408)
    static func requestTimeout(writeQueue: ProcessQueue = .current,
                                      headers: Headers = .init(),
                                      body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                        head: .requestTimeout(headers: headers),
                        body: body)
    }
    /// HTTP Length Required (411)
    static func lengthRequired(writeQueue: ProcessQueue = .current,
                                      headers: Headers = .init(),
                                      body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .lengthRequired(headers: headers),
                     body: body)
    }
    /// HTTP Precondition Failed (412)
    static func preconditionFailed(writeQueue: ProcessQueue = .current,
                                          headers: Headers = .init(),
                                          body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .preconditionFailed(headers: headers),
                     body: body)
    }
    /// HTTP Unsupported Media Type (415)
    static func unsupportedMediaType(writeQueue: ProcessQueue = .current,
                                            headers: Headers = .init(),
                                            body: Body = .empty) -> LittleWebServer.HTTP.Response {
          return .init(writeQueue: writeQueue,
                       head: .unsupportedMediaType(headers: headers),
                       body: body)
    }
    /// HTTP Bad Request (400)
    static func badRequest(writeQueue: ProcessQueue = .current,
                                  headers: Headers = .init(),
                                  body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .badRequest(headers: headers),
                     body: body)
    }
    /// HTTP Temporarily Movied (302)
    static func temporarilyMoved(location: String,
                                        writeQueue: ProcessQueue = .current,
                                        headers: Headers = .init(),
                                        body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .temporarilyMoved(location: location, headers: headers),
                     body: body)
        
    }
    /// HTTP Moved Permanently (301)
    static func permanentlyMoved(location: String,
                                        writeQueue: ProcessQueue = .current,
                                        headers: Headers = .init(),
                                        body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .permanentlyMoved(location: location, headers: headers),
                     body: body)
    }
    /// HTTP Internal Error (500)
    static func internalError(writeQueue: ProcessQueue = .current,
                                     headers: Headers = .init(),
                                     body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .internalError(headers: headers),
                     body: body)
    }
    /// HTTP Switching Protocol (101)
    static func switchProtocol(writeQueue: ProcessQueue = .current,
                               headers: Headers = .init(),
                               body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .switchProtocol(headers: headers),
                     body: body)
    }
    /// HTTP Continue (100)
    static func `continue`(writeQueue: ProcessQueue = .current,
                          headers: Headers = .init(),
                          body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .continue(headers: headers),
                     body: body)
    }
    /// HTTP Not Allowed (405)
    static func notAllowed(writeQueue: ProcessQueue = .current,
                          headers: Headers = .init(),
                          body: Body = .empty) -> LittleWebServer.HTTP.Response {
        return .init(writeQueue: writeQueue,
                     head: .notAllowed(headers: headers),
                     body: body)
    }
}


#if swift(>=4.1)
extension LittleWebServer.Helpers.OpenEnum: Equatable
    where Enum.RawValue: Equatable { }

extension LittleWebServer.Helpers.OpenEnum: LittleWebServerOpenEquatableRawRepresentable
    where Enum.RawValue: Equatable { }
#endif

public extension LittleWebServer.HTTP.Headers.WeightedObject where T: LittleWebServerOpenRawRepresentable {
    init(object: T.Enum) {
        self.init(object: T(object))
    }
}


public func ==<T>(lhs: LittleWebServer.HTTP.Headers.WeightedObject<T>, rhs: T) -> Bool {
    return lhs.object == rhs
}
extension LittleWebServer.HTTP.Headers.WeightedObject where T: LittleWebServerSimilarOperator {
    public static func ~=(lhs: LittleWebServer.HTTP.Headers.WeightedObject<T>, rhs: T) -> Bool {
        return lhs.object == rhs || lhs.object ~= rhs
    }
}

public extension LittleWebServer.HTTP.Headers.WeightedObject where T == LittleWebServer.HTTP.Headers.AcceptLanguage {
    
    var identity: String { return self.object.identity }
    var isAnyLanguage: Bool { return self.object.isAnyLanguage }
    var locale: Locale? { return self.object.locale }
    
}

// MARK:- Operators
public func ~=(lhs: LittleWebServer.HTTP.Headers.ContentType?,
               rhs: LittleWebServer.HTTP.Headers.ContentType) -> Bool {
    guard let lhs = lhs else { return false }
    return lhs ~= rhs
}

public func ~=(lhs:  LittleWebServer.HTTP.Headers.ContentType.ResourceType?,
               rhs: LittleWebServer.HTTP.Headers.ContentType.ResourceType) -> Bool {
    guard let lhs = lhs else { return false }
    return lhs ~= rhs
}

public func ~=(lhs:  LittleWebServer.HTTP.Headers.ContentType.ResourceType.Group?,
               rhs: LittleWebServer.HTTP.Headers.ContentType.ResourceType.Group) -> Bool {
    guard let lhs = lhs else { return false }
    return lhs ~= rhs
}

public func ~=(lhs:  LittleWebServer.HTTP.Headers.ContentType.ResourceType.GroupType?,
               rhs: LittleWebServer.HTTP.Headers.ContentType.ResourceType.GroupType) -> Bool {
    guard let lhs = lhs else { return false }
    return lhs ~= rhs
}

public func ~=(lhs: LittleWebServer.HTTP.Version?,
               rhs: LittleWebServer.HTTP.Version) -> Bool {
    guard let lhs = lhs else { return false }
    return lhs ~= rhs
}

public func ~=(lhs: LittleWebServer.HTTP.Headers.AcceptLanguage?,
               rhs: LittleWebServer.HTTP.Headers.AcceptLanguage) -> Bool {
    guard let lhs = lhs else { return false }
    return lhs ~= rhs
}
