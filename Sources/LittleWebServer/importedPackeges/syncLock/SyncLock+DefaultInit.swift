//
//  SyncLock+DefaultInit.swift
//  
//
//  Created by Tyler Anger on 2022-08-30.
//

import Foundation

/// Protocol defining an object type that can be created with an
/// initializer with no parameters
public protocol _SyncLockDefaultInit {
    static func syncLockInit() -> Self
}

extension Dictionary: _SyncLockDefaultInit {
    public static func syncLockInit() -> Dictionary<Key, Value> {
        return .init()
    }
}
extension Array: _SyncLockDefaultInit {
    public static func syncLockInit() -> Array<Element> {
        return .init()
    }
}

extension Optional: _SyncLockDefaultInit {
    public static func syncLockInit() -> Optional<Wrapped> {
        return .none
    }
}
