//
//  URL+LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-07-06.
//

import Foundation

internal extension URL {
    func resourceValues(forKeys keys: Set<URLResourceKey> = [.isDirectoryKey],
                        using manager: FileManager) throws -> _URLResourceValues {
        
        var resourceKeys: [FileAttributeKey : Any] = [:]
        var isDir: Bool? = nil
        var isD: Bool = false
        if manager.fileExists(atPath: self.path, isDirectory: &isD) {
            isDir = isD
            resourceKeys = try manager.attributesOfItem(atPath: self.path)
        }
        
        return _URLResourceValues(self, isDirectory: isDir, resourceKeys: resourceKeys)
        
        
    }
}
