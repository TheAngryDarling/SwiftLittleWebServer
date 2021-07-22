//
//  Data+LittleWebServer.swift
//  LittleWebServerPackageDescription
//
//  Created by Tyler Anger on 2021-04-07.
//

import Foundation

internal extension Data {
    
    func hasSuffix(_ suffix: Data) -> Bool {
        guard self.count >= suffix.count else { return false }
        
        return (self.suffix(suffix.count) == suffix)
    }
    
    func hasSuffix(_ suffix: [UInt8]) -> Bool {
        return self.hasSuffix(Data(suffix))
    }
    
    func hasPrefix(_ prefix: Data) -> Bool {
        guard self.count >= prefix.count else { return false }
        return (self.prefix(prefix.count) == prefix)
    }
    
    func hasPrefix(_ prefix: [UInt8]) -> Bool {
        return self.hasPrefix(Data(prefix))
    }
}
