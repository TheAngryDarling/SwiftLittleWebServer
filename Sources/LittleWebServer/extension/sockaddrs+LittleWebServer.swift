//
//  sockaddrs+LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-02.
//

import Foundation

internal protocol AddressConvtable { }

extension AddressConvtable {
    
    mutating func asIP4Address<R>(_ body: @escaping (UnsafePointer<sockaddr_in>) throws -> R ) rethrows -> R {
        return try withUnsafePointer(to: &self) {
            return try $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1, body)
        }
    }
    
    mutating func asMutableIP4Address<R>(_ body: @escaping (UnsafeMutablePointer<sockaddr_in>) throws -> R ) rethrows -> R {
        return try withUnsafeMutablePointer(to: &self) {
            return try $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1, body)
        }
    }
    
    mutating func asIP6Address<R>(_ body: @escaping (UnsafePointer<sockaddr_in6>) throws -> R ) rethrows -> R {
        return try withUnsafePointer(to: &self) {
            return try $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1, body)
        }
    }
    
    mutating func asMutableIP6Address<R>(_ body: @escaping (UnsafeMutablePointer<sockaddr_in6>) throws -> R ) rethrows -> R {
        return try withUnsafeMutablePointer(to: &self) {
            return try $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1, body)
        }
    }
    
    mutating func asUnixAddress<R>(_ body: @escaping (UnsafePointer<sockaddr_un>) throws -> R ) rethrows -> R {
        return try withUnsafePointer(to: &self) {
            return try $0.withMemoryRebound(to: sockaddr_un.self, capacity: 1, body)
        }
    }
    
    mutating func asMutableUnixAddress<R>(_ body: @escaping (UnsafeMutablePointer<sockaddr_un>) throws -> R ) rethrows -> R {
        return try withUnsafeMutablePointer(to: &self) {
            return try $0.withMemoryRebound(to: sockaddr_un.self, capacity: 1, body)
        }
    }
}

extension sockaddr: AddressConvtable { }
extension addrinfo: AddressConvtable {
    mutating func asSockAddr<R>(_ body: @escaping (UnsafePointer<sockaddr>) throws -> R ) rethrows -> R {
        return try withUnsafePointer(to: &self) {
            return try $0.withMemoryRebound(to: sockaddr.self, capacity: 1, body)
        }
    }
    
    mutating func asSockAddr<R>(_ body: @escaping (UnsafeMutablePointer<sockaddr>) throws -> R ) rethrows -> R {
        return try withUnsafeMutablePointer(to: &self) {
            return try $0.withMemoryRebound(to: sockaddr.self, capacity: 1, body)
        }
    }
}
extension sockaddr_storage: AddressConvtable { }
