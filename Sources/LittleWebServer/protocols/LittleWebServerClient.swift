//
//  WebServerClient.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-17.
//

import Foundation

public enum LittleWebServerClientError: Swift.Error {
    case readError(LittleWebServerSocketSystemError)
    case writeError(LittleWebServerSocketSystemError)
    case fileTransferFileNotFound(path: String)
    case fileTransferUnableToGetFileSize(path: String)
    case fileTransferUnableToOpenFile(path: String)
    case fileTransferReadError(Swift.Error)
    case chunkInvalidSize(String)
    case chunkInvalidEndCharacter(expecting: UInt8, found: UInt8)
    case invalidReadError(code: Int, LittleWebServerSocketSystemError)
    case noBytesReturned
    case endOfStreamReached
}

/// Client Connection Details
public protocol LittleWebServerClientDetails {
    /// The unique ID of  the given connection
    var uid: String { get }
    /// A Unique Identifier for the Client.
    var uuid: UUID { get }
    /// The scheme/protocol used for communication between the server and the client like http, https, unix, or your own unique scheme
    var scheme: String { get }
}
/// Representation of any client connection wether it be Unix File Socket, TCP/IP Socket, or
/// any other custom connection
public protocol LittleWebServerClient: LittleWebServerConnection,
                                       LittleWebServerClientReader,
                                       LittleWebServerClientWriter {
    
    /// The connection details for this connection.  These details weill be used when signaling server events
    var connectionDetails: LittleWebServerClientDetails { get }
    
    /// The unique ID of  the given connection
    var uid: String { get }
    /// A Unique Identifier for the Client.
    var uuid: UUID { get }
    /// The scheme/protocol used for communication between the server and the client like http, https, unix, or your own unique scheme
    var scheme: String { get }
    
}

public extension LittleWebServerClient {
    var uid: String { return self.connectionDetails.uid }
    var uuid: UUID { return self.connectionDetails.uuid }
    var scheme: String { return self.connectionDetails.scheme }
}

/// Socket Client Connection Details
public protocol LittleWebServerSocketClientDetails: LittleWebServerClientDetails {
    /// The socket address for the client connection
    var address: LittleWebServerSocketConnection.Address { get }
}

/// Represents an client connection that uses sockets
public protocol LittleWebServerSocketClient: LittleWebServerClient {
    /// The socket address for the client connection
    var address: LittleWebServerSocketConnection.Address { get }
    
    /// The connection details for this connection.  These details weill be used when signaling server events
    var socketConnectionDetails: LittleWebServerSocketClientDetails { get }
    
}

public extension LittleWebServerSocketClient {
    var connectionDetails: LittleWebServerClientDetails {
        return self.socketConnectionDetails
    }
    var address: LittleWebServerSocketConnection.Address {
        return self.socketConnectionDetails.address
    }
}
/// TCP/IP Socket Client Connection Details
public protocol LittleWebServerTCPIPSocketClientDetails: LittleWebServerSocketClientDetails {
    /// The TCP/IP Address of the client connection
    var ipAddress: LittleWebServerSocketConnection.Address.IP { get }
    /// The TCP/IP Port assigned to the client connection
    var port: LittleWebServerSocketConnection.Address.TCPIPPort { get }
}
public extension LittleWebServerTCPIPSocketClientDetails {
    var ipAddress: LittleWebServerSocketConnection.Address.IP {
        return self.address.ipAddress!
    }
    var port: LittleWebServerSocketConnection.Address.TCPIPPort {
        return self.address.tcpPort!
    }
}

/// Represents an client connection that uses TCP/IP Sockets
public protocol LittleWebServerTCPIPSocketClient: LittleWebServerSocketClient {
    /// The TCP/IP Address of the client connection
    var ipAddress: LittleWebServerSocketConnection.Address.IP { get }
    /// The TCP/IP Port assigned to the client connection
    var port: LittleWebServerSocketConnection.Address.TCPIPPort { get }
    
    /// The connection details for this connection.  These details weill be used when signaling server events
    var tcpIPSocketConnectionDetails: LittleWebServerTCPIPSocketClientDetails { get }
}

public extension LittleWebServerTCPIPSocketClient {
    var ipAddress: LittleWebServerSocketConnection.Address.IP {
        return self.tcpIPSocketConnectionDetails.ipAddress
    }
    var port: LittleWebServerSocketConnection.Address.TCPIPPort {
        return self.tcpIPSocketConnectionDetails.port
    }
    var socketConnectionDetails: LittleWebServerSocketClientDetails {
        return self.tcpIPSocketConnectionDetails
    }
}

/// TCP/IP Socket Client Connection Details
public protocol LittleWebServerUnixFileSocketClientDetails: LittleWebServerSocketClientDetails {
    /// The path the the Unix Socket File
    var path: String { get }
}
public extension LittleWebServerUnixFileSocketClientDetails {
    var path: String { return self.address.unixPath! }
    
    
}


/// Represents an client connection that uses Unix File Sockets
public protocol LittleWebServerUnixFileSocketClient: LittleWebServerSocketClient {
    /// The path the the Unix Socket File
    var path: String { get }
    
    /// The connection details for this connection.  These details weill be used when signaling server events
    var unixFileSocketConnectionDetails: LittleWebServerUnixFileSocketClientDetails { get }
}
public extension LittleWebServerUnixFileSocketClient {
    var path: String { return self.address.unixPath! }
    var socketConnectionDetails: LittleWebServerSocketClientDetails {
        return self.unixFileSocketConnectionDetails
    }
    
}


enum LittleWebServerClientHTTPReadError: Swift.Error {
    case invalidRead(expectedBufferSize: Int, actualBufferSize: Int)
    case unableToCreateString(from: Data)
    case invalidRequestHead(String)
}


