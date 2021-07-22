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

/// Representation of any client connection wether it be Unix File Socket, TCP/IP Socket, or
/// any other custom connection
public protocol LittleWebServerClient: LittleWebServerConnection,
                                       LittleWebServerClientReader,
                                       LittleWebServerClientWriter {}

/// Represents an client connection that uses sockets
public protocol LittleWebServerSocketClient: LittleWebServerClient {
    /// The socket address for the client connection
    var address: LittleWebServerSocketConnection.Address { get }
}
/// Represents an client connection that uses TCP/IP Sockets
public protocol LittleWebServerTCPIPSocketClient: LittleWebServerClient {
    /// The TCP/IP Address of the client connection
    var ipAddress: LittleWebServerSocketConnection.Address.IP { get }
    /// The TCP/IP Port assigned to the client connection
    var port: LittleWebServerSocketConnection.Address.TCPIPPort { get }
}

public extension LittleWebServerTCPIPSocketClient where Self: LittleWebServerSocketClient {
    var ipAddress: LittleWebServerSocketConnection.Address.IP { return self.address.ipAddress! }
    var port: LittleWebServerSocketConnection.Address.TCPIPPort { return self.address.tcpPort! }
}

/// Represents an client connection that uses Unix File Sockets
public protocol LittleWebServerUnixFileSocketClient: LittleWebServerClient {
    /// The path the the Unix Socket File
    var path: String { get }
}
public extension LittleWebServerUnixFileSocketClient where Self: LittleWebServerSocketClient {
    var path: String { return self.address.unixPath! }
}


enum LittleWebServerClientHTTPReadError: Swift.Error {
    case invalidRead(expectedBufferSize: Int, actualBufferSize: Int)
    case unableToCreateString(from: Data)
    case invalidRequestHead(String)
}

internal extension LittleWebServerClient {
    /// Reads one HTTP line from the connection.
    /// This means that it will keep reading 1 byte at
    /// a time until it reaches the buffer has a suffix of \r\n
    func readHTTPLine() throws -> String {
        return try autoreleasepool {
            var httpLineData = Data()
            var readByte: UInt8 = 0
            repeat {
                
                guard (try self.readByte(into: &readByte)) else {
                    throw LittleWebServerClientHTTPReadError.invalidRead(expectedBufferSize: 1, actualBufferSize: 0)
                }
                //print(readByte)
                httpLineData.append(readByte)
                
            } while !httpLineData.hasSuffix(LittleWebServer.CRLF_DATA) && self.isConnected
            
            // Remove CR+LF from end of bytes
            httpLineData.removeLast(2)
            
            // Try creating string
            guard let rtn = /*String(data: httpLineData, encoding: .unicode) ??*/ String(data: httpLineData, encoding: .utf8) else {
                throw LittleWebServerClientHTTPReadError.unableToCreateString(from: httpLineData)
            }
            
            return rtn
        }
    }
    /// Reads the first line of the HTTP request.
    /// This includes the method, context path and the HTTP version used
    func readRequestHead() throws -> LittleWebServer.HTTP.Request.Head {
        let httpHeadLine = try self.readHTTPLine()
        //print("Request Head '\(httpHeadLine)'")
        guard let rtn = LittleWebServer.HTTP.Request.Head.parse(httpHeadLine) else {
            throw LittleWebServerClientHTTPReadError.invalidRequestHead(httpHeadLine)
        }
        return rtn
    }
    /// Reads the HTTP Headers that come after the HTTP head
    /// Each HTTP Line it reads should be {Header Name}: {Header Value}\r\n
    /// A trailing \r\n is expected to indicate that the headers are finished
    func readRequestHeaders() throws -> LittleWebServer.HTTP.Request.Headers {
        var rtn = LittleWebServer.HTTP.Request.Headers()
        
        // Read the first header or empty string meaning no headers
        var workingLine: String = try self.readHTTPLine()
        while !workingLine.isEmpty {
            
            if let r = workingLine.range(of: ": ") {
                let key = String(workingLine[..<r.lowerBound])
                let val = String(workingLine[r.upperBound...])
                rtn[.init(properString: key)] = val
            } else {
                rtn[.init(properString: workingLine)] = ""
            }
            
            workingLine = try self.readHTTPLine()
            
        }
        
        return rtn
    }
}


