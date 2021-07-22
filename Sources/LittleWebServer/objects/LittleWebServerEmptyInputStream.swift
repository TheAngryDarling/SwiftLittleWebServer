//
//  LittleWebServerEmptyInputStream.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-01.
//

import Foundation

/// An Empty Input Stream
internal class LittleWebServerEmptyInputStream: LittleWebServerInputStream {
    let hasBytesAvailable: Bool = false
    let isConnected: Bool = true
    
    
    public init() {}
    
    public func readBuffer(into buffer: UnsafeMutablePointer<UInt8>, count: Int) throws -> UInt {
        return 0
    }
    
    public func peekBuffer(into buffer: UnsafeMutablePointer<UInt8>, count: Int) throws -> UInt {
        return 0
    }
}
