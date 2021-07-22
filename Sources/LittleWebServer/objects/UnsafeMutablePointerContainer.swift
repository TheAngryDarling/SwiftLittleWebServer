//
//  UnsafeMutablePointerContainer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-16.
//

import Foundation


internal class UnsafeMutablePointerContainer<Pointee> {
    public private(set) var buffer: UnsafeMutablePointer<Pointee>
    public private(set) var capacity: Int
    private let defaultValue: Pointee
    
    
    public subscript(i: Int) -> Pointee {
        get { return self.buffer[i] }
        set { self.buffer[i] = newValue }
    }
    
    public init(capacity: Int, defaultValue: Pointee) {
        self.defaultValue = defaultValue
        self.capacity = capacity
        self.buffer = UnsafeMutablePointerContainer.allocateBuffer(capacity: capacity,
                                                                   defaultValue: defaultValue)
    }
    deinit {
        self.deallocate()
    }
    
    private static func allocateBuffer<Pointee>(capacity: Int,
                                                defaultValue: Pointee) -> UnsafeMutablePointer<Pointee> {
        precondition(capacity > 0, "Capacity must be > 0")
        let rtn = UnsafeMutablePointer<Pointee>.allocate(capacity: capacity)
        #if swift(>=4.1)
        rtn.initialize(repeating: defaultValue, count: capacity)
        #else
        rtn.initialize(to: defaultValue, count: capacity)
        #endif
        return rtn
    }
    
    private static func dellocateBuffer<Pointee>(_ buffer: UnsafeMutablePointer<Pointee>, capacity: Int) {
        if capacity > 0 {
            buffer.deinitialize(count: capacity)
            #if swift(>=4.1)
            buffer.deallocate()
            #else
            buffer.deallocate(capacity: capacity)
            #endif
        }
    }
    
    func deallocate() {
        guard self.capacity > 0  else {
            return
        }
        UnsafeMutablePointerContainer.dellocateBuffer(self.buffer, capacity: self.capacity)
        self.capacity = 0
    }
    
    func shiftLeft(count: Int) {
        guard count < self.capacity else {
            for i in 0..<self.capacity {
                self.buffer[i] = defaultValue
            }
            return
        }
        
        
    }
    
    typealias ResizeAction = (_ oldBuffer: UnsafeMutablePointer<Pointee>,
                              _ oldSize: Int,
                              _ newBuffer: UnsafeMutablePointer<Pointee>,
                              _ newSize: Int) -> Void
    
    func resize(capacity newCapacity: Int,
                action: ResizeAction? = nil) {
        precondition(newCapacity >= 0, "Invalid capacity")
        guard newCapacity != 0 else {
            UnsafeMutablePointerContainer.dellocateBuffer(self.buffer, capacity: self.capacity)
            self.capacity = 0
            return
        }
        let currentBuffer = self.buffer
        let currentCapacity = self.capacity
        
        let newBuffer = UnsafeMutablePointerContainer.allocateBuffer(capacity: newCapacity,
                                                                     defaultValue: self.defaultValue)
        
        
        
        let action = action ?? { oldBuffer, oldCount, newBuffer, newCount in
            var maxCopySize = newCount
            if oldCount < newCount {
                maxCopySize = oldCount
            }
            
            newBuffer.assign(from: oldBuffer, count: maxCopySize)
        }
        
        action(currentBuffer, currentCapacity, newBuffer, newCapacity)
        
        self.buffer = newBuffer
        self.capacity = newCapacity
        
        UnsafeMutablePointerContainer.dellocateBuffer(currentBuffer, capacity: currentCapacity)
        
    }
    
    func adjustCapacity(by count: Int,
                          action: ResizeAction? = nil) {
        self.resize(capacity: self.capacity + count, action: action)
    }
    
    func assign(from source: UnsafePointer<Pointee>, count: Int) {
        self.buffer.assign(from: source, count: count)
    }
    
    func assign(from source: UnsafeMutablePointerContainer<Pointee>, count: Int) {
        self.assign(from: source.buffer, count: count)
    }
    
    
    static func copyFromOld(_ range: Range<Int>) -> ResizeAction {
        return { oldBuffer, oldCount, newBuffer, newCount in
            newBuffer.assign(from: oldBuffer + range.lowerBound, count: range.count)
        }
    }
    
    static func copyFromOld(startingAt index: Int, count: Int? = nil) -> ResizeAction {
        return { oldBuffer, oldCount, newBuffer, newCount in
            let count = count ?? (oldCount - index)
            newBuffer.assign(from: oldBuffer + index, count: count)
        }
    }
    
    static func +(lhs: UnsafeMutablePointerContainer<Pointee>, rhs: Int) -> UnsafeMutablePointer<Pointee> {
        return lhs.buffer + rhs
    }
    
}

extension UnsafeMutablePointerContainer where Pointee: BinaryInteger {
    convenience init(capacity: Int) {
        self.init(capacity: capacity, defaultValue: 0)
    }
}


