//
//  SyncLock+Sequence.swift
//  
//
//  Created by Tyler Anger on 2022-08-30.
//

import Foundation

internal extension _SyncLock where Object: Sequence {
    typealias Element = Object.Element
    
    func contains(where predicate: @escaping (Element) throws -> Bool) rethrows -> Bool {
        return try self.lockingForWithValue { ptr in
            return try ptr.pointee.contains(where: predicate)
        }
    }
    
    func first(where predicate: @escaping (Element) throws -> Bool) rethrows -> Element? {
        return try self.lockingForWithValue { ptr in
            return try ptr.pointee.first(where: predicate)
        }
    }
    
    func filter(_ isIncluded: @escaping (Element) throws -> Bool) rethrows -> [Element] {
        return try self.lockingForWithValue { ptr in
            return try ptr.pointee.filter(isIncluded)
        }
    }
    
    func map<T>(_ transform: @escaping (Element) throws -> T) rethrows -> [T] {
        return try self.lockingForWithValue { ptr in
            return try ptr.pointee.map(transform)
        }
    }
    #if swift(>=4.1)
    func compactMap<T>(_ transform: @escaping (Element) throws -> T?) rethrows -> [T] {
        return try self.lockingForWithValue { ptr in
            return try ptr.pointee.compactMap(transform)
        }
    }
    #endif
    func flatMap<SegmentOfResult>(_ transform: @escaping (Element) throws -> SegmentOfResult) rethrows -> [SegmentOfResult.Element] where SegmentOfResult : Sequence {
        return try self.lockingForWithValue { ptr in
            return try ptr.pointee.flatMap(transform)
        }
    }
    
    func reduce<Result>(_ initialResult: Result,
                        _ nextPartialResult: @escaping (_ partialResult: Result,
                                                        Element) throws -> Result) rethrows -> Result {
        return try self.lockingForWithValue { ptr in
            return try ptr.pointee.reduce(initialResult, nextPartialResult)
        }
    }
    
    func reduce<Result>(into initialResult: Result,
                        _ updateAccumulatingResult: @escaping (_ partialResult: inout Result,
                                                               Element) throws -> ()) rethrows -> Result {
        return try self.lockingForWithValue { ptr in
            return try ptr.pointee.reduce(into: initialResult, updateAccumulatingResult)
        }
    }
    
    /// Locks the value and executes a for each before unlocking
    func forEach(_ body: @escaping (Element) throws -> Void) rethrows {
        try self.lockingForWithValue { ptr in
            try ptr.pointee.forEach(body)
        }
    }
    /// Locks the value and executes a for each before unlocking
    func forEach(_ body: @escaping (Element) -> Void) {
        self.lockingForWithValue { ptr in
            ptr.pointee.forEach(body)
        }
    }
}

internal extension _SyncLock where Object: Sequence, Object.Element: Equatable {
    func contains(_ element: Element) -> Bool {
        return self.lockingForWithValue { ptr in
            return ptr.pointee.contains(element)
        }
    }
}
