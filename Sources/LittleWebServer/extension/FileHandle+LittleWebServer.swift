//
//  FileHandle+LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-31.
//

import Foundation

internal extension FileHandle {
    
    func closeHandle() throws {
        #if swift(>=4.2) && _runtime(_ObjC)
            if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
                try self.close()
            } else {
                self.closeFile()
            }
        #else
            self.closeFile()
        #endif
    }
    
    func getCurrentOffset() throws -> UInt64 {
        #if swift(>=4.2) && _runtime(_ObjC)
            if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
                return try self.offset()
            } else {
                return self.offsetInFile
            }
        #else
            return self.offsetInFile
        #endif
    }
    
    func setCurrentOffset(_ value: UInt64) throws {
        #if swift(>=4.2) && _runtime(_ObjC)
            if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
                try self.seek(toOffset: value)
            } else {
                self.seek(toFileOffset: value)
            }
        #else
            self.seek(toFileOffset: value)
        #endif
    }
    
    func increaseCurrentOffset(by count: UInt) throws {
        let offset = try self.getCurrentOffset()
        try self.setCurrentOffset(offset + UInt64(count))
    }
    
    func read(into buffer: UnsafeMutablePointer<UInt8>, upToCount count: Int) throws -> UInt {
        precondition(count >= 0, "Count must be >= 0")
        guard count > 0 else {
            return 0
        }
        
        let currentOffset = try self.getCurrentOffset()
        
        #if os(Linux)
        let ret = Glibc.read(self.fileDescriptor, buffer, count)
        #else
        let ret = Darwin.read(self.fileDescriptor, buffer, count)
        #endif
        
        // validate error
        guard ret >= 0  else {
            throw LittleWebServerSocketSystemError.current()
        }
        
        try self.setCurrentOffset(currentOffset + UInt64(ret))
        //self.seek(toFileOffset: currentOffset + UInt64(ret))
        
        return UInt(ret)
    }
    
    func write(_ buffer: UnsafePointer<UInt8>, count: Int) throws {
        var written = 0
        while written < count {
            #if os(Linux)
            let ret = Glibc.write(self.fileDescriptor, buffer + written, Int(count - written))
            #else
            let ret = Darwin.write(self.fileDescriptor, buffer + written, Int(count - written))
            #endif
            
            guard ret >= 0  else {
                throw LittleWebServerSocketSystemError.current()
            }
            
            written += ret
            //try increaseCurrentOffset(by: UInt(ret))
        }
    }
    func write(bytes: [UInt8]) throws {
        var b = bytes
        try self.write(&b, count: b.count)
        
    }
    
    func write(byte: UInt8) throws {
        
        var b = byte
        
        try self.write(&b, count: 1)
        
    }
}
