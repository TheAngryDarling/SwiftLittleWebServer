//
//  LittleWebServerCustomStringHashable.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-20.
//

import Foundation

/// Hasable Helper Protocol.  Uses the hash for the description
public protocol LittleWebServerCustomStringHashable: CustomStringConvertible, Hashable { }
public extension LittleWebServerCustomStringHashable {
    #if !swift(>=4.2)
    var hashValue: Int { return self.description.hashValue }
    #else
    func hash(into hasher: inout Hasher) {
        self.description.hash(into: &hasher)
    }
    #endif
}

/// Hasable Helper Protocol.  Uses the hash for the description for swift < 4.2 and uses auto fill after
public protocol LittleWebServerStructCustomStringHashable: CustomStringConvertible, Hashable { }
public extension LittleWebServerStructCustomStringHashable {
    #if !swift(>=4.2)
    var hashValue: Int { return self.description.hashValue }
    #else
    func hash(into hasher: inout Hasher) {
        self.description.hash(into: &hasher)
    }
    #endif
}


/// Hasable Helper Protocol.  Uses the hash for the description lowercased
public protocol LittleWebServerCaseInsensativeCustomStringHashable: CustomStringConvertible, Hashable { }
public extension LittleWebServerCaseInsensativeCustomStringHashable {
    #if !swift(>=4.2)
    var hashValue: Int { return self.description.lowercased().hashValue }
    #else
    func hash(into hasher: inout Hasher) {
        self.description.lowercased().hash(into: &hasher)
    }
    #endif
}

/// Hasable Helper Protocol.  Uses the hash for the rawValue
public protocol LittleWebServerRawValueHashable: RawRepresentable, Hashable where RawValue: Hashable { }
public extension LittleWebServerRawValueHashable {
    #if !swift(>=4.2)
    var hashValue: Int { return self.rawValue.hashValue }
    #else
    func hash(into hasher: inout Hasher) {
        self.rawValue.hash(into: &hasher)
    }
    #endif
}
