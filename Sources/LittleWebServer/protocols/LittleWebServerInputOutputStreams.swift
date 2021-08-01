//
//  LittleWebServerInputOutputStreams.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-17.
//

import Foundation

/// Represents an input stream for reading data
public protocol LittleWebServerInputStream: LittleWebServerClientReader {
    /// Indicator if the stream is connected
    var isConnected: Bool { get }
    /// Indicator if there are bytes available
    var hasBytesAvailable: Bool { get }
    /// Allows to peak ahead of the reads without loosing the data for the read method
    func peekBuffer(into buffer: UnsafeMutablePointer<UInt8>, count: Int) throws -> UInt
    
}

/// Represents an output stream for writing data
public protocol LittleWebServerOutputStream: LittleWebServerClientWriter {
    /// Indicator if the stream is connected
    var isConnected: Bool { get }
    
    /// The maximum number of byte to buffer to read each time when transfering file data.  This can be overridden by the speed limiter
    var defaultFileTransferBufferSize: UInt { get }
    
    /// Write the contents of a file to the output stream
    /// - Parameters:
    ///   - atPath: Path to the file to write
    ///   - range: The byte range within the file to write.  If nil, will write the whole file
    ///   - speedLimit: The speed limiter to use when writing the file.  This controlls the speed (bytes/second) of the write
    func writeContentsOfFile(atPath: String,
                             range: LittleWebServer.HTTP.Response.Body.FileRange?,
                             speedLimit: LittleWebServer.FileTransferSpeedLimiter) throws
}
public extension LittleWebServerOutputStream {
    /// Write the contents of a file to the output stream
    /// - Parameters:
    ///   - atPath: Path to the file to write
    ///   - speedLimit: The speed limiter to use when writing the file.  This controlls the speed (bytes/second) of the write
    func writeContentsOfFile(atPath path: String,
                             speedLimit: LittleWebServer.FileTransferSpeedLimiter = .unlimited) throws {
        try self.writeContentsOfFile(atPath: path, range: nil, speedLimit: speedLimit)
    }
}

public extension LittleWebServerInputStream {
    /// Peeks bytes into buffer
    /// Returns the number of bytes read
    func peek(into buffer: inout [UInt8]) throws -> UInt {
        return try self.peekBuffer(into: &buffer, count: buffer.count)
    }
    
    /// Peeks a single byte into the buffer
    @discardableResult
    func peekByte(into buffer: inout UInt8) throws -> Bool {
        return (try self.peekBuffer(into: &buffer, count: 1) == 1)
    }
    
    /// Peeks a single byte
    func peekByte() throws -> UInt8 {
        var buffer = [UInt8](repeating: 0, count: 1)
        guard (try self.peek(into: &buffer)) > 0 else {
            throw LittleWebServerClientError.noBytesReturned
        }
        return buffer[0]
    }
    
    /// Peeks ahead the exact amout of data
    /// - Parameter size: The exact size to peek
    /// - Returns: Returns the peeked data
    func peek(exactly size: Int) throws -> Data {
        var rtn = Data()
        var buffer = [UInt8](repeating: 0, count: 12)
        while rtn.count < size {
            var readSize = buffer.count
            if readSize > (size - rtn.count) { readSize = (size - rtn.count) }
            //let ret = try self.readBuffer(into: &buffer, count: (size - rtn.count))
            let ret = try self.peekBuffer(into: &buffer, count: readSize)
            if ret == 0 {
                break
            }
            /*for i in 0..<ret {
                rtn.append(buffer[Int(i)])
            }*/
            rtn.append(&buffer, count: Int(ret))
        }
        return rtn
    }
}
