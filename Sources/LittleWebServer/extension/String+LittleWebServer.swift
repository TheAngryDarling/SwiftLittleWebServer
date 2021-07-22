//
//  String+LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-17.
//

import Foundation


internal extension String {
    var sha1: Data {
        return SHA1.hash(string: self)
    }
    
    func hasPrefix(_ character: Character) -> Bool {
        return self.hasPrefix("\(character)")
    }
    func hasSuffix(_ character: Character) -> Bool {
        return self.hasSuffix("\(character)")
    }
    
    func range(of character: Character,
               options: CompareOptions = [],
               range: Range<Index>? = nil,
               locale: Locale? = nil) -> Range<String.Index>? {
        return self.range(of: "\(character)", options: options, range: range, locale: locale)
    }
    
    #if !swift(>=4.2) || !(os(macOS) || os(iOS) || os(tvOS) || os(watchOS))
    mutating func withUTF8<R>(_ body: (UnsafeBufferPointer<UInt8>) throws -> R) rethrows -> R {
        let buffer: [UInt8] = Array(self.utf8)
        return try buffer.withUnsafeBufferPointer(body)
    }
    #endif
}
