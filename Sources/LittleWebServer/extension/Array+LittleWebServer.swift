//
//  Array+LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-12.
//

import Foundation

internal extension Array {
    func subset(where condition: (Element) throws -> Bool) rethrows -> [Element] {
        var rtn: [Element] = []
        
        for element in self {
            if (try condition(element)) { rtn.append(element) }
        }
        
        return rtn
    }
    
    func appending(_ newElement: Element) -> Array<Element> {
        var rtn = self
        rtn.append(newElement)
        return rtn
    }
}

internal extension Array where Element: Equatable {
    func intersection<S>(_ other: S) -> Array<Element> where S: Sequence, S.Element == Element {
        var rtn: [Element] = []
        
        for element in other {
            if self.contains(element) { rtn.append(element) }
        }
        
        return rtn
    }
    
    func symmetricDifference<S>(_ other: S) -> Array<Element> where Element == S.Element, S : Sequence {
        var rtn: [Element] = []
        let otherArray = Array(other)
        
        for element in self {
            if !otherArray.contains(element) { rtn.append(element) }
        }
        
        for element in otherArray {
            if !self.contains(element) { rtn.append(element) }
        }
        
        return rtn
    }
    
    /// Returns an array of elements from the current array that were not in the sequence
    func missing<S>(from other: S) -> Array<Element> where Element == S.Element, S : Sequence {
        var rtn: [Element] = []
        for element in self {
            if !other.contains(element) { rtn.append(element) }
        }
        
        return rtn
    }
}

internal extension Sequence where Element == LittleWebServer.ListenerControl {
    func contains(_ element: LittleWebServerListener) -> Bool {
        return self.contains(where: { return $0.listener.uid == element.uid })
    }
}

internal extension Sequence where Element: LittleWebServerListener {
    func contains(_ element: LittleWebServer.ListenerControl) -> Bool {
        return self.contains(where: { return $0.uid == element.listener.uid })
    }
}

internal extension Array where Element == LittleWebServer.ListenerControl {
   
    func intersection<S>(_ other: S) -> Array<Element> where S: Sequence, S.Element: LittleWebServerListener {
        var rtn: [Element] = []
        
        for element in self {
            if other.contains(element) { rtn.append(element) }
        }
        
        return rtn
    }
    
    /// Returns an array of elements from the current array that were not in the sequence
    func missing<S>(from other: S) -> Array<Element> where S: Sequence, S.Element: LittleWebServerListener  {
        var rtn: [Element] = []
        
        for element in self {
            if !other.contains(element) { rtn.append(element) }
        }
        
        return rtn
    }
}

internal extension Array where Element: LittleWebServerListener {
    func contains(_ element: LittleWebServer.ListenerControl) -> Bool {
        return self.contains(where: { return $0.uid == element.listener.uid })
    }
    
    /// Returns an array of elements from the current array that were not in the sequence
    func missing<S>(from other: S) -> Array<Element> where S: Sequence, S.Element == LittleWebServer.ListenerControl  {
        var rtn: [Element] = []
        
        for element in self {
            if !other.contains(element) { rtn.append(element) }
        }
        
        return rtn
    }
}

internal extension Array where Element == LittleWebServer.Routing.Requests.BaseRoutes {
    subscript(method: LittleWebServer.HTTP.Method) -> LittleWebServer.Routing.Requests.BaseRoutes! {
        return self.first(where: { return $0.method == method})
    }
}

internal extension Array where Element: Equatable {
    func sameElements(as other: Array<Element>) -> Bool {
        guard self.count == other.count else { return false }
        for element in self {
            if !other.contains(element) { return false }
        }
        return true
    }
}
internal extension Array where Element == URLQueryItem {
    subscript(key: String) -> String? {
        return self.first(where: { return $0.name == key })?.value
    }
    
    init(urlQuery: String) {
        self.init()
        let items = urlQuery.split(separator: "&")
        for item in items {
            guard !item.isEmpty else { continue }
            let query = item.split(separator: "=")
            guard query.count >= 1 && !query[0].isEmpty else { continue }
            let name: String = query[0].removingPercentEncoding ?? String(query[0])
            var val: String? = nil
            if query.count > 1 {
                val = query[1].removingPercentEncoding ?? String(query[1])
            }
            self.append(URLQueryItem(name: name, value: val))
        }
    }
}

#if !swift(>=4.2)
internal extension Array {
    mutating func removeAll(where condition: (Element) -> Bool) {
        guard !self.isEmpty else { return }
        var currentIndex = self.startIndex
        while currentIndex < self.endIndex {
            if condition(self[currentIndex]) {
                self.remove(at: currentIndex)
            } else {
                currentIndex = self.index(after: currentIndex)
            }
        }
        /*
        var currentIndex = self.endIndex
        while currentIndex > self.startIndex {
            currentIndex = self.index(before: currentIndex)
            if condition(self[currentIndex]) {
                self.remove(at: currentIndex)
            }
        }*/
    }
    
    func compactMap<ElementOfResult>(_ transform: @escaping (Element) -> ElementOfResult?) -> Array<ElementOfResult> {
        var rtn: [ElementOfResult] = []
        for element in self {
            if let r = transform(element) {
                rtn.append(r)
            }
        }
        return rtn
    }
}
internal extension Array where Element: Equatable {
    func firstIndex(of element: Element) -> Index? {
        return self.firstIndex(where: { return $0 == element })
    }
}
#endif

