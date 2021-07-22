//
//  LittleWebServerOpenRawRepresentable.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-07-10.
//

import Foundation
/// Represents an OpenEnum object
/// This protocol is intended to help user OpenEnum with generics
public protocol LittleWebServerOpenRawRepresentable: RawRepresentable where RawValue == Enum.RawValue {
    associatedtype Enum: RawRepresentable
    
    //var rawValue: Enum.RawValue { get }
    init(_ r: Enum)
    //init(rawValue: Enum.RawValue)
}

extension LittleWebServerOpenRawRepresentable where Enum.RawValue: Equatable {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    public static func ==(lhs: Self, rhs: Enum) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    public static func ==(lhs: Self, rhs: Enum.RawValue) -> Bool {
        return lhs.rawValue == rhs
    }
}

extension LittleWebServerOpenRawRepresentable where Enum.RawValue: Comparable {
    public static func <(lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    public static func <(lhs: Self, rhs: Enum) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    public static func <(lhs: Self, rhs: Enum.RawValue) -> Bool {
        return lhs.rawValue < rhs
    }
}

/// Represents an OpenEquatableEnum object
/// This protocol is intended to help user OpenEquatableEnum with generics
public protocol LittleWebServerOpenEquatableRawRepresentable: LittleWebServerOpenRawRepresentable,
                                                              Equatable
    where Enum.RawValue: Equatable {
}

public extension Collection where Element : LittleWebServerOpenEquatableRawRepresentable {
    func contains(_ element: Element.Enum) -> Bool {
        return self.contains(where: { return $0 == element })
    }
    
    func contains(_ element: Element.Enum.RawValue) -> Bool {
        return self.contains(where: { return $0 == element })
    }
    
    func firstIndex(of element: Element.Enum) -> Index? {
        return self.firstIndex(where: { return $0 == element  })
    }
    
    func firstIndex(of element: Element.Enum.RawValue) -> Index? {
        return self.firstIndex(where: { return $0 == element  })
    }
}
