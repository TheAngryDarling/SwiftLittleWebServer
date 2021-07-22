//
//  _URLResourceValues.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-07-06.
//

import Foundation

internal struct _URLResourceValues {
    
    private let url: URL
    private let resourceKeys: [FileAttributeKey : Any]
    public let isDirectory: Bool?
    
    public var fileSize: Int? {
        guard let v = self.resourceKeys[.size],
              let number = v as? NSNumber else {
            return nil
        }
        
        return Int(truncating: number)
        
    }
    
    
    internal init(_ url: URL,
                  isDirectory: Bool? = nil,
                  resourceKeys: [FileAttributeKey : Any] = [:]) {
        self.url = url
        self.resourceKeys = resourceKeys
        self.isDirectory = isDirectory
    }
}
