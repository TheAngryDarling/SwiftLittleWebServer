//
//  ResultPatch.swift
//  LittleWebServerTests
//
//  Created by Tyler Anger on 2021-07-13.
//

import Foundation
/*
#if !swift(>=5.0)
    /// A value that represents either a success or a failure, including an
    /// associated value in each case.
    public enum Result<Success, Failure> where Failure : Error {

        /// A success, storing a `Success` value.
        case success(Success)

        /// A failure, storing a `Failure` value.
        case failure(Failure)

        /// Returns a new result, mapping any success value using the given
        /// transformation.
        ///
        /// Use this method when you need to transform the value of a `Result`
        /// instance when it represents a success. The following example transforms
        /// the integer success value of a result into a string:
        ///
        ///     func getNextInteger() -> Result<Int, Error> { /* ... */ }
        ///
        ///     let integerResult = getNextInteger()
        ///     // integerResult == .success(5)
        ///     let stringResult = integerResult.map({ String($0) })
        ///     // stringResult == .success("5")
        ///
        /// - Parameter transform: A closure that takes the success value of this
        ///   instance.
        /// - Returns: A `Result` instance with the result of evaluating `transform`
        ///   as the new success value if this instance represents a success.
        public func map<NewSuccess>(_ transform: (Success) -> NewSuccess) -> Result<NewSuccess, Failure> {
            switch self {
                case .success(let s): return .success(transform(s))
                case .failure(let e): return .failure(e)
            }
        }

        /// Returns a new result, mapping any failure value using the given
        /// transformation.
        ///
        /// Use this method when you need to transform the value of a `Result`
        /// instance when it represents a failure. The following example transforms
        /// the error value of a result by wrapping it in a custom `Error` type:
        ///
        ///     struct DatedError: Error {
        ///         var error: Error
        ///         var date: Date
        ///
        ///         init(_ error: Error) {
        ///             self.error = error
        ///             self.date = Date()
        ///         }
        ///     }
        ///
        ///     let result: Result<Int, Error> = // ...
        ///     // result == .failure(<error value>)
        ///     let resultWithDatedError = result.mapError({ e in DatedError(e) })
        ///     // result == .failure(DatedError(error: <error value>, date: <date>))
        ///
        /// - Parameter transform: A closure that takes the failure value of the
        ///   instance.
        /// - Returns: A `Result` instance with the result of evaluating `transform`
        ///   as the new failure value if this instance represents a failure.
        public func mapError<NewFailure>(_ transform: (Failure) -> NewFailure) -> Result<Success, NewFailure> {
            switch self {
                case .success(let s): return .success(s)
                case .failure(let e): return .failure(transform(e))
            }
            
        }

        /// Returns a new result, mapping any success value using the given
        /// transformation and unwrapping the produced result.
        ///
        /// - Parameter transform: A closure that takes the success value of the
        ///   instance.
        /// - Returns: A `Result` instance with the result of evaluating `transform`
        ///   as the new failure value if this instance represents a failure.
        public func flatMap<NewSuccess>(_ transform: (Success) -> Result<NewSuccess, Failure>) -> Result<NewSuccess, Failure> {
            switch self {
                case .success(let s): return transform(s)
                case .failure(let e): return .failure(e)
            }
        }

        /// Returns a new result, mapping any failure value using the given
        /// transformation and unwrapping the produced result.
        ///
        /// - Parameter transform: A closure that takes the failure value of the
        ///   instance.
        /// - Returns: A `Result` instance, either from the closure or the previous
        ///   `.success`.
        public func flatMapError<NewFailure>(_ transform: (Failure) -> Result<Success, NewFailure>) -> Result<Success, NewFailure> {
            switch self {
                case .success(let s): return .success(s)
                case .failure(let e): return transform(e)
            }
        }

        /// Returns the success value as a throwing expression.
        ///
        /// Use this method to retrieve the value of this result if it represents a
        /// success, or to catch the value if it represents a failure.
        ///
        ///     let integerResult: Result<Int, Error> = .success(5)
        ///     do {
        ///         let value = try integerResult.get()
        ///         print("The value is \(value).")
        ///     } catch error {
        ///         print("Error retrieving the value: \(error)")
        ///     }
        ///     // Prints "The value is 5."
        ///
        /// - Returns: The success value, if the instance represents a success.
        /// - Throws: The failure value, if the instance represents a failure.
        public func get() throws -> Success {
            switch self {
                case .success(let rtn): return rtn
                case .failure(let e): throw e
            }
        }
    }

    /*
    extension Result where Failure == Swift.Error {

        /// Creates a new result by evaluating a throwing closure, capturing the
        /// returned value as a success, or any thrown error as a failure.
        ///
        /// - Parameter body: A throwing closure to evaluate.
        public init(catching body: () throws -> Success) {
            do {
                self = Result<Success, Failure>.success(try body())
            } catch {
                self = Result<Success, Failure>.failure(error)
            }
        }
    }
    */
    #if swift(>=4.1)
        extension Result : Equatable where Success : Equatable, Failure : Equatable {

            /// Returns a Boolean value indicating whether two values are equal.
            ///
            /// Equality is the inverse of inequality. For any values `a` and `b`,
            /// `a == b` implies that `a != b` is `false`.
            ///
            /// - Parameters:
            ///   - lhs: A value to compare.
            ///   - rhs: Another value to compare.
            public static func == (a: Result<Success, Failure>, b: Result<Success, Failure>) -> Bool {
                switch (a, b) {
                    case (.success(let lhsS), .success(let rhsS)): return lhsS == rhsS
                    case (.failure(let lhsF), .failure(let rhsF)): return lhsF == rhsF
                    default: return false
                }
            }
        }


        extension Result : Hashable where Success : Hashable, Failure : Hashable {

            #if !swift(>=4.2)
            /// The hash value.
            ///
            /// Hash values are not guaranteed to be equal across different executions of
            /// your program. Do not save hash values to use during a future execution.
            ///
            /// - Important: `hashValue` is deprecated as a `Hashable` requirement. To
            ///   conform to `Hashable`, implement the `hash(into:)` requirement instead.
            public var hashValue: Int {
                switch self {
                    case .success(let rtn): return rtn.hashValue
                    case .failure(let rtn): return rtn.hashValue
                }
            }
            #endif

            #if swift(>=4.2)
                /// Hashes the essential components of this value by feeding them into the
                /// given hasher.
                ///
                /// Implement this method to conform to the `Hashable` protocol. The
                /// components used for hashing must be the same as the components compared
                /// in your type's `==` operator implementation. Call `hasher.combine(_:)`
                /// with each of these components.
                ///
                /// - Important: Never call `finalize()` on `hasher`. Doing so may become a
                ///   compile-time error in the future.
                ///
                /// - Parameter hasher: The hasher to use when combining the components
                ///   of this instance.
                public func hash(into hasher: inout Hasher) {
                    switch self {
                        case .success(let rtn):
                            hasher.combine(rtn)
                        case .failure(let rtn):
                            hasher.combine(rtn)
                    }
                }
            #endif
        }
    #endif
#endif
*/
