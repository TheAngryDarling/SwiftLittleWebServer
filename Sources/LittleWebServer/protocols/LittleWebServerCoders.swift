//
//  LittleWebServerCoders.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-21.
//

import Foundation

/// An object encoder that can take an object and encoder it into data
public protocol LittleWebServerObjectEncoder {
    /// The media type the data represents
    var littleWebServerContentMediaType: LittleWebServer.HTTP.Headers.ContentType.ResourceType { get }
    /// Encode the give object into data
    func encode<T>(_ value: T) throws -> Data where T : Encodable
}
internal extension LittleWebServerObjectEncoder {
    /// The content type the data represents
    var littleWebServerContentType: LittleWebServer.HTTP.Headers.ContentType {
        return .init(self.littleWebServerContentMediaType)
    }
}

public protocol LittleWebServerObjectDecoder {
    /// The media type this decoder expects the data to be in
    var littleWebServerContentMediaType: LittleWebServer.HTTP.Headers.ContentType.ResourceType { get }
    /// Decode the data to the given type
    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable
}
internal extension LittleWebServerObjectDecoder {
    /// The content type this decoder expects the data to be in
    var littleWebServerContentType: LittleWebServer.HTTP.Headers.ContentType {
        return .init(self.littleWebServerContentMediaType)
    }
}


extension JSONEncoder: LittleWebServerObjectEncoder {
    public var littleWebServerContentMediaType: LittleWebServer.HTTP.Headers.ContentType.ResourceType { return .json }
}

extension JSONDecoder: LittleWebServerObjectDecoder {
    public var littleWebServerContentMediaType: LittleWebServer.HTTP.Headers.ContentType.ResourceType { return .json }
}
