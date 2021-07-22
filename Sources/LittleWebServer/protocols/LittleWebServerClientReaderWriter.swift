//
//  LittleWebServerClientReaderWriter.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-17.
//

import Foundation

/// Represetns an objects for reading data
public protocol LittleWebServerClientReader {
    /// Read data from the client
    /// - Parameters:
    ///   - buffer: The buffer to read data into
    ///   - count: The max number of bytes to read
    /// - Returns: The number of bytes actually read
    func readBuffer(into buffer: UnsafeMutablePointer<UInt8>, count: Int) throws -> UInt
}

/// Represents an objects for writning data
public protocol LittleWebServerClientWriter {
    /// Write data to the client
    /// - Parameters:
    ///   - pointer: The buffer of data to write
    ///   - length: The number of bytes within the buffer to write
    func writeBuffer(_ pointer: UnsafeRawPointer, length: Int) throws
}
internal extension LittleWebServerClientWriter {
    /// Write data to the client
    /// - Parameters:
    ///   - pointer: The buffer of data to write
    ///   - length: The number of bytes within the buffer to write
    func writeBuffer(_ pointer: UnsafeMutablePointerContainer<UInt8>,
                     length: Int) throws {
        try self.writeBuffer(pointer.buffer, length: length)
    }
}


public extension LittleWebServerClientReader {
    
    /// A byte representation of a character return (\r)
    private var CR: UInt8 { return 13 }
    /// A byte representatio of a line feed (\n)
    private var LF: UInt8 { return 10 }
    
    
    /// Reads bytes into the buffer.
    /// This reads upto the size of the buffer
    /// - Parameter buffer: The buffer to read into
    /// - Returns: The number of bytes read
    func read(into buffer: inout [UInt8]) throws -> UInt {
        return try self.readBuffer(into: &buffer, count: buffer.count)
    }
    
    /// Read one byte into the buffer
    /// - Parameter byte: The buffer to read into
    /// - Returns: Indicator if the byte was read
    @discardableResult
    func readByte(into byte: inout UInt8) throws -> Bool {
        return (try self.readBuffer(into: &byte, count: 1) == 1)
    }
    
    /// Read a single byte
    func readByte() throws -> UInt8 {
        var buffer = [UInt8](repeating: 0, count: 1)
        guard (try self.read(into: &buffer)) > 0 else {
            throw LittleWebServerClientError.noBytesReturned
        }
        return buffer[0]
    }
    
    /// Reads exactly the number of bytes requested or until a failure or end of stream
    /// - Parameters:
    ///   - buffer: The buffer to read into
    ///   - exactly: The number of bytes to read
    func read(_ buffer: UnsafeMutablePointer<UInt8>, exactly: Int) throws {
        
        var currentlyRead: Int = 0
        while currentlyRead < exactly {
            //let ret = try self.readBuffer(into: &buffer, count: (size - rtn.count))
            let ret = try self.readBuffer(into: buffer + currentlyRead, count: exactly - currentlyRead)
            if ret == 0 {
                throw LittleWebServerClientError.endOfStreamReached
            }
            currentlyRead += Int(ret)
            
        }
    }
    
    /// Reads exactly the number of bytes requested or until a failure or end of stream
    /// - Parameter size: The number of bytes to read
    /// - Returns: The data structure containing the bytes read
    func read(exactly size: Int) throws -> Data {
        var rtn = Data()
        var buffer = [UInt8](repeating: 0, count: 12)
        while rtn.count < size {
            var readSize = buffer.count
            if readSize > (size - rtn.count) { readSize = (size - rtn.count) }
            let ret = try self.readBuffer(into: &buffer, count: readSize)
            if ret == 0 {
                break
            }
            rtn.append(&buffer, count: Int(ret))
        }
        return rtn
    }
    
    /// Read UTF8 line where ending was \r\n
    func readUTF8Line() throws -> String {
        var characters: String = ""
        var bytes = [UInt8](repeating: 0, count: 2)
        repeat {
            bytes[0] = bytes[1]
            bytes[1] = try self.readByte()
            if bytes[1] > self.CR { characters.append(Character(UnicodeScalar(bytes[1]))) }
        } while bytes != [self.CR, self.LF]
        return characters
    }
}

public extension LittleWebServerClientWriter {
    
    /// Writes bytes to the client
    /// - Parameter bytes: The bytes to write
    func write(_ bytes: [UInt8]) throws {
        try bytes.withUnsafeBytes {
            try self.writeBuffer($0.baseAddress!, length: $0.count)
        }
    }
    
    /// Write data to the client
    /// - Parameter data: The data to write
    func write( _ data: Data) throws {
        #if !swift(>=5.0)
        try data.withUnsafeBytes { ( buffer: UnsafePointer<UInt8>) throws -> Void in
            try self.writeBuffer(UnsafeRawPointer(buffer), length: data.count)
        }
        #else
        try data.withUnsafeBytes {
           try self.writeBuffer($0.baseAddress!, length: $0.count)
        }
        #endif
        
        
    }
    
    /// Write a UTF8 String to the client
    /// - Parameter string: The string to write
    func writeUTF8(_ string: String) throws {
        try write(Array(string.utf8))
    }
    
    /// Writes a UTF8 line
    /// - Parameters:
    ///   - string: The string to write
    ///   - addLineSuffix: Indicator if should add line suffix
    ///   - lineSuffix: The suffix to append if addLineSuffix is true.  (Default: \r\n)
    func writeUTF8Line(_ string: String,
                       addLineSuffix: Bool = true,
                       lineSuffix: String = "\r\n") throws {
        var line = string
        if addLineSuffix { line += lineSuffix }
        try self.writeUTF8(line)
    }
}
