//
//  UInt8+LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-07.
//

import Foundation

internal extension UInt8 {
    /// bit is a 0 base index where 0 bit is the most significant bit
    func contains(bit: Int) -> Bool {
        precondition(bit >= 0 && bit < 8, "Invalid bit position.  Must be >= 0 && < 8")
        
        var bitPattern: UInt8 = 0x01
        // shift bit to the left to specific location
        bitPattern = bitPattern << (7 - bit)
        
        return ((self & bitPattern) == bitPattern)
    }
    
    /*func bits(upto bit: Int) -> UInt8 {
        precondition(bit >= 0 && bit < 8, "Invalid bit position.  Must be >= 0 && < 8")
        var bitPattern: UInt8 = 0x80
        if bit > 0 {
            for _ in 1..<bit {
                bitPattern = (bitPattern >> 1) + 0x80
            }
        }
        return (self & bitPattern) >> (8 - bit)
    }*/
    
    func bits(from bit: Int) -> UInt8 {
        precondition(bit >= 0 && bit < 8, "Invalid bit position.  Must be >= 0 && < 8")
        
        var bitPattern: UInt8 = 0x01
        if bit < 7 {
            for _ in 0..<(7 - bit) {
                bitPattern = (bitPattern << 1) + 0x01
            }
        }
        //print("bits(from: \(bit)) { pattern: \(String(bitPattern, radix: 2))b }")
        return self & bitPattern
    }
}
