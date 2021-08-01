//
//  HTTPLittleWebServerOutputStreamV1_1.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-08-01.
//

import Foundation

internal class HTTPLittleWebServerOutputStreamV1_1: LittleWebServerOutputStream {
    
    
    public static let FileTransferBufferSize: UInt = 1024
    private let client: LittleWebServerClient
    /// Indicator if data should be sent in cunks
    public let chunked: Bool
    /// Indicator to keep track if the zero (end) chunk has been sent
    private var hasWrittenZeroChunk: Bool = false
    /// The maximum chunk size to use.  If not set then will use the total size being written
    private let maxChunkedSize: Int?
    /// The maximum number of byte to buffer to read each time when transfering file data.  This can be overridden by the speed limiter
    public let defaultFileTransferBufferSize: UInt
    
    public var isConnected: Bool { return self.client.isConnected }
    
    public init(client: LittleWebServerClient,
                chunked: Bool,
                maxChunkedSize: Int? = nil,
                fileTransferBufferSize: UInt = HTTPLittleWebServerOutputStreamV1_1.FileTransferBufferSize) {
        self.client = client
        self.chunked = chunked
        self.maxChunkedSize = maxChunkedSize
        self.defaultFileTransferBufferSize = fileTransferBufferSize
    }
    
    public convenience init(client: LittleWebServerClient,
                            transferEncodings: LittleWebServer.HTTP.Response.Headers.TransferEncodings?,
                            maxChunkedSize: Int? = nil,
                            fileTransferBufferSize: UInt = HTTPLittleWebServerOutputStreamV1_1.FileTransferBufferSize) {
        self.init(client: client,
                  chunked: (transferEncodings?.contains(.chunked) ?? false),
                  maxChunkedSize: maxChunkedSize,
                  fileTransferBufferSize: fileTransferBufferSize)
    }
    
    func writeBuffer(_ pointer: UnsafeRawPointer, length: Int) throws {
        // If not chunked, lets just pass along the raw data
        guard self.chunked else {
            try self.client.writeBuffer(pointer, length: length)
            return
        }
        
        guard length > 0 else {
            if !self.hasWrittenZeroChunk {
                try self.client.writeUTF8("0\r\n\r\n")
            }
            self.hasWrittenZeroChunk = true
            return
        }
        
        let mxChunkSize = self.maxChunkedSize ?? length
        var currentWritten: Int = 0
        while currentWritten < length {
            let chunkSize: Int
            if (length - currentWritten) < mxChunkSize {
                chunkSize = (length - currentWritten)
            } else {
                chunkSize = mxChunkSize
            }
            
            let chunkHexSize = String(chunkSize, radix: 16, uppercase: true)
            try self.client.writeUTF8Line(chunkHexSize)
            
            try self.client.writeBuffer(pointer + currentWritten, length: chunkSize)
            //try self.writeUTF8Line("")
            try self.client.writeUTF8("\r\n")
            
            currentWritten += chunkSize
            
        }
    }
    
    func writeContentsOfFile(atPath path: String,
                             range: LittleWebServer.HTTP.Response.Body.FileRange?,
                             speedLimit: LittleWebServer.FileTransferSpeedLimiter) throws {
        
        let file = try LittleWebServer.ReadableFile(path: path)
        
        
        defer {
            file.close()
        }
        
        let fileRange = range ?? LittleWebServer.HTTP.Response.Body.FileRange(file.size)
        
        if fileRange.lowerBound != 0 {
            try file.seek(to: fileRange.lowerBound)
        }
        
        let totalBufferSize = Int(speedLimit.bufferSize ?? self.defaultFileTransferBufferSize)
        
        let buffer = UnsafeMutablePointerContainer<UInt8>(capacity: totalBufferSize)
        defer {
            buffer.deallocate()
        }
        
        var currentRead: UInt = 0
        var readSize = totalBufferSize
        if fileRange.count < readSize { readSize = Int(fileRange.count) }
        while currentRead < fileRange.count && self.isConnected {
            let ret = try file.read(into: buffer, upToCount: readSize)
            guard ret > 0 else {
                break
            }
            currentRead += ret
            try self.writeBuffer(buffer, length: Int(ret))
            speedLimit.doPuase()
            
        }
    }
    
    public func close() throws {
        // Only write end chunk if we're writing chunked data
        // AND we have not already wrote the end chunk
        // AND we are still connected to client
        if self.chunked &&
           !self.hasWrittenZeroChunk &&
            self.isConnected {
            self.hasWrittenZeroChunk = true
            try self.client.writeUTF8("0\r\n\r\n")
            
        }
    }
}
