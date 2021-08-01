//
//  LittleWebServerTCPIPListener.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-17.
//

import Foundation

/// A TCP/IP Listener
public class LittleWebServerTCPIPListener: LittleWebServerSocketListener {
    
    /// A selectable IP Address.  This could be the first available or a specific ip address
    public enum IPAddress: ExpressibleByNilLiteral,
                           LittleWebServerExpressibleByStringInterpolation,
                           Equatable {
        public enum AnyAvailable: Equatable {
            /// The first available IPv4 or IPv6 address
            case any
            /// The first IPv4 address
            case ipV4
            /// THe first IPv6 address
            case ipV6
            
            public static func ==(lhs: AnyAvailable, rhs: AnyAvailable) -> Bool {
                switch (lhs, rhs) {
                    case (.any, .any): return true
                    case (.ipV4, .ipV4): return true
                    case (.ipV6, .ipV6): return true
                    default: return false
                }
            }
            
        }
        
        case anyAvailable(AnyAvailable)
        case specific(LittleWebServerSocketConnection.Address.IP)
        
        /// The first available address
        public static var firstAvailable: IPAddress {
            return .anyAvailable(.any)
        }
        
        /// Representation of an IPv4 address of 0.0.0.0
        public static var anyIPv4: IPAddress {
            return .specific(.anyIPv4)
        }
        /// Representation of an IPv4 Loopback address (127.0.0.1)
        public static var ipV4Loopback: IPAddress {
            return .specific(.ipV4Loopback)
        }
        // Representation of an IPv6 address of ::
        public static var anyIPv6: IPAddress {
            return .specific(.anyIPv6)
        }
        /// Representation of an IPv6 Loopback address (::1)
        public static var ipV6Loopback: IPAddress {
            return .specific(.ipV6Loopback)
        }
        
        public init(nilLiteral: ()) {
            self = .anyAvailable(.any)
        }
        
        public init(stringLiteral value: String) {
            self = .specific(LittleWebServerSocketConnection.Address.IP(stringLiteral: value))
        }
        
        public static func ==(lhs: IPAddress, rhs: IPAddress) -> Bool {
            switch (lhs, rhs) {
                case (.anyAvailable(let lhsV), .anyAvailable(let rhsV)):
                    return lhsV == rhsV
                case (.specific(let lhsV), .specific(let rhsV)):
                    return lhsV == rhsV
                default: return false
            }
        }
    }
    private var _address: Address
    
    public override var address: LittleWebServerSocketConnection.Address { return self._address }
    /// The IP Address used to listen
    public var ipAddress: Address.IP { return self.address.ipAddress! }
    /// The port being listened on
    public var port: Address.TCPIPPort { return self.address.tcpPort! }
    //public private(set) var port: Address.TCPIPPort
    
    /// The string representation of the IP Address
    public var host: String {
        return self.ipAddress.node
    }
    
    /// The URL to access this listener
    /// Note: While scheme unix is not official not supported by default when using URLSession,
    /// this is what will show up when accessing a unix file socket
    public var url: URL {
        var urlString = "\(self.scheme)://\(self.host)"
        let defaultSchemePort = LittleWebServerDefaultSchemePort.default(for: self.scheme)
        if defaultSchemePort == nil || defaultSchemePort!.port != self.port {
            urlString += ":\(self.port)"
        }
        return URL(string: urlString)!
    }
    
    public override var uid: String {
        return self.url.absoluteString
    }
    
    /// Create new TCP/IP Listener
    /// - Parameters:
    ///   - ipAddress: The ip address to listen on or first available address. (Default: first available)
    ///   - port: The port to listen on or the first available port. (Default: any)
    ///   - reuseAddr: Indicator if
    ///   - scheme: The URL Scheme used for this connection if available
    ///   - maxBacklogSize: The maximun number of connection that can be waiting to be accpeted
    ///   - enablePortSharing: Indicator if port sharing should occur on inet6 sockets
    public init(_ ipAddress: IPAddress = .firstAvailable,
                port: Address.TCPIPPort = .firstAvailable,
                reuseAddr: Bool = true,
                scheme: String? = nil,
                maxBacklogSize: Int32 = LittleWebServerSocketListener.DEFAULT_MAX_BACK_LOG_SIZE,
                enablePortSharing: Bool = true) throws {
        
        let scheme: String = scheme ?? LittleWebServerDefaultSchemePort.default(for: port)?.scheme ?? ""
        
        var socketfd: SocketDescriptor = LittleWebServerSocketConnection.SOCKET_INVALID_DESCRIPTOR
        var actualIP: LittleWebServerSocketConnection.Address.IP? = nil
        var actualPort: Address.TCPIPPort = port
        
        switch ipAddress {
            case .specific(let workingIP):
                socketfd = try LittleWebServerSocketConnection.newStreamSocket(family: workingIP.family)
                
                do {
                    try LittleWebServerTCPIPListener.bind(socketfd,
                                                          ip: workingIP,
                                                          on: actualPort)
                } catch {
                    LittleWebServerSocketConnection.closeSocket(socketfd)
                    socketfd = LittleWebServerSocketConnection.SOCKET_INVALID_DESCRIPTOR
                   
                    throw SocketError.socketBindFailed(error)
                }
                
                actualIP = workingIP
            case .anyAvailable(let anyAvailable):
                let targetInfos:  [(family: Address.IP.Family, targets: UnsafeMutablePointer<addrinfo>)]
                var families: Address.IP.Families = []
                if anyAvailable == .any || anyAvailable == .ipV6 {
                    families.insert(.inet6)
                }
                if anyAvailable == .any || anyAvailable == .ipV4 {
                    families.insert(.inet4)
                }
                
                targetInfos = try LittleWebServerTCPIPListener.getTargetInfoOptions(families: families,
                                                                                    node: nil,
                                                                                    port: port)
                
                defer {
                    for item in targetInfos {
                        freeaddrinfo(item.targets)
                    }
                }
                
                for ti in targetInfos where actualIP == nil {
                    
                    if socketfd != LittleWebServerSocketConnection.SOCKET_INVALID_DESCRIPTOR {
                        LittleWebServerSocketConnection.closeSocket(socketfd)
                        socketfd = LittleWebServerSocketConnection.SOCKET_INVALID_DESCRIPTOR
                    }
                    socketfd = try LittleWebServerSocketConnection.newStreamSocket(family: ti.family)
                    
                    
                    var info: UnsafeMutablePointer<addrinfo>? = ti.targets
                    
                    while info != nil {

                        do {
                            try LittleWebServerTCPIPListener.bind(socketfd,
                                                                  address: info!.pointee.ai_addr,
                                                                  addressLength: info!.pointee.ai_addrlen)
                            actualIP = LittleWebServerSocketConnection.Address.IP(addressInfo: info!.pointee)
                            break
                        } catch {
                            // Try the next one...
                            info = info?.pointee.ai_next
                        }
                    }
                }
        }
        
        if actualIP == nil {
            
            LittleWebServerSocketConnection.closeSocket(socketfd)
            
            throw SocketError.socketBindFailureNoAvailableOptions

        }
        
        if port == 0 {
            let addr = try Address(addressProvider: { (sockaddr, length) in
                if getsockname(socketfd, sockaddr, length) != 0 {
                    LittleWebServerSocketConnection.closeSocket(socketfd)
                    throw SocketError.unableToRetriveSocketName(systemError: .current())
                    
                }
            })
            
            actualPort = addr!.tcpPort!
        }
        
        guard let realIP = actualIP else {
            LittleWebServerSocketConnection.closeSocket(socketfd)
            throw SocketError.unableToFindValidHostIP
            
        }
        
    
        //self.address = realIP
        //self.port = actualPort
        
        self._address = Address.ip(realIP, port: actualPort)
        
        //try super.init(socketfd, family: realIP.family, proto: .tcp, scheme: scheme)
        try super.init(socketfd,
                       address: self._address,
                       scheme: scheme,
                       maxBacklogSize: maxBacklogSize,
                       enablePortSharing: enablePortSharing)
        
        
    }
    
    open override func accept() throws -> LittleWebServerClient {
        
        let connectionDetails = try self.acceptSocket()
        return try LittleWebServerTCPIPClient(connectionDetails.socket,
                                              address: connectionDetails.address,
                                              scheme: self.scheme)
    }
    
    /// Bind the specific socket/address
    /// - Parameters:
    ///   - socket: The socket descriptor to bind
    ///   - address: The address to bind with
    ///   - addressLength: The size of th address
    /// - Returns: Returns a results
    private static func bind(_ socket: SocketDescriptor,
                             address: UnsafePointer<sockaddr>,
                             addressLength: socklen_t) throws {
        #if os(Linux)
        if Glibc.bind(socket, address, addressLength) != 0 {
            throw LittleWebServerSocketSystemError.current()
        }
        #else
        if Darwin.bind(socket, address, addressLength) != 0 {
            throw LittleWebServerSocketSystemError.current()
        }
        #endif
    }
    
    /// Bind the specific socket/address
    /// - Parameters:
    ///   - socket: The socket descriptor to bind
    ///   - info: The address to bind with
    private static func bind(_ socket: SocketDescriptor,
                             info: addrinfo) throws {
        try self.bind(socket,
                      address: info.ai_addr,
                      addressLength: info.ai_addrlen)
    }
    
    /// Bind the specific socket/address
    /// - Parameters:
    ///   - socket: The socket descriptor to bind
    ///   - address: The address to bind with
    private static func bind(_ socket: SocketDescriptor,
                             using address: LittleWebServerSocketConnection.Address) throws {
        try address.withUnsafeSocketAddrPointer {
            try self.bind(socket, address: $0, addressLength: socklen_t($1))
        }
    }
    
    /// Bind the specific socket/address
    /// - Parameters:
    ///   - socket: The socket descriptor to bind
    ///   - ip: The IP Address to bind to
    ///   - port: The port to bind to
    private static func bind(_ socket: SocketDescriptor,
                             ip: LittleWebServerSocketConnection.Address.IP,
                             on port: LittleWebServerSocketConnection.Address.TCPIPPort) throws {
        
        let address = LittleWebServerSocketConnection.Address.ip(ip, port: port)
        return try self.bind(socket, using: address)
        
    }
    
    /// Get a list of available addresses for the given family, node (ip address if provided) and port
    /// - Parameters:
    ///   - families: The address family (
    ///   - node: The IP address to test if available
    ///   - port: The port to test if available
    /// - Returns: Returns an array of available TCP/IP Family and Addresses that could be used
    private static func getTargetInfoOptions(families: Address.IP.Families,
                                             node: String? = nil,
                                             port: Address.TCPIPPort) throws -> [(family: Address.IP.Family, targets: UnsafeMutablePointer<addrinfo>)] {
        var rtn: [(family: Address.IP.Family, targets: UnsafeMutablePointer<addrinfo>)] = []
        for family in families {
            #if os(Linux)
            var hints = addrinfo(
                ai_flags: AI_PASSIVE,
                ai_family: family.rawValue,
                ai_socktype: Int32(SOCK_STREAM.rawValue),
                ai_protocol: 0,
                ai_addrlen: 0,
                ai_addr: nil,
                ai_canonname: nil,
                ai_next: nil)
            #else
            var hints = addrinfo(
                ai_flags: AI_PASSIVE,
                ai_family: family.rawValue,
                ai_socktype: SOCK_STREAM,
                ai_protocol: 0,
                ai_addrlen: 0,
                ai_canonname: nil,
                ai_addr: nil,
                ai_next: nil)
            #endif
            
            var targetInfo: UnsafeMutablePointer<addrinfo>? = nil
            
            // Retrieve the info on our target...
            let status: Int32 = getaddrinfo(node ?? nil, "\(port)", &hints, &targetInfo)
            if status != 0 {

                // On error we will cleanup
                for item in rtn {
                    freeaddrinfo(item.targets)
                }
                throw SocketError.Address.ip(.adderinfo(.init(rawValue: status )))
            }
            
            rtn.append((family: family, targets: targetInfo!))
        }
        
        return rtn
        
    }
}

public class LittleWebServerHTTPListener: LittleWebServerTCPIPListener {
    /// Create a new TCP/IP Connection with the http scheme
    /// - Parameters:
    ///   - ipAddress: The ip address to listen on or first available address. (Default: first available)
    ///   - port: The port to listen on
    ///   - reuseAddr: Indicator if
    ///   - maxBacklogSize: The maximun number of connection that can be waiting to be accpeted
    ///   - enablePortSharing: Indicator if port sharing should occur on inet6 sockets
    public init(_ ipAddress: IPAddress = .firstAvailable,
                port: Address.TCPIPPort,
                reuseAddr: Bool = true,
                maxBacklogSize: Int32 = LittleWebServerSocketListener.DEFAULT_MAX_BACK_LOG_SIZE,
                enablePortSharing: Bool = true) throws {
        try super.init(ipAddress,
                       port: port,
                       reuseAddr: reuseAddr,
                       scheme: "http",
                       maxBacklogSize: maxBacklogSize,
                       enablePortSharing: enablePortSharing)
    }
    
    /// Create a new TCP/IP Connection with the http scheme
    /// - Parameters:
    ///   - ip: The specific IP Address to listen on
    ///   - port: The port to listen on
    ///   - reuseAddr: Indicator if
    ///   - maxBacklogSize: The maximun number of connection that can be waiting to be accpeted
    ///   - enablePortSharing: Indicator if port sharing should occur on inet6 sockets
    public convenience init(specificIP ip: LittleWebServerSocketConnection.Address.IP,
                            port: LittleWebServerSocketConnection.Address.TCPIPPort,
                            reuseAddr: Bool = true,
                            maxBacklogSize: Int32 = LittleWebServerSocketListener.DEFAULT_MAX_BACK_LOG_SIZE,
                            enablePortSharing: Bool = true) throws {
        try self.init(.specific(ip),
                      port: port,
                      reuseAddr: reuseAddr,
                      maxBacklogSize: maxBacklogSize,
                      enablePortSharing: enablePortSharing)
    }
}
