//
//  _LittleWebServerInputStream.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-31.
//

import Foundation


internal class _LittleWebServerInputStream: LittleWebServerInputStream {
    
    private let client: LittleWebServerClient
    public internal(set) var chunked: Bool
    public internal(set) var reportedContentLength: UInt? = nil
    /// the size of the buffer
    private var rawBufferSize: Int
    /// The actual read buffer
    //private var rawReadBuffer: UnsafeMutablePointer<UInt8>
    private var rawReadBuffer: UnsafeMutablePointerContainer<UInt8>
    
    
    public private(set) var lastChunkSize: Int? = nil
    
    public var isConnected: Bool { return self.client.isConnected }
    public var hasBytesAvailable: Bool {
        guard let atEnd = self.endOfStream else {
            return true
        }
        return !atEnd
    }
    
    /// The current index of within the buffer
    private var currentRawBufferIndex: Int = 0 {
        didSet {
            self.currentRawBufferPeekIndex = self.currentRawBufferIndex
        }
    }
    
    /// The current peek index of within the buffer
    private var currentRawBufferPeekIndex: Int = 0 {
        willSet {
            precondition(newValue >= self.currentRawBufferIndex, "Peek Index must be >= read index")
        }
    }
    
    
    
    /// The size of readable data within the buffer
    private var currentRawBufferLength: Int = 0
    
    public private(set) var contentBytesRead: UInt = 0
    public private(set) var actualByteRead: UInt = 0
    
    private var currentRawBufferSize: Int {
        var rtn = self.currentRawBufferLength - self.currentRawBufferIndex
        if rtn < 0 { rtn = 0 }
        return rtn
    }
    
    private var currentRawBufferPeekSize: Int {
        var rtn = self.currentRawBufferLength - self.currentRawBufferPeekIndex
        if rtn < 0 { rtn = 0 }
        return rtn
    }
    
    public var endOfStream: Bool? {
        if let cS = self.lastChunkSize, cS == 0 {
            return true
        } else if let rCl = self.reportedContentLength {
            return self.contentBytesRead >= rCl
        }
        
        return nil
    }
    
    public init(client: LittleWebServerClient, chunked: Bool = false) {
        self.client = client
        self.chunked = chunked
        self.rawBufferSize = 1024
        
        self.rawReadBuffer = .init(capacity: self.rawBufferSize)
    }
    
    deinit {
        self.rawReadBuffer.deallocate()
    }
    
    private static func deallocBuffer(_ buffer: UnsafeMutablePointerContainer<UInt8>, size: Int) {
        buffer.deallocate()
    }
    
    private func resizeBufferIfNeeded(for size: Int) {
        // allocate new buffer
        
        let newSize = self.currentRawBufferSize + size
        
        // Make sure the total new size is more then the what we have available
        guard newSize > self.rawBufferSize else {
            // if we currently have data, we'll move it to the front
            if self.currentRawBufferSize > 0 {
                for i in 0..<self.currentRawBufferLength {
                    self.rawReadBuffer[i] = self.rawReadBuffer[self.currentRawBufferIndex + i] // copy byte to new location
                    self.rawReadBuffer[self.currentRawBufferIndex + i] = 0 // clear out old location
                }
                // Since we re-located the data to the beginning,
                // we must adjust the current index
                // we also adjust the peek index accouting for the shift
                // and the fact that updating the currentRawBufferIndex
                // changes currentRawBufferPeekIndex to currentRawBufferIndex
                let oldIndex = self.currentRawBufferIndex
                let oldPeekIndex = self.currentRawBufferPeekSize
                self.currentRawBufferIndex = 0
                self.currentRawBufferPeekIndex = oldPeekIndex - oldIndex
            }
            return
        }
        
        
        
        self.rawReadBuffer.adjustCapacity(by: size,
                                          action: UnsafeMutablePointerContainer<UInt8>.copyFromOld(startingAt: self.currentRawBufferIndex,
                                                                                                   count: self.currentRawBufferSize))
        
        
    }
    
    public func readBuffer(into buffer: UnsafeMutablePointer<UInt8>, count: Int) throws -> UInt {
        if !self.chunked {
            if self.currentRawBufferSize == 0 {
                var actualReadSize = count
                if let rcl = self.reportedContentLength {
                    // If we have a reported content length
                    // we need to ensure we don't go past it
                    if (self.contentBytesRead + UInt(count)) > rcl {
                        actualReadSize = Int(rcl) - Int(self.contentBytesRead)
                    }
                }
                guard actualReadSize > 0 else { return 0 }
                let rtn = try self.client.readBuffer(into: buffer, count: actualReadSize)
                
                self.actualByteRead += rtn
                self.contentBytesRead += rtn
                return rtn
            } else {
                var actualReadSize: Int = count
                if count > self.currentRawBufferSize {  actualReadSize = self.currentRawBufferSize }
                
                buffer.assign(from: self.rawReadBuffer + self.currentRawBufferIndex,
                              count: actualReadSize)
                
                self.currentRawBufferIndex += actualReadSize
                self.contentBytesRead += UInt(actualReadSize)
                return UInt(actualReadSize)
            }
        } else {
        
        
            if self.currentRawBufferSize == 0 {
                try self.readChunk()
            }
            
            guard self.currentRawBufferSize > 0 else { return 0 }
            
            let actualReadSize: Int
            if count < self.currentRawBufferSize {  actualReadSize = count }
            else { actualReadSize = self.currentRawBufferSize }
            
            
            buffer.assign(from: self.rawReadBuffer + self.currentRawBufferIndex,
                          count: actualReadSize)
            
            self.currentRawBufferIndex += actualReadSize
            self.contentBytesRead += UInt(actualReadSize)
            return UInt(actualReadSize)
        }
    }
     
    
    public func peekBuffer(into buffer: UnsafeMutablePointer<UInt8>, count: Int) throws -> UInt {
        
        var count = count
        // Adjust for end of body stream
        if let rcl = self.reportedContentLength {
            // If we have a reported content length
            // we need to ensure we don't go past it
            if (self.contentBytesRead + UInt(count)) > rcl {
                count = Int(rcl) - Int(self.contentBytesRead)
            }
        }
        
        guard count > 0 else { return 0 }
        
        // Make sure we have enought space at the end of the buffer for count bytes to be placed
        self.resizeBufferIfNeeded(for: count)
        
        if self.currentRawBufferSize < count {
            if self.chunked {
                while self.currentRawBufferSize < count {
                    try self.readChunk()
                }
            } else {
                let ret = try self.client.readBuffer(into: self.rawReadBuffer + self.currentRawBufferLength,
                                                     count: count)
                if ret == 0 {
                    return 0
                }
                
                self.actualByteRead += ret
                self.currentRawBufferLength = Int(ret)
                
            }
        }
        
        var actualReadSize: Int = count
        if count > self.currentRawBufferPeekSize {  actualReadSize = self.currentRawBufferPeekSize }
        
        buffer.assign(from: self.rawReadBuffer + self.currentRawBufferPeekIndex,
                      count: actualReadSize)
        
        self.currentRawBufferPeekIndex += actualReadSize
        
        return UInt(actualReadSize)
        
        
        
    }
    
    public func readChunk() throws {
        
        let hexSize = try self.client.readHTTPLine()
        self.actualByteRead += UInt(hexSize.count) + 2 // character + \r\n
        
        guard let size = Int(hexSize, radix: 16) else {
            throw LittleWebServerClientError.chunkInvalidSize(hexSize)
        }
        self.lastChunkSize = size
        
        self.resizeBufferIfNeeded(for: size)
        
        
        var currentReadSize = 0
        while currentReadSize < size {
            // Must start read into buffer the end of the total usable buffer (Not actual end of buffer)
            // Could be where the last buffer read left off
            let ret = try self.client.readBuffer(into: self.rawReadBuffer + self.currentRawBufferLength + currentReadSize,
                                                 count: (size - currentReadSize))
            guard ret > 0 else {
                throw LittleWebServerClientError.noBytesReturned
            }
            self.actualByteRead += ret
            currentReadSize += Int(ret)
            
        }
        // Update the total usable buffer size
        self.currentRawBufferLength += currentReadSize
        // Read CR
        let cr = try self.client.readByte()
        self.actualByteRead += 1
        guard cr == LittleWebServer.CR else {
            throw LittleWebServerClientError.chunkInvalidEndCharacter(expecting: LittleWebServer.CR, found: cr)
        }
        // Read LF
        let lf = try self.client.readByte()
        self.actualByteRead += 1
        guard lf == LittleWebServer.LF else {
            throw LittleWebServerClientError.chunkInvalidEndCharacter(expecting: LittleWebServer.LF, found: lf)
        }
    }
}
