//
//  LittleWebServerCommonHeaders.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-17.
//

import Foundation

/// Protocol contianing common request/response headers
public protocol LittleWebServerCommonHeaders: Collection,
                                              ExpressibleByDictionaryLiteral
    where Element == (key: LittleWebServer.HTTP.Headers.Name, value: Value) {
    
    subscript(key: LittleWebServer.HTTP.Headers.Name) -> String? { get set }
    subscript(position: Index) -> (key: LittleWebServer.HTTP.Headers.Name, value: Value) { get }
    
}

public extension LittleWebServerCommonHeaders {
    subscript(key: LittleWebServer.HTTP.Headers.Name,
              defaultValue: @autoclosure () -> String) -> String {
        return self[key] ?? defaultValue()
    }
    
    /// The HTTP Connection Header
    var connection: LittleWebServer.HTTP.Headers.Connection? {
        get {
            guard let val: String = self[.connection] else { return nil }
            return LittleWebServer.HTTP.Headers.Connection(rawValue: val)
        }
        set {
            self[.connection] = newValue?.rawValue ?? nil
        }
    }
    
    /// The HTTP Content-Type Header
    var contentType: LittleWebServer.HTTP.Headers.ContentType? {
        get {
            guard let val: String = self[.contentType] else { return nil }
            return LittleWebServer.HTTP.Headers.ContentType(val)
        }
        set {
            self[.contentType] = newValue?.description ?? nil
        }
    }
    
    /// The HTTP Content-Length Header
    var contentLength: UInt? {
        get {
            guard let val: String = self[.contentLength] else { return nil }
            return UInt(val)
        }
        set {
            self[.contentLength] = newValue?.description ?? nil
        }
    }
    
    /// The HTTP ETag Header
    var eTag: String? {
        get { return self[.eTag] }
        set { self[.eTag] = newValue }
    }
    
    /// The HTTP Host Header
    var host: LittleWebServer.HTTP.Headers.Host? {
        get {
            guard let val: String = self[.host] else { return nil }
            return LittleWebServer.HTTP.Headers.Host(val)
        }
        set {
            self[.host] = newValue?.description ?? nil
        }
    }
    
}

internal protocol _LittleWebServerCommonHeaders: LittleWebServerCommonHeaders {
    /// Function that transforms header names into a proper format
    func transformHeaderKey(_ key: String) -> String
    /// Get the HTTP 1.X header content
    var http1xContent: String { get }
}

internal extension _LittleWebServerCommonHeaders {
    static func defaultTransformHeaderKey(_ key: String) -> String {
        let customKeys: [String] = ["eTag"]
        for cK in customKeys {
            if cK.lowercased() == key {
                return cK
            }
        }
        
        var key = key
        key.replaceSubrange(key.startIndex..<key.index(after: key.startIndex),
                            with: key[key.startIndex].uppercased())
        
        var searchRange: Range<String.Index> = key.startIndex..<key.endIndex
        while let r = key.range(of: "-", range: searchRange) {
            if r.upperBound < key.endIndex {
                key.replaceSubrange(r.upperBound..<key.index(after: r.upperBound),
                                    with: key[r.upperBound].uppercased())
            }
            searchRange = r.upperBound..<key.endIndex
        }
        
        return key
    }
    func transformHeaderKey(_ key: String) -> String {
        return Self.defaultTransformHeaderKey(key)
    }
}

internal extension _LittleWebServerCommonHeaders where Value == String {
    var http1xContent: String {
        var rtn: String = ""
        let sortedData = self.sorted(by: { return $0.key < $1.key })
        for (key, val) in sortedData {
            var strHeaderKey = key.rawValue
            if !key.isProper {
                strHeaderKey = self.transformHeaderKey(key.rawValue)
            }
            
            rtn += strHeaderKey + ": " + val + "\r\n"
            
        }
        return rtn
    }
}


internal extension _LittleWebServerCommonHeaders where Value == LittleWebServer.HTTP.Response.Headers.HeaderValue {
    var http1xContent: String {
        var rtn: String = ""
        let sortedData = self.sorted(by: { return $0.key < $1.key })
        for (key, val) in sortedData {
            var strHeaderKey = key.rawValue
            if !key.isProper {
                strHeaderKey = self.transformHeaderKey(key.rawValue)
            }
            
            //let values = val.values
            let values = val
            
            for value in values {
                rtn += strHeaderKey + ": " + value + "\r\n"
            }
            
        }
        return rtn
    }
}
