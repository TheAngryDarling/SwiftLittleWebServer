//
//  SyncLock+Comparable.swift
//  
//
//  Created by Tyler Anger on 2022-08-30.
//

import Foundation

internal extension _SyncLock where Object: Comparable {
    static func < (lhs: _SyncLock,
                   rhs: _SyncLock) -> Bool {
        return lhs.value < rhs.value
    }
    static func < (lhs: _SyncLock,
                   rhs: Object) -> Bool {
        return lhs.value < rhs
    }
    static func <= (lhs: _SyncLock,
                    rhs: _SyncLock) -> Bool {
        return lhs.value <= rhs.value
    }
    static func <= (lhs: _SyncLock,
                    rhs: Object) -> Bool {
        return lhs.value <= rhs
    }
    static func > (lhs: _SyncLock,
                   rhs: _SyncLock) -> Bool {
        return lhs.value > rhs.value
    }
    static func > (lhs: _SyncLock,
                   rhs: Object) -> Bool {
        return lhs.value > rhs
    }
    static func >= (lhs: _SyncLock,
                    rhs: _SyncLock) -> Bool {
        return lhs.value >= rhs.value
    }
    static func >= (lhs: _SyncLock,
                    rhs: Object) -> Bool {
        return lhs.value >= rhs
    }
}
