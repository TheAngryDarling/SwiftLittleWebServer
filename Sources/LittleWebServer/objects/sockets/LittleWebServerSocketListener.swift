//
//  SocketListener.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-17.
//

import Foundation
import Dispatch


/// A base for any Socket listener
open class LittleWebServerSocketListener: LittleWebServerSocketConnection,
                                          LittleWebServerListener {
    
    /// The default maximum socket listener back log size
    public static let DEFAULT_MAX_BACK_LOG_SIZE: Int32 = 0
    
    
    private let isListenerLock = NSLock()
    private var _isListening: Bool = false
    open var isListening: Bool {
        self.isListenerLock.lock()
        defer { self.isListenerLock.unlock() }
        return self._isListening
    }
    
    open var uid: String { fatalError("Must be implemented in child class") }
    
    /// The maximum socket listener back log size
    private let maxBacklogSize: Int32
    
    open override var isListener: Bool { return true }
    
    public let scheme: String
    
    /// Create a new socket listener
    /// - Parameters:
    ///   - socketDescriptor: The socket descriptor to use to listen on
    ///   - family: The socket family this socket descriptor belongs to (eg inet4, inet6, unix)
    ///   - proto: The socket protocol this socket descriptor uses (eg tcp, unix)
    ///   - scheme: The scheme for this connection (eg http, https, unix).  This can be anything you want it just fills the scheme of the url property
    ///   - maxBacklogSize: The maximun number of connection that can be waiting to be accpeted
    ///   - enablePortSharing: Indicator if port sharing should occur on inet6 sockets
    public init(_ socketDescriptor: SocketDescriptor,
                family: AddressFamily,
                proto: AddressProtocol,
                scheme: String,
                maxBacklogSize: Int32 = LittleWebServerSocketListener.DEFAULT_MAX_BACK_LOG_SIZE,
                enablePortSharing: Bool = true) throws {
        if (family == .unix && proto != .unix)  {
            preconditionFailure("A family of \(family) must have a protocol of \(AddressProtocol.unix)")
        }
        if (family != .unix && proto == .unix) {
            preconditionFailure("A family of \(family) cannot have a protocol of \(AddressProtocol.unix)")
        }
        self.maxBacklogSize = maxBacklogSize
        self.scheme = scheme
        try super.init(socketDescriptor)
        if family == .inet6 && !enablePortSharing {
            do {
                try LittleWebServerSocketListener.disableIP6IP4PortSharing(self.socketDescriptor,
                                                                           family: family)
            } catch {
                self.close()
                throw error
            }
        }
    }
    
    /// Create a new socket listener
    /// - Parameters:
    ///   - socketDescriptor: The socket descriptor to use to listen on
    ///   - address: The socket address information
    ///   - scheme: The scheme for this connection (eg http, https, unix).  This can be anything you want it just fills the scheme of the url property
    ///   - maxBacklogSize: The maximun number of connection that can be waiting to be accpeted
    ///   - enablePortSharing: Indicator if port sharing should occur on inet6 sockets
    public init(_ socketDescriptor: SocketDescriptor,
                address: Address,
                scheme: String,
                maxBacklogSize: Int32 = LittleWebServerSocketListener.DEFAULT_MAX_BACK_LOG_SIZE,
                enablePortSharing: Bool = true) throws {
        if (address.family == .unix && address.proto != .unix)  {
            preconditionFailure("A family of \(address.family) must have a protocol of \(AddressProtocol.unix)")
        }
        if (address.family != .unix && address.proto == .unix) {
            preconditionFailure("A family of \(address.family) cannot have a protocol of \(AddressProtocol.unix)")
        }
        self.maxBacklogSize = maxBacklogSize
        self.scheme = scheme
        try super.init(socketDescriptor)
        if family == .inet6 && !enablePortSharing {
            do {
                try LittleWebServerSocketListener.disableIP6IP4PortSharing(self.socketDescriptor,
                                                                           family: family)
            } catch {
                self.close()
                throw error
            }
        }
    }
    
    
    /// Create a new socket listener
    /// - Parameters:
    ///   - family: The socket family this socket should use (eg inet4, inet6, unix)
    ///   - proto: The socket protocol this socket descriptor should use (eg tcp, unix)
    ///   - scheme: The scheme for this connection (eg http, https, unix).  This can be anything you want it just fills the scheme of the url property
    ///   - maxBacklogSize: The maximun number of connection that can be waiting to be accpeted
    ///   - enablePortSharing: Indicator if port sharing should occur on inet6 sockets
    public init(family: AddressFamily,
                proto: AddressProtocol,
                scheme: String,
                maxBacklogSize: Int32 = LittleWebServerSocketListener.DEFAULT_MAX_BACK_LOG_SIZE,
                enablePortSharing: Bool = true) throws {
        if (family == .unix && proto != .unix)  {
            preconditionFailure("A family of \(family) must have a protocol of \(AddressProtocol.unix)")
        }
        if (family != .unix && proto == .unix) {
            preconditionFailure("A family of \(family) cannot have a protocol of \(AddressProtocol.unix)")
        }
        
        self.maxBacklogSize = maxBacklogSize
        self.scheme = scheme
        try super.init(family: family, proto: proto)
        if family == .inet6 && !enablePortSharing {
            do {
                try LittleWebServerSocketListener.disableIP6IP4PortSharing(self.socketDescriptor,
                                                                           family: family)
            } catch {
                self.close()
                throw error
            }
        }
    }
    
    /// Create a new socket listener
    /// - Parameters:
    ///   - address: The socket address used to create the socket descriptor
    ///   - scheme: The scheme for this connection (eg http, https, unix).  This can be anything you want it just fills the scheme of the url property
    ///   - maxBacklogSize: The maximun number of connection that can be waiting to be accpeted
    ///   - enablePortSharing: Indicator if port sharing should occur on inet6 sockets
    public init(address: Address,
                scheme: String,
                maxBacklogSize: Int32 = LittleWebServerSocketListener.DEFAULT_MAX_BACK_LOG_SIZE,
                enablePortSharing: Bool = true) throws {
        if (address.family == .unix && address.proto != .unix)  {
            preconditionFailure("A family of \(address.family) must have a protocol of \(AddressProtocol.unix)")
        }
        if (address.family != .unix && address.proto == .unix) {
            preconditionFailure("A family of \(address.family) cannot have a protocol of \(AddressProtocol.unix)")
        }
        
        self.maxBacklogSize = maxBacklogSize
        self.scheme = scheme
        try super.init(family: address.family, proto: address.proto)
        if address.family == .inet6 && !enablePortSharing {
            do {
                try LittleWebServerSocketListener.disableIP6IP4PortSharing(self.socketDescriptor,
                                                                           family: address.family)
            } catch {
                self.close()
                throw error
            }
        }
    }
    
    override open func close() {
        self.stopListening()
        super.close()
    }
    
    open func startListening() throws {
        self.isListenerLock.lock()
        defer { self.isListenerLock.unlock() }
        
        guard !self._isListening else { return }
        
        #if os(Linux)
        let ret = Glibc.listen(self.socketDescriptor, self.maxBacklogSize)
        #else
        let ret = Darwin.listen(self.socketDescriptor, self.maxBacklogSize)
        #endif
        if ret < 0 {
            throw SocketError.socketListeningFailed(systemError: .current())
        }
        
        self._isListening = true
        
    }
    
    open func stopListening() {
        self.isListenerLock.lock()
        defer { self.isListenerLock.unlock() }
        
        guard self._isListening else { return }
        
        #if os(Linux)
            _ = Glibc.shutdown(self.socketDescriptor, Int32(SHUT_RDWR))
        #else
            _ = Darwin.shutdown(self.socketDescriptor, Int32(SHUT_RDWR))
        #endif
        self._isListening = false
        
        
    }
    
    /// Accept an incomming connection
    /// - Returns: The new client connection and address of the connection
    public func acceptSocket() throws -> (socket: SocketDescriptor, address: Address) {
        struct AcceptInterrupt: Swift.Error {
            public init() { }
        }
        
        guard self.socketDescriptor != LittleWebServerSocketConnection.SOCKET_INVALID_DESCRIPTOR else {
            throw SocketError.missingSocketDescriptor
        }
        
        guard self.isConnected else {
            throw SocketError.socketNotConnected
        }
        
        guard self.isListening else {
            throw SocketError.socketNotListening
        }
        
        
        var clientSocket: SocketDescriptor = LittleWebServerSocketConnection.SOCKET_INVALID_DESCRIPTOR
        var clientAddress: Address? = nil
        
        var keepTrying: Bool = true
        repeat {
            do {
                guard let acceptAddress = try Address.init(addressProvider: { (addressPointer, addressLengthPointer) in
                    #if os(Linux)
                        let fd = Glibc.accept(self.socketDescriptor, addressPointer, addressLengthPointer)
                    #else
                        let fd = Darwin.accept(self.socketDescriptor, addressPointer, addressLengthPointer)
                    #endif
                    
                    if fd < 0 {
                        
                        // The operation was interrupted, continue the loop...
                        if errno == EINTR {
                            throw AcceptInterrupt()
                        }
                        
                        throw SocketError.socketAcceptFailed(systemError: .current())
                    }
                    clientSocket = fd
                }) else {
                    
                    if clientSocket != LittleWebServerSocketConnection.SOCKET_INVALID_DESCRIPTOR {
                        LittleWebServerSocketConnection.closeSocket(clientSocket)
                    }
                    
                    throw SocketError.socketWrongClientSocketProtocol
                    
                }
                clientAddress = acceptAddress
                
            } catch is AcceptInterrupt {
                
                continue
            }

            keepTrying = false
        } while keepTrying && !Thread.current.isCancelled
        
        guard clientSocket != LittleWebServerSocketConnection.SOCKET_INVALID_DESCRIPTOR &&
              clientAddress != nil else {
            
            if clientSocket != LittleWebServerSocketConnection.SOCKET_INVALID_DESCRIPTOR {
                LittleWebServerSocketConnection.closeSocket(clientSocket)
            }
            
            throw SocketError.socketUnabletToLoadClientSocket
        }
        
        return (socket: clientSocket, address: clientAddress!)
    }
    
    open func accept() throws -> LittleWebServerClient {
        
        let connectionDetails = try self.acceptSocket()
        return try LittleWebServerClientSocket(connectionDetails.socket,
                                               address: connectionDetails.address,
                                               scheme: self.scheme)
    }
    /*
    open func reinitialize() throws -> Bool {
        fatalError("Must be implemented in child class")
    }
    */
    
    
    /// Sets th socket option of SO_REUSEADDR on the given socket descriptor
    /// - Parameter socketDescriptor: The socket descriptor to set the option to
    /// - Returns: Returns an indicator if the option was set
    @discardableResult
    public static func setupReuseAddr(_ socketDescriptor: SocketDescriptor) throws -> Int32 {
        var value: Int32 = 1
        guard setSocketOpt(socketDescriptor, option: SO_REUSEADDR, value: &value) != -1 else {
            throw SocketError.socketSettingReUseAddrFailed(systemError: .current())
        }
        return value
    }
    
    
    /// Sets the socket option to disable IPv6 to IPv4 port sharing
    /// - Parameter socketDescriptor: The socket descriptor to set the option to
    /// - Parameter family: The socket family this socket should use (eg inet4, inet6, unix)
    private static func disableIP6IP4PortSharing(_ socketDescriptor: SocketDescriptor,
                                                 family: AddressFamily) throws {
        guard family == .inet6 else { return }
        var on: Int32 = 1
        if LittleWebServerSocketConnection.setSocketOpt(socketDescriptor,
                                         level: Int32(IPPROTO_IPV6),
                                         option: IPV6_V6ONLY,
                                         value: &on) < 0 {
            throw SocketError.socketSettingIPv6IPv4PortSharingFailed(systemError: .current())
        }
    }
    
}
