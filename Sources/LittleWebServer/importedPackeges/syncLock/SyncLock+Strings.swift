//
//  SyncLock+Strings.swift
//  
//
//  Created by Tyler Anger on 2022-08-30.
//

import Foundation

internal extension _SyncLock where Object == String {
    
    static func +=(lhs: inout _SyncLock,
                   rhs: _SyncLock) {
        lhs.lockingForWithValue { ptr in
            ptr.pointee += rhs.value
        }
    }
    static func +=(lhs: inout _SyncLock,
                   rhs: Object) {
        lhs.lockingForWithValue { ptr in
            ptr.pointee += rhs
        }
    }
}

internal extension _SyncLock where Object: StringProtocol {
    
    static func == <RHS>(lhs: _SyncLock, rhs: RHS) -> Bool where RHS : StringProtocol {
        return lhs.lockingForWithValue { ptr in
            return ptr.pointee == rhs
        }
    }
    
    static func != <RHS>(lhs: _SyncLock, rhs: RHS) -> Bool where RHS : StringProtocol {
        return lhs.lockingForWithValue { ptr in
            return ptr.pointee != rhs
        }
    }
}
