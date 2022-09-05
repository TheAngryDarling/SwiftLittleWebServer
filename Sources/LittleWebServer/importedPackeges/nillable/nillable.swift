//
//  Nillable.swift
//  
//
//  Created by Tyler Anger on 2022-08-31.
//

import Foundation

/// Protocol used when checking objects of Any type to be nilable
internal protocol _Nillable {

    /// Static variable returning the Wrapped type the optional object.
    /// Eg. Optional<String> will return String.  Optional<Optional<String>> will return Optional<String>
    /// Eg. NSNull will return Any
    static var wrappedType: Any.Type { get }

    /// Static variable returning the root Wrapped type of the optional object.
    /// This means if its a nested optional eg Optional<Optional<String>>, the return will still be String
    static var wrappedRootType: Any.Type { get }

    /// A nil value of the given type
    /// Eg. Optional<...>.none, NSNull()
    static var nilAnyValue: Any { get }

    /// Returns the Wrapped type the optional object.
    /// Eg. Optional<String> will return String.  Optional<Optional<String>> will return Optional<String>
    var wrappedType: Any.Type { get }

    /// Returns the root Wrapped type of the optional object.
    /// This means if its a nested optional eg Optional<Optional<String>>, the return will still be String
    var wrappedRootType: Any.Type { get }

    /// Indicates if this optional object is nil or not
    var isNil: Bool { get }
    /// Indicates if the root optional object is nil or not
    var isRootNil: Bool { get }
    /// Unsafely unwraps the object.  Refer to Optional.unsafelyUnwrapped
    var unsafeUnwrap: Any { get }
    /// Unsafely unwrapes the root object.
    var unsafeRootUnwrap: Any { get }
    /// Safely unwrapes the object
    var safeUnwrap: Any? { get }
    /// Safely unwapes the root object
    var safeRootUnwrap: Any? { get }

    /// Tests the current wrapped type
    ///
    /// - Parameter type: the type to test against
    /// - Returns: Returns true if the type provided is the same as the wraped type otherwise false
    func isWrappedType<T>(_ type: T.Type) -> Bool

    /// Test the root wrapped type
    ///
    /// - Parameter type: the type to test against
    /// - Returns: Returns true if the type provided is the same as the root wraped type otherwise false
    func isRootWrappedType<T>(_ type: T.Type) -> Bool

    /// Unsafely tries to unwrap the object to specific type.
    /// This could fail on the Optional.unsafelyUnwrapped or the casting from Any to T
    ///
    /// - Parameter type: The type to force unwrap to
    /// - Returns: Returns the wrapped object as the type provided or will fail because it was nil or casting error
    func unsafeUnwrap<T>(usingType type: T.Type) -> T

    /// Safely tries to unwrap the object to specific type.
    /// If any value is nil or could not cast to T this method will return nil
    ///
    /// - Parameter type: The type to unwrap to
    /// - Returns: Returns the wrapped object as the type provided or nil on any failures
    func safeUnwrap<T>(usingType type: T.Type) -> T?

    /// Unsafely tries to unwrap the root object to specific type.
    /// This could fail on the Optional.unsafelyUnwrapped or the casting from Any to T
    ///
    /// - Parameter type: The type to force unwrap to
    /// - Returns: Returns the root wrapped object as the type provided or will fail because it was nil or casting error
    func unsafeRootUnwrap<T>(usingType type: T.Type) -> T

    /// Safely tries to unwrap the root object to specific type.
    /// If any value is nil or could not cast to T this method will return nil
    ///
    /// - Parameter type: type: The type to unwrap to
    /// - Returns: Returns the root wrapped object as the type provided or nil on any failures
    func safeRootUnwrap<T>(usingType type: T.Type) -> T?
}

internal extension _Nillable {

    /// Indicates if the root optional object is nil or not
    var isRootNil: Bool {
        return (self.safeRootUnwrap == nil)
    }

    /// Safely unwrapes the object
    var safeUnwrap: Any? {
        guard !self.isNil else { return nil }
        return self.unsafeUnwrap
    }

    /// Returns the Wrapped type the optional object.
    /// Eg. Optional<String> will return String.  Optional<Optional<String>> will return Optional<String>
    var wrappedType: Any.Type { return Self.wrappedType }
    /// Static variable returning the root Wrapped type of the optional object.
    /// This means if its a nested optional eg Optional<Optional<String>>, the return will still be String
    var wrappedRootType: Any.Type { return Self.wrappedRootType }

    /// Tests the current wrapped type
    ///
    /// - Parameter type: the type to test against
    /// - Returns: Returns true if the type provided is the same as the wraped type otherwise false
    func isWrappedType<T>(_ type: T.Type) -> Bool {
        return (type == wrappedType)
    }
    /// Test the root wrapped type
    ///
    /// - Parameter type: the type to test against
    /// - Returns: Returns true if the type provided is the same as the root wraped type otherwise false
    func isRootWrappedType<T>(_ type: T.Type) -> Bool {
        return (type == self.wrappedRootType)
    }
    /// Unsafely tries to unwrap the object to specific type.
    /// This could fail on the Optional.unsafelyUnwrapped or the casting from Any to T
    ///
    /// - Parameter type: The type to force unwrap to
    /// - Returns: Returns the wrapped object as the type provided or will fail because it was nil or casting error
    func unsafeUnwrap<T>(usingType type: T.Type) -> T {
        let val = self.unsafeUnwrap
        // swiftlint:disable:next force_cast
        return val as! T
    }

    /// Safely tries to unwrap the object to specific type.
    /// If any value is nil or could not cast to T this method will return nil
    ///
    /// - Parameter type: The type to unwrap to
    /// - Returns: Returns the wrapped object as the type provided or nil on any failures
    func safeUnwrap<T>(usingType type: T.Type) -> T? {
        guard let val = self.safeUnwrap else { return nil }
        return val as? T
    }

    /// Unsafely tries to unwrap the root object to specific type.
    /// This could fail on the Optional.unsafelyUnwrapped or the casting from Any to T
    ///
    /// - Parameter type: The type to force unwrap to
    /// - Returns: Returns the root wrapped object as the type provided or will fail because it was nil or casting error
    func unsafeRootUnwrap<T>(usingType type: T.Type) -> T {
        let val = self.unsafeRootUnwrap
        // swiftlint:disable:next force_cast
        return val as! T
    }

    /// Safely tries to unwrap the root object to specific type.
    /// If any value is nil or could not cast to T this method will return nil
    ///
    /// - Parameter type: type: The type to unwrap to
    /// - Returns: Returns the root wrapped object as the type provided or nil on any failures
    func safeRootUnwrap<T>(usingType type: T.Type) -> T? {
        guard let val = self.safeRootUnwrap else { return nil }
        return val as? T
    }

}

extension NSNull: _Nillable {

    /// Implementation for Nillable.
    /// This will always return Any.self
    public static var wrappedType: Any.Type { return Any.self }
    /// Implementation for Nillable.
    /// This will always return Any.self
    public static var wrappedRootType: Any.Type { return Any.self }

    public static var nilAnyValue: Any { return NSNull() }

    /// Implementation for Nillable.
    /// Indicates if this optional object is nil or not.
    /// This will always return true
    public var isNil: Bool { return true }

    /// Implementation for Nillable.
    /// This will always cause a preconditionFailure
    public var unsafeUnwrap: Any { preconditionFailure("unsafelyUnwrapped of nil optional") }
    /// Implementation for Nillable.
    /// This will always cause a preconditionFailure
    public var unsafeRootUnwrap: Any { return self.unsafeUnwrap }
    /// Implementation for Nillable.
    /// This will always return nil
    public var safeRootUnwrap: Any? { return nil }
}

extension Optional: _Nillable {

    /// Static variable returning the Wrapped type the optional object.
    /// Eg. Optional<String> will return String.  Optional<Optional<String>> will return Optional<String>
    /// Eg. NSNull will return Any
    public static var wrappedType: Any.Type { return Wrapped.self }
    /// Static variable returning the root Wrapped type of the optional object.
    /// This means if its a nested optional eg Optional<Optional<String>>, the return will still be String
    public static var wrappedRootType: Any.Type {
        var rtn: Any.Type = Optional.wrappedType
        if let nillableType = rtn as? _Nillable.Type {
            rtn = nillableType.wrappedType
        }
        return rtn
    }

    public static var nilAnyValue: Any { return Optional<Wrapped>.none as Any }

    /// Indicates if this optional object is nil or not
    public var isNil: Bool {
        guard case .none = self else {
            return false
        }
        return true
    }
    /// Unsafely unwraps the object.  Refer to Optional.unsafelyUnwrapped
    public var unsafeUnwrap: Any { return self.unsafelyUnwrapped }
    /// Unsafely unwrapes the root object.
    public var unsafeRootUnwrap: Any {
        var rtn: Any = self.unsafeUnwrap
        if let nillableRtn = rtn as? _Nillable {
            rtn = nillableRtn.unsafeRootUnwrap
        }
        return rtn
    }
    /// Safely unwapes the root object
    public var safeRootUnwrap: Any? {
        guard !self.isNil else { return nil }

        if let nillableObject = self.unsafeUnwrap as? _Nillable {
            // If our Wrapped type is of optional type, then lets unwrap it
            return nillableObject.safeRootUnwrap
        } else {
            return self.unsafeUnwrap
        }
    }
}
