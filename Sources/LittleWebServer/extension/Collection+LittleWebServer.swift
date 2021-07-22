//
//  Collection+LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-07-11.
//

import Foundation

internal extension Collection {
    
    
    #if !swift(>=4.2)
    func firstIndex(where condition: (Element) -> Bool) -> Index? {
        for (index, value) in self.enumerated() {
            if condition(value) { return (index as! Self.Index) }
        }
        return nil
    }
    #endif
}
