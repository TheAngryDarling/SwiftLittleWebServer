//
//  SyncLock+Equatable.swift
//  
//
//  Created by Tyler Anger on 2022-08-30.
//

import Foundation

internal extension _SyncLock where Object: Equatable {
    static func ==(lhs: _SyncLock,
                   rhs: _SyncLock) -> Bool {
        return lhs.value == rhs.value
    }
    static func ==(lhs: _SyncLock,
                   rhs: Object) -> Bool {
        return lhs.value == rhs
    }
    static func !=(lhs: _SyncLock,
                   rhs: _SyncLock) -> Bool {
        return lhs.value != rhs.value
    }
    static func !=(lhs: _SyncLock,
                   rhs: Object) -> Bool {
        return lhs.value != rhs
    }
}

#if swift(>=4.1)
extension _SyncLock: Equatable where Object: Equatable { }

// Would like to do this but gives an error about multiple matches of
// the >, >=, <, <= which are implemented in SynchronizableStorage+Comparable.swift
// extension SynchronizableObject: Comparable where Object: Comparable { }
#endif
