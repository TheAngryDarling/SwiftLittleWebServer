//
//  LittleWebServerSocketConnection.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-17.
//

import Foundation
import Dispatch
import SynchronizeObjects


public extension LittleWebServerSocketConnection {
    /// Represention of a Socket Descriptor
    typealias SocketDescriptor = Int32
}

public extension LittleWebServerSocketConnection {
    /// The socket family
    enum AddressFamily: RawRepresentable, CustomStringConvertible {
        /// An IP4 connection
        case inet4
        /// An IP6 connection
        case inet6
        /// A Unix File connection
        case unix
        
        public var description: String {
            switch self {
                case .inet4: return "inet4"
                case .inet6: return "inet6"
                case .unix: return "unix"
            }
        }
        
        public var rawValue: Int32 {
            #if os(Linux)
            switch self {
                case .inet4: return Int32(AF_INET)
                case .inet6: return Int32(AF_INET6)
                case .unix: return Int32(AF_UNIX)
            }
            #else
            switch self {
                case .inet4: return AF_INET
                case .inet6: return AF_INET6
                case .unix: return AF_UNIX
            }
            #endif
        }
        
        public init?(rawValue: Int32) {
            switch rawValue {
                case AF_INET: self = .inet4
                case AF_INET6: self = .inet6
                case AF_UNIX: self = .unix
                default: return nil
            }
        }
    }
    /// The Socket Protocol
    enum AddressProtocol: RawRepresentable, CustomStringConvertible {
        /// A TCP/IP communication protocol
        case tcp
        /// A Unix File communication protocol
        case unix
        
        public var description: String {
            switch self {
                case .tcp: return "tcp"
                case .unix: return "unix"
            }
        }
        
        //IPPROTO
        public var rawValue: Int32 {
            switch self {
                case .tcp:
                    #if os(Linux)
                    return Int32(IPPROTO_TCP)
                    #else
                    return IPPROTO_TCP
                    #endif
                case .unix: return 0
            }
        }
        
        public init?(rawValue: Int32) {
            switch rawValue {
                case Int32(IPPROTO_TCP): self = .tcp
                case 0: self = .unix
                default: return nil
            }
        }
    }
    /// Socket Address
    enum Address: LittleWebServerExpressibleByStringInterpolation {
        #if os(Linux)
        /// Representation of the character block used to store the path to the Unix Socket File
        /// On Linux this is 108 bytes.
        /// On Mac this is 104 bytes
        public typealias SunPath = (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar)
        #else
        /// Representation of the character block used to store the path to the Unix Socket File
        /// On Linux this is 108 bytes.
        /// On Mac this is 104 bytes
        public typealias SunPath = (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar)
        #endif
        
        /// Representation of a TCP/IP Port
        public struct TCPIPPort: RawRepresentable,
                                 ExpressibleByIntegerLiteral,
                                 Comparable,
                                 CustomStringConvertible {
            
            /// Represents first available port
            public static let firstAvailable: TCPIPPort = 0
                        
            public var rawValue: UInt16
            
            public var description: String { return "\(self.rawValue)" }
            
            public var sockaddrPort: in_port_t {
                return htons(self.rawValue)
            }
            
            public init(rawValue value: UInt16) { self.rawValue = value }
            
            public init?(_ string: String) {
                guard let v = UInt16(string) else { return nil }
                self.init(rawValue: v)
            }
            public init(integerLiteral value: UInt16) {
                self.init(rawValue: value)
            }
            public init(sockaddrPort: in_port_t) {
                self.init(rawValue: ntohs(sockaddrPort))
            }
            
            public static func ==(lhs: TCPIPPort, rhs: TCPIPPort) -> Bool {
                return lhs.rawValue == rhs.rawValue
            }
            public static func <(lhs: TCPIPPort, rhs: TCPIPPort) -> Bool {
                return lhs.rawValue < rhs.rawValue
            }
            
            public static func ==<Other>(lhs: TCPIPPort, rhs: Other) -> Bool where Other: BinaryInteger {
                return lhs.rawValue == rhs
            }
            public static func < <Other>(lhs: TCPIPPort, rhs: Other) -> Bool where Other: BinaryInteger {
                return lhs.rawValue < rhs
            }
            
        }

        /// IP Socket Address
        public enum IP: LittleWebServerExpressibleByStringInterpolation, Equatable {
            /// The IP Address Family
            public enum Family: RawRepresentable,
                                CustomStringConvertible,
                                LittleWebServerRawValueHashable {
                /// An IP4 connection
                case inet4
                /// An IP6 connection
                case inet6
                
                public var description: String {
                    switch self {
                        case .inet4: return "inet4"
                        case .inet6: return "inet6"
                    }
                }
                
                public var addressFamily: AddressFamily {
                    switch self {
                        case .inet4: return .inet4
                        case .inet6: return .inet6
                    }
                }
                
                public var rawValue: Int32 {
                    #if os(Linux)
                    switch self {
                        case .inet4: return Int32(AF_INET)
                        case .inet6: return Int32(AF_INET6)
                    }
                    #else
                    switch self {
                        case .inet4: return AF_INET
                        case .inet6: return AF_INET6
                    }
                    #endif
                }
                
                public init?(rawValue: Int32) {
                    switch rawValue {
                        case AF_INET: self = .inet4
                        case AF_INET6: self = .inet6
                        default: return nil
                    }
                }
                
                public static func ==(lhs: Family, rhs: Family) -> Bool {
                    switch (lhs, rhs) {
                        case (.inet4, .inet4): return true
                        case (.inet6, .inet6): return true
                        default: return false
                    }
                }
            }
            /// Represents a Set of Family options
            public typealias Families = Set<Family>
            
            
            
            /// IP Errors
            public enum Error: Swift.Error, CustomStringConvertible {
                /// IP AddrInfo Errors
                public enum AddrInfoError: RawRepresentable, Swift.Error, CustomStringConvertible {
                    /// A direct AddrInfo Error Code
                    case raw(Int32)
                    /// A System Error Code
                    case system(CInt)
                    
                    public var rawValue: Int32 {
                        switch self {
                            case .raw(let rtn): return rtn
                            case .system(_): return EAI_SYSTEM
                        }
                    }
                    
                    public var description: String {
                        switch self {
                        case .raw(let code):
                            return String(cString: gai_strerror(code))
                        case .system(let code):
                            return "SYSTEM ERROR [ " + LittleWebServerSocketSystemError(errno: code).message + " ]"
                        }
                    }
                    
                    public init(rawValue: Int32) {
                        switch rawValue {
                            case EAI_SYSTEM: self = .system(errno)
                            default: self = .raw(rawValue)
                        }
                    }
                    
                    public static func ==(lhs: AddrInfoError, rhs: AddrInfoError) -> Bool {
                        switch (lhs, rhs) {
                            case (.raw(let lhsC), .raw(let rhsC)):
                                return lhsC == rhsC
                            case (.system(let lhsE), .system(let rhsE)):
                                return lhsE == rhsE
                            default: return false
                        }
                    }
                    
                    public static func ==(lhs: AddrInfoError, rhs: Int32) -> Bool {
                        return lhs.rawValue == rhs
                    }
                }
                
                /// An AddrInfo Error
                case adderinfo(AddrInfoError)
                /// The given AddressProtocol in invalid
                case invalidProtocolFamilyType(Int32)
                /// A System Error
                case systemError(LittleWebServerSocketSystemError)
                /// The given string contains an invalid address
                case invalidIPAddress(String)
                
                public var description: String {
                    switch self {
                    case .adderinfo(let info):
                        return info.description
                    case .systemError(let err):
                        return err.description
                    case .invalidProtocolFamilyType(let ft):
                        return "Invalid Protocol Family Type '\(ft)'"
                    case .invalidIPAddress(let address):
                        return "Invalid IP Address '\(address)'"
                    }
                }
            }

            /// IPv4 Socket Address
            case v4(in_addr)
            
            /// IPv6 Socket Address
            case v6(in6_addr)
            
            
            /// Representation of an IPv4 address of 0.0.0.0
            public static let anyIPv4: IP = "0.0.0.0"
            /// Representation of an IPv4 Loopback address (127.0.0.1)
            public static let ipV4Loopback: IP = "127.0.0.1"
            // Representation of an IPv6 address of ::
            public static let anyIPv6: IP = "::"
            /// Representation of an IPv6 Loopback address (::1)
            public static let ipV6Loopback: IP = "::1"

            /// Size of the ip socket address.
            public var sockAddrSize: Int {
                switch self {
                    case .v4(_):
                        return MemoryLayout<(sockaddr_in)>.size
                    case .v6(_):
                        return MemoryLayout<(sockaddr_in6)>.size
                }
            }
            
            /// The protocol family of the address
            public var family: Family {
                switch self {
                    case .v4(_):
                        return .inet4
                    case .v6(_):
                        return .inet6
                }
            }
            /*
            public var family: AddressFamily {
                switch self {
                    case .v4(_):
                        return .inet4
                    case .v6(_):
                        return .inet6
                }
            }
            */
            
            /// The string representation of the IP Address
            public var node: String {
                var buf: [CChar]
                switch self {
                    case .v4(let addr):
                        var addr = addr
                        buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                        inet_ntop(self.family.rawValue, &addr, &buf, socklen_t(buf.count))
                    case .v6(let addr):
                        var addr = addr
                        buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                        inet_ntop(self.family.rawValue, &addr, &buf, socklen_t(buf.count))
                }
                
                return String(validatingUTF8: buf) ?? ""
            }
            
            public var description: String {
                return "\(self.node)"
            }
            
            public init(_ string: String) throws {
                if string.contains(".") {
                    var addr = in_addr()
                    let status: Int32 = inet_pton(Int32(AF_INET), string, &addr)
                    if status == 0 {
                        throw Error.invalidIPAddress(string)
                    } else if status < 0 {
                        throw Error.systemError(.current())
                    } else {
                        self = IP.v4(addr)
                    }
                } else {
                    var addr = in6_addr()
                    let status: Int32 = inet_pton(Int32(AF_INET6), string, &addr)
                    if status == 0 {
                        throw Error.invalidIPAddress(string)
                    } else if status < 0 {
                        throw Error.systemError(.current())
                    } else {
                        self = IP.v6(addr)
                        
                    }
                }
            }
            
            
            public init(stringLiteral value: String) {
                do {
                    try self.init(value)
                } catch {
                    fatalError("Invalid IP Address: \(error)")
                }
            }
            
            public static func ==(lhs: IP, rhs: IP) -> Bool {
                switch (lhs, rhs) {
                    case (.v4(_), .v4(_)):
                        return lhs.description == rhs.description
                    case (.v6(_), .v6(_)):
                            return lhs.description == rhs.description
                    default: return false
                }
            }
        }
        /// Address Error
        public enum Error: Swift.Error {
            case ip(IP.Error)
            case invalidIP6Address(String)
            case invalidPortNumber(String)
            case unixPathTooLong(max: Int, current: Int)
        }
        /// Represents a TCP/IP address
        case ip(IP, port: TCPIPPort)

        /// Represents a Unix File address
        case unix(SunPath, count: UInt8)
        
        /// The IP Address of the socket (if the socket is a TCP/IP socket)
        public var ipAddress: IP? {
            guard case .ip(let rtn, port: _) = self else { return nil }
            return rtn
        }
        /// The TCP/IP port of the socket (if the socket is a TCP/IP socket)
        public var tcpPort: TCPIPPort? {
            guard case .ip(_, port: let rtn) = self else { return nil }
            return rtn
        }
        
        /// The SunPath of the socket(if the socket is a Unix File socket)
        public var unixSunPath: SunPath? {
            guard case .unix(let rtn, count: _) = self else { return nil }
            return rtn
        }
        /// The number of characters in the unixSunPath of the socket(if the socket is a Unix File socket)
        public var unixPathCount: UInt8? {
            guard case .unix(_, count: let rtn) = self else { return nil }
            return rtn
        }
        /// The path to the socket file of the socket(if the socket is a Unix File socket)
        public var unixPath: String? {
            guard var sunPath = self.unixSunPath else { return nil }
            let rtn: String? = withUnsafeMutablePointer(to: &sunPath.0) {
                return String.init(validatingUTF8: $0)
            }
            return rtn
        }

        /// Size of the socket address
        public var sockAddrSize: Int {
            switch self {
            case .ip(let ip, port: _):
                return ip.sockAddrSize
            case .unix(_, count: _):
                return MemoryLayout<(sockaddr_un)>.size
            }
        }
        
        /// The protocol family of the address. (Readonly)
        public var family: AddressFamily {
            switch self {
            case .ip(let ip, port: _):
                return ip.family.addressFamily
            case .unix(_, count: _):
                return .unix
            }
        }
        /// The socket protocol used
        public var proto: AddressProtocol {
            switch self {
                case .ip(_, port: _):
                    return .tcp
                case .unix(_, count: _):
                    return .unix
            }
        }
        
        public var description: String {
            
            switch self {
                case .ip(let ip, port: let port):
                    var rtn = ip.node
                    if port != 0 {
                        if ip.family == .inet6 {
                            rtn = "[" + rtn + "]"
                        }
                        rtn += ":\(port)"
                    }
                    return rtn
                case .unix(_, count: _):
                    let rtn = self.unixPath
                    
                    guard rtn != nil else { return "Unknown Unix File Path"}
                    return "unix://" + rtn!
            }
        }
        
        public init(_ string: String) throws {
            
            if !string.hasPrefix("unix://") {
                var ipAddressString = string
                var portString = ""
                var port: TCPIPPort = 0
                var portSearchRange: Range<String.Index> = ipAddressString.startIndex..<ipAddressString.endIndex
                let ip6CloseBraceRange = ipAddressString.range(of: "]", options: .backwards)
                if let r2 = ip6CloseBraceRange,
                   ipAddressString.hasPrefix("[") {
                    portSearchRange = r2.upperBound..<ipAddressString.endIndex
                }
                if let r = ipAddressString.range(of: ":", options: .backwards, range: portSearchRange) {
                    if ipAddressString.hasPrefix("[") {
                        guard let r2 = ip6CloseBraceRange else {
                            throw Error.invalidIP6Address(ipAddressString)
                        }
                        portString = String(ipAddressString[r.upperBound...])
                        // Get everything from beginning upto ]
                        ipAddressString = String(ipAddressString[..<r2.lowerBound])
                        // Remove [
                        ipAddressString.removeFirst()
                       
                    } else {
                        var quoteCount: Int = 0
                        if !ipAddressString.contains(where: { if $0 == ":" { quoteCount += 1}; return quoteCount > 1 }) {
                            portString = String(ipAddressString[r.upperBound...])
                            ipAddressString = String(ipAddressString[..<r.lowerBound])
                        }
                    }
                    
                } else if ipAddressString.hasPrefix("[") && ipAddressString.hasSuffix("]") {
                    ipAddressString.removeFirst()
                    ipAddressString.removeLast()
                }
                
                if !portString.isEmpty {
                    guard let p = TCPIPPort(portString) else {
                        throw Error.invalidPortNumber(portString)
                    }
                    port = p
                }
                
                let ip = try IP.init(ipAddressString)
                self = .ip(ip, port: port)
            
            } else {
                var path = string
                path.removeFirst("unix://".count)
                
                var addr = sockaddr_un()
                //addr.sun_family = sa_family_t(AF_LOCAL)
                addr.sun_family = sa_family_t(AF_UNIX)
                
                let sunPahSize = MemoryLayout.size(ofValue: addr.sun_path)
                
                if path.utf8.count >= sunPahSize {
                    throw Error.unixPathTooLong(max: sunPahSize-1, current: path.utf8.count)
                }
                
                
                // Copy the path to the remote address...
                _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in

                    path.withCString {
                        strncpy(ptr, $0, path.utf8.count)
                    }
                }
                
                self = .unix(addr.sun_path, count: UInt8(path.utf8.count))

                /*
                #if !os(Linux)
                addr.sun_len = UInt8(MemoryLayout<UInt8>.size + MemoryLayout<sa_family_t>.size + path.utf8.count + 1)
                #endif
                */
                
            }
        }
        
        public init(stringLiteral value: String) {
            do {
                try self.init(value)
            } catch {
                fatalError("Invalid Address: \(error)")
            }
        }
        
        /// Converts a sockaddr_in into a Address
        public static func from(addr: sockaddr_in) -> Address {
            
            return .ip(.v4(addr.sin_addr), port: TCPIPPort(sockaddrPort: addr.sin_port))
        }
        /// Converts a sockaddr_in6 into a Address
        public static func from(addr: sockaddr_in6) -> Address {
            return .ip(.v6(addr.sin6_addr), port: TCPIPPort(sockaddrPort: addr.sin6_port))
        }
        /// Converts a sockaddr_un into a Address
        public static func from(addr: sockaddr_un) -> Address {
            #if os(Linux)
            return .unix(addr.sun_path, count: UInt8(MemoryLayout<SunPath>.size))
            #else
            return .unix(addr.sun_path, count: addr.sun_len)
            #endif
        }
        /// Converts a sockaddr into a Address
        public static func from(addr: sockaddr) -> Address? {
            var addr = addr
            switch Int32(addr.sa_family) {
                case AF_INET:
                    return withUnsafePointer(to: &addr) {
                        return $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                            return Address.from(addr: $0.pointee)
                        }
                    }
                case AF_INET6:
                    return withUnsafePointer(to: &addr) {
                        return $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                            return Address.from(addr: $0.pointee)
                        }
                    }
                case AF_UNIX:
                    return withUnsafePointer(to: &addr) {
                        return $0.withMemoryRebound(to: sockaddr_un.self, capacity: 1) {
                            return Address.from(addr: $0.pointee)
                        }
                    }
                default:
                    return nil
            }
        }
        
        /// Provides access to the sockaddr pointer of the address
        /// - Parameter body: A closure that takes a pointer to the address and the size of the socket
        /// - Returns: The return value, if any, of the `body` closure.
        public func withUnsafeSocketAddrPointer<R>(_ body: (UnsafePointer<sockaddr>, Int) throws -> R) rethrows -> R {
            switch self {
            case .ip(let ip, port: let port):
                switch ip {
                    
                    case .v4(let address):
                        var addr = sockaddr_in()
                        addr.sin_addr = address
                        addr.sin_family = sa_family_t(AF_INET)
                        addr.sin_port = port.sockaddrPort
                        
                        return try withUnsafePointer(to: &addr) {
                            return try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                                return try body($0, MemoryLayout<(sockaddr_in)>.size)
                            }
                        }
                        
                    case .v6(let address):
                        var addr = sockaddr_in6()
                        addr.sin6_addr = address
                        addr.sin6_family = sa_family_t(AF_INET6)
                        addr.sin6_port = port.sockaddrPort
                        
                        return try withUnsafePointer(to: &addr) {
                            return try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                                return try body($0, MemoryLayout<(sockaddr_in6)>.size)
                            }
                        }
                }
            
            case .unix(let path, count: let count):
                var addr = sockaddr_un()
                //addr.sun_family = sa_family_t(AF_LOCAL)
                addr.sun_family = sa_family_t(AF_UNIX)
                addr.sun_path = path
            
                #if !os(Linux)
                addr.sun_len = UInt8(MemoryLayout<UInt8>.size + MemoryLayout<sa_family_t>.size + Int(count) + 1)
                #endif
                
                return try withUnsafePointer(to: &addr) {
                    return try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        return try body($0, MemoryLayout<(sockaddr_un)>.size)
                    }
                }
            
            }
        }
    }
    
    
    
    enum SocketError: Swift.Error {
        case addressError(LittleWebServerSocketConnection.Address.Error)
        case unableToCreateSocket(systemError: LittleWebServerSocketSystemError)
        case socketSettingReUseAddrFailed(systemError: LittleWebServerSocketSystemError)
        case socketSettingNoSigPipFailed(systemError: LittleWebServerSocketSystemError)
        case socketSettingIPv6IPv4PortSharingFailed(systemError: LittleWebServerSocketSystemError)
        case socketBindFailed(Swift.Error)
        case socketBindFailureNoAvailableOptions
        case socketListeningFailed(systemError: LittleWebServerSocketSystemError)
        case unableToFindValidHostIP
        case unableToRetriveSocketName(systemError: LittleWebServerSocketSystemError)
        
        case invalidSocketDescriptor(systemError: LittleWebServerSocketSystemError)
        case missingSocketDescriptor
        case socketNotConnected
        case socketNotListening
        case socketAcceptFailed(systemError: LittleWebServerSocketSystemError)
        case socketWrongClientSocketProtocol
        case socketUnabletToLoadClientSocket
        
        public struct Address {
            private init() { }
            
            public static func ip(_ err: LittleWebServerSocketConnection.Address.IP.Error) -> SocketError {
                return .addressError(.ip(err))
            }
            public static func unixPathTooLong(max: Int, current: Int) -> SocketError {
                return .addressError(.unixPathTooLong(max: max, current: current))
            }
        }
    }
}

extension LittleWebServerSocketConnection.Address.IP {
    
    init?(addressInfo: addrinfo) {
        
        switch Int32(addressInfo.ai_family) {
            case AF_INET:
                self = addressInfo.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    var addr = sockaddr_in()
                    memcpy(&addr, $0, Int(MemoryLayout<sockaddr_in>.size))
                    return LittleWebServerSocketConnection.Address.IP.v4(addr.sin_addr)
                }
            case AF_INET6:
                self = addressInfo.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                    var addr = sockaddr_in6()
                    memcpy(&addr, $0, Int(MemoryLayout<sockaddr_in6>.size))
                    return LittleWebServerSocketConnection.Address.IP.v6(addr.sin6_addr)
                }
            default:
                return nil
        }
    }
    
    
    /// Creates a Socket.Address
    ///
    /// - Parameter addressProvider: Tuple containing pointers to the sockaddr and its length.
    /// - Returns: Newly initialized Socket.Address.
    init?(addressProvider: (UnsafeMutablePointer<sockaddr>, UnsafeMutablePointer<socklen_t>) throws -> Void) rethrows {
        
        var addressStorage = sockaddr_storage()
        var addressStorageLength = socklen_t(MemoryLayout.size(ofValue: addressStorage))
        try withUnsafeMutablePointer(to: &addressStorage) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { addressPointer in
                try withUnsafeMutablePointer(to: &addressStorageLength) { addressLengthPointer in
                    try addressProvider(addressPointer, addressLengthPointer)
                }
            }
        }
        
        switch Int32(addressStorage.ss_family) {
            case AF_INET:
                self = Swift.withUnsafePointer(to: &addressStorage) {
                    return $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                        return LittleWebServerSocketConnection.Address.IP.v4($0.pointee.sin_addr)
                    }
                }
            case AF_INET6:
                self = Swift.withUnsafePointer(to: &addressStorage) {
                    return $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                        return LittleWebServerSocketConnection.Address.IP.v6($0.pointee.sin6_addr)
                    }
                }
            default:
                return nil
        }
    }
}

extension LittleWebServerSocketConnection.Address {
    
    /// Creates a Socket.Address
    ///
    /// - Parameter ddressProvider: Tuple containing pointers to the sockaddr and its length.
    /// - Returns: Newly initialized Socket.Address.
    init?(addressProvider: (UnsafeMutablePointer<sockaddr>, UnsafeMutablePointer<socklen_t>) throws -> Void) rethrows {
        
        var addressStorage = sockaddr_storage()
        var addressStorageLength = socklen_t(MemoryLayout.size(ofValue: addressStorage))
        try withUnsafeMutablePointer(to: &addressStorage) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { addressPointer in
                try withUnsafeMutablePointer(to: &addressStorageLength) { addressLengthPointer in
                    try addressProvider(addressPointer, addressLengthPointer)
                }
            }
        }
        
        switch Int32(addressStorage.ss_family) {
            case AF_INET:
                self = addressStorage.asIP4Address {
                    return LittleWebServerSocketConnection.Address.from(addr: $0.pointee)
                }
            case AF_INET6:
                self = addressStorage.asIP6Address {
                    return LittleWebServerSocketConnection.Address.from(addr: $0.pointee)
                }
            case AF_UNIX:
                self = addressStorage.asUnixAddress {
                    return LittleWebServerSocketConnection.Address.from(addr: $0.pointee)
                }
            default:
                return nil
        }
    }
    
    init?(addressInfo: addrinfo) {
        var addressInfo = addressInfo
        //TCPIPPort(ntohs(addr.sin6_port))
        switch Int32(addressInfo.ai_family) {
            case AF_INET:
                self = addressInfo.asIP4Address {
                    return .ip(.v4($0.pointee.sin_addr), port: TCPIPPort(sockaddrPort: $0.pointee.sin_port))
                }
            case AF_INET6:
                self = addressInfo.asIP6Address {
                    return .ip(.v6($0.pointee.sin6_addr), port: TCPIPPort(sockaddrPort: $0.pointee.sin6_port))
                }
                
            case AF_UNIX:
                self = addressInfo.asUnixAddress {
                    #if os(Linux)
                    let count: UInt8 = UInt8(MemoryLayout<SunPath>.size)
                    #else
                    var count: UInt8 = $0.pointee.sun_len
                    count -= UInt8(MemoryLayout<UInt8>.size + MemoryLayout<sa_family_t>.size)
                    count -= 1
                    #endif
                    
                    return .unix($0.pointee.sun_path, count: count)
                }
            default:
                return nil
        }
    }
}




open class LittleWebServerSocketConnection: NSObject {
    /// Representation of an invalid socket descriptor
    public static let SOCKET_INVALID_DESCRIPTOR: SocketDescriptor = -1
    
    
    private let _socketDescriptor: SyncLockObj<SocketDescriptor>
    /// The current socket descriptor of the connection
    public var socketDescriptor: SocketDescriptor {
        return self._socketDescriptor.value
    }
    /// Indicator if the current socket is connected
    open var isConnected: Bool {
        return self._socketDescriptor.lockingForWithValue { ptr in
            return ptr.pointee != LittleWebServerSocketConnection.SOCKET_INVALID_DESCRIPTOR
        }
    }
    /// Indicator if the current socket is listening (is a server socket)
    open var isListener: Bool { return false }
    /// Indicator if the current socket is a client socket
    open var isClient: Bool { return false }
    /// The socket address information
    open var address: Address {
        let addr = Address.init(addressProvider: { (sockaddr, length) in
            getsockname(self.socketDescriptor, sockaddr, length)
        })
        
        guard let a = addr else {
            fatalError("Failed to retrieve socket address information")
        }
        
        return a
    }
    
    /// The socket address family
    public var family: AddressFamily {
        return self.address.family
    }
    /// The socket address protocol
    public var proto: AddressProtocol {
        return self.address.proto
    }
    
    /// Create a new Connection
    ///
    /// This init will enable SO_NOSIGPIPE on the socket
    /// - Parameter socketDescriptor: The socket descriptor
    internal init(_ socketDescriptor: SocketDescriptor) throws {
        self._socketDescriptor = .init(value: socketDescriptor)
        super.init()
        do {
            try LittleWebServerSocketConnection.setupNoSigPip(socketDescriptor)
        } catch {
            self.close()
            throw error
        }
    }
    
    /// Create a new socket with the given inforamtion
    /// - Parameters:
    ///   - family: The socket family (eg unix, inet4, inet6)
    ///   - proto: The socket protocol (eg, tcp or unix)
    internal init(family: AddressFamily, proto: AddressProtocol) throws {
        let sd = try LittleWebServerSocketConnection.newStreamSocket(family: family,
                                                                     proto: proto)
        self._socketDescriptor = .init(value: sd)
        super.init()
        
        do {
            try LittleWebServerSocketConnection.setupNoSigPip(sd)
        } catch {
            self.close()
            throw error
        }
    }
    
    /// Create a new socket with the given address information
    /// - Parameter address: The address information used to create the socket
    internal init(address: Address) throws {
        let sd = try LittleWebServerSocketConnection.newStreamSocket(family: address.family,
                                                                     proto: address.proto)
        self._socketDescriptor = .init(value: sd)
        super.init()
        do {
            try LittleWebServerSocketConnection.setupNoSigPip(sd)
        } catch {
            self.close()
            throw error
        }
    }
    
    deinit {
        self.close()
    }
    
    
    /// Closes the socket
    open func close() {
        self._socketDescriptor.lockingForWithValue { ptr in
            guard ptr.pointee != LittleWebServerSocketConnection.SOCKET_INVALID_DESCRIPTOR else {
                return
            }
            LittleWebServerSocketConnection.closeSocket(ptr.pointee)
            ptr.pointee = LittleWebServerSocketConnection.SOCKET_INVALID_DESCRIPTOR
        }
    }
    
    
    /// Create a new socket with the given socket information
    /// - Parameters:
    ///   - family: The socket family (eg unix, inet4, inet6)
    ///   - proto: The socket protocol (eg, tcp or unix)
    /// - Returns: Returns the newly created socket connection
    public static func newStreamSocket(family: LittleWebServerSocketConnection.AddressFamily,
                                       proto: LittleWebServerSocketConnection.AddressProtocol) throws -> SocketDescriptor {
        var rtn: SocketDescriptor = LittleWebServerSocketConnection.SOCKET_INVALID_DESCRIPTOR
        #if os(Linux)
        rtn = Glibc.socket(family.rawValue, Int32(SOCK_STREAM.rawValue), proto.rawValue)
        #else
        rtn = Darwin.socket(family.rawValue, SOCK_STREAM, proto.rawValue)
        #endif
        if rtn == LittleWebServerSocketConnection.SOCKET_INVALID_DESCRIPTOR {
            throw SocketError.invalidSocketDescriptor(systemError: .current())
        }
        return rtn
    }
    
    /// Create a new socket with the given socket information
    /// - Parameters:
    ///   - family: The IP socket family (eg inet4, inet6)
    ///   - proto: The socket protocol (eg, tcp or unix)
    /// - Returns: Returns the newly created socket connection
    public static func newStreamSocket(family: LittleWebServerSocketConnection.Address.IP.Family) throws -> SocketDescriptor {
        return try self.newStreamSocket(family: family.addressFamily, proto: .tcp)
    }
    
    /// Close the given socket descriptor
    /// - Parameter socket: The socket descriptor to close
    public static func closeSocket(_ socket: SocketDescriptor) {
        #if os(Linux)
            _ = Glibc.close(socket)
        #else
            _ = Darwin.close(socket)
        #endif
    }
    
    /// Set socket options
    /// - Parameters:
    ///   - socketDescriptor: The socket descriptor to set the options on
    ///   - level: The option level to use (Default:SOL_SOCKET)
    ///   - option: The option to set
    ///   - value: The value to set
    ///   - valueSize: The size of the value object
    /// - Returns: Returns a return code indicating of the value was set or not
    public static func setSocketOpt<V>(_ socketDescriptor: SocketDescriptor,
                                       level: Int32 = SOL_SOCKET,
                                       option: Int32,
                                       value: inout V,
                                       valueSize: socklen_t = socklen_t(MemoryLayout<V>.size)) -> Int32 {
        return setsockopt(socketDescriptor,
                          level,
                          option,
                          &value,
                          valueSize)
    }
    
    /// Setup SO_NOSIGPIPE on the given socket
    /// - Parameter socketDescriptor: The socket descriptor to set the option on
    /// - Returns: Returns a return code indicating of the value was set or not
    @discardableResult
    public static func setupNoSigPip(_ socketDescriptor: SocketDescriptor) throws -> Int32 {
        var value: Int32 = 1
        #if !os(Linux)
        guard setSocketOpt(socketDescriptor, option: SO_NOSIGPIPE, value: &value) != -1 else {
            throw SocketError.socketSettingNoSigPipFailed(systemError: .current())
        }
        #endif
        return value
    }
}

public extension LittleWebServerSocketConnection.Address.TCPIPPort {
    /// The default port for a HTTP Protocol
    static var http: LittleWebServerSocketConnection.Address.TCPIPPort {
        return 80
    }
    /// The default port for a Web Socket Protocol
    static var ws: LittleWebServerSocketConnection.Address.TCPIPPort {
        return 80
    }
    /// The default port for a HTTPS Protocol
    static var https: LittleWebServerSocketConnection.Address.TCPIPPort {
        return 443
    }
    /// The default port for a Secure Web Socket Protocol
    static var wss: LittleWebServerSocketConnection.Address.TCPIPPort {
        return 443
    }
}

public func ==<Numeric>(lhs: LittleWebServerSocketConnection.Address.TCPIPPort,
                        rhs: Numeric) -> Bool where Numeric: FixedWidthInteger {
    return lhs.rawValue == rhs
}
public func !=<Numeric>(lhs: LittleWebServerSocketConnection.Address.TCPIPPort,
                        rhs: Numeric) -> Bool where Numeric: FixedWidthInteger {
    return !(lhs == rhs)
}
public func ==<Numeric>(lhs: Numeric,
                        rhs: LittleWebServerSocketConnection.Address.TCPIPPort) -> Bool where Numeric: FixedWidthInteger {
    return lhs == rhs.rawValue
}
public func !=<Numeric>(lhs: Numeric,
                        rhs: LittleWebServerSocketConnection.Address.TCPIPPort) -> Bool where Numeric: FixedWidthInteger {
    return !(lhs == rhs)
}
