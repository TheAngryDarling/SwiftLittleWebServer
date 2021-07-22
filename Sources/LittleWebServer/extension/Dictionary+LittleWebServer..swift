//
//  Dictionary+LittleWebServer..swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-17.
//

import Foundation

internal extension Dictionary where Key == String, Value: Equatable {
    func sameElements(as other: Dictionary<Key, Value>) -> Bool {
        guard self.count == other.count else { return false }
        for (key, val) in self {
            guard let otherVal = other[key] else { return false }
            if val != otherVal { return false }
        }
        return true
    }
}
