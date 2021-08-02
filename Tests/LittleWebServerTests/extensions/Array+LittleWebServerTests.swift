//
//  Array+LittleWebServerTests.swift
//  LittleWebServerTests
//
//  Created by Tyler Anger on 2021-07-24.
//

import Foundation

#if !swift(>=4.2)
extension Array {
    func allSatisfy(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        for obj in self {
            if !(try predicate(obj)) { return false }
        }
        return true
    }
}
#endif
