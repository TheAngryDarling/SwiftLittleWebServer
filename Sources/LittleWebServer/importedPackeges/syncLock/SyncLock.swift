//
//  SyncLock.swift
//  
//
//  Created by Tyler Anger on 2022-08-30.
//

import Foundation

internal class _SyncLock<Object> {
    
    private var _value: Object
    private let _lock: NSLock
    
    /// Synchronized access to the resource
    public var value: Object {
        get { return self.lockingFor { return self._value } }
        set { self.lockingFor { self._value = newValue } }
    }
    /// Access to the resource without synchronization
    public var unsafeValue: Object {
        get { return  self._value }
        set { self._value = newValue }
    }
    
    /// Create new Synchronizable Object
    /// - Parameters:
    ///   - value: The Object to keep synchronized
    ///   - lock: The locking method
    public init(value: Object,
                lock: NSLock = NSLock()) {
        self._value = value
        self._lock = lock
    }
    
    
    /// Method used to lock the resource for the execution of the block
    public func lockingFor(_ block: () throws -> Void) rethrows {
        self._lock.lock()
        defer { self._lock.unlock()}
        try block()
    }
    
    /// Method used to lock the resource for the execution of the block
    public func lockingFor<T>(_ block: () throws -> T) rethrows -> T {
        self._lock.lock()
        defer { self._lock.unlock()}
        return try block()
    }
    
    
    /// Method used to lock the resource for the execution of the block
    public func lockingForWithValue(_ block: (UnsafeMutablePointer<Object>) throws -> Void) rethrows {
        self._lock.lock()
        defer { self._lock.unlock()}
        try block(&self._value)
    }
    
    /// Method used to lock the resource for the execution of the block
    public func lockingForWithValue<T>(_ block: (UnsafeMutablePointer<Object>) throws -> T) rethrows -> T {
        self._lock.lock()
        defer { self._lock.unlock()}
        return try block(&self._value)
    }
    
}

internal extension _SyncLock where Object: _SyncLockDefaultInit {
    /// Create new Synchronizable Object
    /// - Parameters:
    ///   - value: The Object to keep synchronized
    ///   - lock: The locking method
    convenience init(lock: NSLock = NSLock()) {
        self.init(value: Object.syncLockInit(),
                  lock: lock)
    }
}














