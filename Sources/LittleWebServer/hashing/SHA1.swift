//
//  SHA1.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-10.
//
// Lifted/Modified from https://github.com/httpswift/swifter/blob/stable/Xcode/Sources/String%2BSHA1.swift

import Foundation

/// SHA1 Hasher
internal struct SHA1 {
    

    private static func rotateLeft(_ v: UInt32, _ n: UInt32) -> UInt32 {
        return ((v << n) & 0xFFFFFFFF) | (v >> (32 - n))
    }
    
    /// Hashes the given collection of bytes
    /// - Parameter input: The byte to hash
    /// - Returns: The hashed value
    public static func hash<C>(_ input: C) -> [UInt8] where C: Collection, C.Element == UInt8 {

        // Alghorithm from: https://en.wikipedia.org/wiki/SHA-1
        var message = Array(input)

        var h0 = UInt32(littleEndian: 0x67452301)
        var h1 = UInt32(littleEndian: 0xEFCDAB89)
        var h2 = UInt32(littleEndian: 0x98BADCFE)
        var h3 = UInt32(littleEndian: 0x10325476)
        var h4 = UInt32(littleEndian: 0xC3D2E1F0)

        // ml = message length in bits (always a multiple of the number of bits in a character).
        let ml = UInt64(message.count * 8)

        // append the bit '1' to the message e.g. by adding 0x80 if message length is a multiple of 8 bits.
        message.append(0x80)

        // append 0 ≤ k < 512 bits '0', such that the resulting message length in bits is congruent to −64 ≡ 448 (mod 512)
        let padBytesCount = ( message.count + 8 ) % 64

        message.append(contentsOf: [UInt8](repeating: 0, count: 64 - padBytesCount))

        // append ml, in a 64-bit big-endian integer. Thus, the total length is a multiple of 512 bits.
        var mlBigEndian = ml.bigEndian
        withUnsafePointer(to: &mlBigEndian) {
            message.append(contentsOf: Array(UnsafeBufferPointer<UInt8>(start: UnsafePointer(OpaquePointer($0)), count: 8)))
        }

        // Process the message in successive 512-bit chunks ( 64 bytes chunks ):
        let chunkSizeInBits = 512
        let chunkSizeInBytes = chunkSizeInBits / 8
        
        let wordSizeInBits = UInt32.bitWidth
        let wordSizeInBytes = wordSizeInBits / 8
        
        for currentIndex in stride(from: 0, to: message.count-1, by: chunkSizeInBytes) {
            let chunk = message[currentIndex..<(currentIndex+chunkSizeInBytes)]
            let wordCount = chunk.count / wordSizeInBytes
            
            // break chunk into sixteen 32-bit big-endian words w[i], 0 ≤ i ≤ 15
            var words: [UInt32] = chunk.withUnsafeBytes { buffer in
                let ptr = buffer.baseAddress!.bindMemory(to: UInt32.self, capacity: wordCount)
                let bufferPtr = UnsafeBufferPointer(start: ptr, count: wordCount)
                //let ptr = buffer.bindMemory(to: UInt32.self)
                return bufferPtr.map({ return UInt32(bigEndian: $0) })
                //return ptr.map(UInt32.init(bitpattern:))
            }
            
            // Extend the sixteen 32-bit words into eighty 32-bit words:
            for index in 16...79 {
                let value: UInt32 = ((words[index-3]) ^ (words[index-8]) ^ (words[index-14]) ^ (words[index-16]))
                words.append(rotateLeft(value, 1))
            }

            // Initialize hash value for this chunk:
            var a = h0
            var b = h1
            var c = h2
            var d = h3
            var e = h4

            for i in 0..<80 {
                var f: UInt32 = 0
                var k: UInt32 = 0
                switch i {
                    case 0...19:
                        f = (b & c) | ((~b) & d)
                        k = 0x5A827999
                    case 20...39:
                        f = b ^ c ^ d
                        k = 0x6ED9EBA1
                    case 40...59:
                        f = (b & c) | (b & d) | (c & d)
                        k = 0x8F1BBCDC
                    case 60...79:
                        f = b ^ c ^ d
                        k = 0xCA62C1D6
                    default: break
                }
                let temp = (rotateLeft(a, 5) &+ f &+ e &+ k &+ words[i]) & 0xFFFFFFFF
                e = d
                d = c
                c = rotateLeft(b, 30)
                b = a
                a = temp
                
            }

            // Add this chunk's hash to result so far:
            h0 = ( h0 &+ a ) & 0xFFFFFFFF
            h1 = ( h1 &+ b ) & 0xFFFFFFFF
            h2 = ( h2 &+ c ) & 0xFFFFFFFF
            h3 = ( h3 &+ d ) & 0xFFFFFFFF
            h4 = ( h4 &+ e ) & 0xFFFFFFFF
        }

        // Produce the final hash value (big-endian) as a 160 bit number:
        var digest = [UInt8]()

        [h0, h1, h2, h3, h4].forEach { value in
            var bigEndianVersion = value.bigEndian
            withUnsafePointer(to: &bigEndianVersion) {
                digest.append(contentsOf: Array(UnsafeBufferPointer<UInt8>(start: UnsafePointer(OpaquePointer($0)), count: 4)))
            }
        }

        return digest
    }
    
    /// Hash the given data block
    /// - Parameter input: The data to hash
    /// - Returns: The hashed value as a Data block
    public static func hash(data input: Data) -> Data {
        return Data(self.hash(input))
    }
    /// Hash the given UTF8 String
    /// - Parameter input: The string to hash
    /// - Returns: The hashed value as a Data block
    public static func hash(string input: String) -> Data {
        var mutableString = input
        
        return mutableString.withUTF8 {
            return Data(self.hash($0))
        }
    
        
    }
    
}
