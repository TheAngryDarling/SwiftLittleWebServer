//
//  SyncLock+Collections.swift
//  
//
//  Created by Tyler Anger on 2022-08-30.
//

import Foundation

internal extension _SyncLock where Object: Collection {
    typealias Index = Object.Index
    
    #if !swift(>=4.1)
    typealias IndexDistance = Object.IndexDistance
    #endif
    #if swift(>=4.1)
    var count: Int {
        return self.lockingForWithValue { ptr in
            return ptr.pointee.count
        }
    }
    #else
    var count: IndexDistance {
        return self.lockingForWithValue { ptr in
            return ptr.pointee.count
        }
    }
    #endif
    
    var startIndex: Index {
        return self.lockingForWithValue { ptr in
            return ptr.pointee.startIndex
        }
    }
    
    var endIndex: Index {
        return self.lockingForWithValue { ptr in
            return ptr.pointee.endIndex
        }
    }
    
    var isEmpty: Bool {
        return self.lockingForWithValue { ptr in
            return ptr.pointee.isEmpty
        }
    }
    
    var first: Element? {
        return self.lockingForWithValue { ptr in
            return ptr.pointee.first
        }
    }
    
    subscript(index: Index) -> Element {
        return self.lockingForWithValue { ptr in
            return ptr.pointee[index]
        }
    }
    
    subscript(bounds: Range<Index>) -> Object.SubSequence {
        return self.lockingForWithValue { ptr in
            return ptr.pointee[bounds]
        }
    }
    
}

internal extension _SyncLock where Object: BidirectionalCollection {
    
    var last: Element? {
        return self.lockingForWithValue { ptr in
            return ptr.pointee.last
        }
    }
    
}

internal extension _SyncLock
where Object: BidirectionalCollection,
      Object.SubSequence == Object {
    
    @discardableResult
    func removeLast() -> Element {
        return self.lockingForWithValue { ptr in
            return ptr.pointee.removeLast()
        }
    }
    
    func removeLast(_ k: Int) {
        self.lockingForWithValue { ptr in
            ptr.pointee.removeLast(k)
        }
    }
}

internal extension _SyncLock where Object: MutableCollection {
    subscript(index: Index) -> Element {
        get {
            return self.lockingForWithValue { ptr in
                return ptr.pointee[index]
            }
        }
        set {
            self.lockingForWithValue { ptr in
                ptr.pointee[index] = newValue
            }
        }
    }
}

internal extension _SyncLock where Object: RangeReplaceableCollection {
    func append(_ newElement: Element) {
        self.lockingForWithValue { ptr in
            ptr.pointee.append(newElement)
        }
    }
    func append<S>(contentsOf newElements: S) where S : Sequence, Element == S.Element {
        self.lockingForWithValue { ptr in
            ptr.pointee.append(contentsOf: newElements)
        }
    }
    func insert(_ newElement: Element, at i: Index) {
        self.lockingForWithValue { ptr in
            ptr.pointee.insert(newElement, at: i)
        }
    }
    
    @discardableResult
    func removeFirst() -> Element {
        return self.lockingForWithValue { ptr in
            return ptr.pointee.removeFirst()
        }
    }
    
    func removeFirst(_ k: Int) {
        self.lockingForWithValue { ptr in
            ptr.pointee.removeFirst(k)
        }
    }
    
    
    @discardableResult
    func remove(at i: Index) -> Element {
        return self.lockingForWithValue { ptr in
            return ptr.pointee.remove(at: i)
        }
    }
    
    func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows {
        return try self.lockingForWithValue { ptr in
            var i = ptr.pointee.startIndex
            while i < ptr.pointee.endIndex {
                if try shouldBeRemoved(ptr.pointee[i]) {
                    ptr.pointee.remove(at: i)
                } else {
                    i = ptr.pointee.index(after: i)
                }
            }
        }
    }
}

internal extension _SyncLock where Object: RangeReplaceableCollection, Object.Element: Equatable {
    func remove(_ element: Element) {
        self.removeAll(where: { return $0 == element })
    }
}
