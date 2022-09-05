//
//  SyncLock+Dictionary.swift
//  
//
//  Created by Tyler Anger on 2022-08-30.
//

import Foundation

//  Protocol defining a dictionary.
///  Intended use is in generic inits / methods / objects
internal protocol _SyncLockDictionaryDefinition: Collection where Element == (key: Key, value: Value) {
    associatedtype Key: Hashable
    associatedtype Value
    
    subscript(key: Key) -> Value? { get set }
    subscript(key: Key, default defaultValue: @autoclosure () -> Value) -> Value { get set }
}


extension Dictionary: _SyncLockDictionaryDefinition { }


// Provides access to a dictionary value
// Read / write access on class to ensrue that let variables can update
internal extension _SyncLock where Object: _SyncLockDictionaryDefinition {
    subscript(key: Object.Key) -> Object.Value? {
        get {
            return self.lockingForWithValue { return $0.pointee[key]  }
        }
        set {
            self.lockingForWithValue { $0.pointee[key] = newValue}
        }
    }
    subscript(key: Object.Key,
              default defaultValue: @autoclosure () -> Object.Value) -> Object.Value {
        get {
            return self.lockingForWithValue { return $0.pointee[key] } ?? defaultValue()
        }
        set {
            self.lockingForWithValue { $0.pointee[key] = newValue}
        }
    }
}
