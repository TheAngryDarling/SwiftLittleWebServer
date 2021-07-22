//
//  _LittleWebServerOutputStream.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-31.
//

import Foundation


internal class _LittleWebServerOutputStream: LittleWebServerOutputStream {
    
    
    public static let FileTransferBufferSize: UInt = 1024
    private let client: LittleWebServerClient
    public let chunked: Bool
    private let maxChunkedSize: Int?
    private let fileTransferBufferSize: UInt
    
    public var isConnected: Bool { return self.client.isConnected }
    
    public init(client: LittleWebServerClient,
                chunked: Bool,
                maxChunkedSize: Int? = nil,
                fileTransferBufferSize: UInt = _LittleWebServerOutputStream.FileTransferBufferSize) {
        self.client = client
        self.chunked = chunked
        self.maxChunkedSize = maxChunkedSize
        self.fileTransferBufferSize = fileTransferBufferSize
    }
    
    public convenience init(client: LittleWebServerClient,
                            transferEncodings: LittleWebServer.HTTP.Response.Headers.TransferEncodings?,
                            maxChunkedSize: Int? = nil,
                            fileTransferBufferSize: UInt = _LittleWebServerOutputStream.FileTransferBufferSize) {
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
            try self.writeUTF8Line("")
            
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
        
        let totalBufferSize = Int(speedLimit.bufferSize ?? self.fileTransferBufferSize)
        
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
        if self.chunked {
            try self.writeUTF8Line("0")
        }
    }
}
