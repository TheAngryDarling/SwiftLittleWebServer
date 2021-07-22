//
//  LittleWebServerClientSocket.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-17.
//

import Foundation
/// Representation of a client Socket Connection
open class LittleWebServerClientSocket: LittleWebServerSocketConnection,
                                        LittleWebServerClient,
                                        LittleWebServerSocketClient {
    
    private let _address: Address
    open override var address: Address { return self._address }
    
    open override var isClient: Bool { return true }

    /// The URL Scheme of the connection
    public let scheme: String
    
    open var uid: String { return "\(self.scheme)://\(self.address.description)" }
    
    /// Create new client socket connection
    /// - Parameters:
    ///   - socketDescriptor: The socket descriptor of the connection
    ///   - address: The address information of the connection
    ///   - scheme: The URL Scheme of the connection
    public init(_ socketDescriptor: SocketDescriptor,
                address: LittleWebServerSocketConnection.Address,
                scheme: String) throws {
        self._address = address
        self.scheme = scheme
        try super.init(socketDescriptor)
    }
    
    override open func close() {
        super.close()
    }
    
    private func checkIfShouldClose(after error: LittleWebServerSocketSystemError) {
        if error.errno == 2 || error.errno == 22 || error == .brokenPipe {
            self.close()
        }
    }
    
    /// Read data from the connection
    /// - Parameters:
    ///   - buffer: The buffer to read data into
    ///   - count: The max number of bytes to read
    /// - Returns: The number of bytes actually read
    open func readBuffer(into buffer: UnsafeMutablePointer<UInt8>, count: Int) throws -> UInt {
        var readCount: Int
        #if os(Linux)
        readCount = Glibc.recv(self.socketDescriptor as Int32, buffer, count, Int32(MSG_NOSIGNAL))
        #else
        readCount = Darwin.recv(self.socketDescriptor as Int32, buffer, count, 0)
        #endif
        
        guard readCount >= 0 else {
            let err = LittleWebServerSocketSystemError.current()
            checkIfShouldClose(after: err)
            throw LittleWebServerClientError.readError(err)
        }
        // If read returned 0, means stream just finished
        if readCount == 0 {
            self.close()
        }
        
        return UInt(readCount)
    }
    
    /// Write data to the given connection
    /// - Parameters:
    ///   - pointer: The buffer of data to write
    ///   - length: The number of bytes within the buffer to write
    open func writeBuffer(_ pointer: UnsafeRawPointer, length: Int) throws {
        var sent = 0
        while sent < length && self.isConnected {
            #if os(Linux)
            let s = Glibc.send(self.socketDescriptor, pointer + sent, Int(length - sent), Int32(MSG_NOSIGNAL))
            #else
            let s = Darwin.write(self.socketDescriptor, pointer + sent, Int(length - sent))
            #endif
            if s <= 0 {
                let err = LittleWebServerSocketSystemError.current()
                //checkIfShouldClose(after: err)
                self.close()
                throw LittleWebServerClientError.readError(err)
            }
            sent += s
        }
    }
}

/// A TCP/IP Client Connection
open class LittleWebServerTCPIPClient: LittleWebServerClientSocket, LittleWebServerTCPIPSocketClient { }
/// A Unix File Client Connection
open class LittleWebServerUnixFileClient: LittleWebServerClientSocket, LittleWebServerUnixFileSocketClient { }
