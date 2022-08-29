//
//  RandomNumberGenerator.swift
//  LittleWebServerTests
//
//  Created by Tyler Anger on 2019-06-04.
//

import Foundation
#if os(Linux)
import Glibc
#endif


#if !swift(>=4.1.4)

    fileprivate func _swift_random<N>(_ number: inout N) where N: FixedWidthInteger {
        #if os(Linux)
            number = N(truncatingIfNeeded: random())
        #else
            withUnsafeMutablePointer(to: &number) {
                arc4random_buf($0, MemoryLayout<N>.size);
            }
        #endif
    }


    /// A type that provides uniformly distributed random data.
    ///
    /// When you call methods that use random data, such as creating new random
    /// values or shuffling a collection, you can pass a `RandomNumberGenerator`
    /// type to be used as the source for randomness. When you don't pass a
    /// generator, the default `SystemRandomNumberGenerator` type is used.
    ///
    /// When providing new APIs that use randomness, provide a version that accepts
    /// a generator conforming to the `RandomNumberGenerator` protocol as well as a
    /// version that uses the default system generator. For example, this `Weekday`
    /// enumeration provides static methods that return a random day of the week:
    ///
    ///     enum Weekday: CaseIterable {
    ///         case sunday, monday, tuesday, wednesday, thursday, friday, saturday
    ///
    ///         static func random<G: RandomNumberGenerator>(using generator: inout G) -> Weekday {
    ///             return Weekday.allCases.randomElement(using: &generator)!
    ///         }
    ///
    ///         static func random() -> Weekday {
    ///             var g = SystemRandomNumberGenerator()
    ///             return Weekday.random(using: &g)
    ///         }
    ///     }
    ///
    /// Conforming to the RandomNumberGenerator Protocol
    /// ================================================
    ///
    /// A custom `RandomNumberGenerator` type can have different characteristics
    /// than the default `SystemRandomNumberGenerator` type. For example, a
    /// seedable generator can be used to generate a repeatable sequence of random
    /// values for testing purposes.
    ///
    /// To make a custom type conform to the `RandomNumberGenerator` protocol,
    /// implement the required `next()` method. Each call to `next()` must produce
    /// a uniform and independent random value.
    ///
    /// Types that conform to `RandomNumberGenerator` should specifically document
    /// the thread safety and quality of the generator.
    internal protocol RandomNumberGenerator {

        /// Returns a value from a uniform, independent distribution of binary data.
        ///
        /// Use this method when you need random binary data to generate another
        /// value. If you need an integer value within a specific range, use the
        /// static `random(in:using:)` method on that integer type instead of this
        /// method.
        ///
        /// - Returns: An unsigned 64-bit random value.
        mutating func next() -> UInt64
    }

    extension RandomNumberGenerator {

        /// Returns a value from a uniform, independent distribution of binary data.
        ///
        /// Use this method when you need random binary data to generate another
        /// value. If you need an integer value within a specific range, use the
        /// static `random(in:using:)` method on that integer type instead of this
        /// method.
        ///
        /// - Returns: A random value of `T`. Bits are randomly distributed so that
        ///   every value of `T` is equally likely to be returned.
        public mutating func next<T>() -> T where T : FixedWidthInteger, T : UnsignedInteger {
            var rtn: T = 0
            _swift_random(&rtn)
            return rtn
        }

        /// Returns a random value that is less than the given upper bound.
        ///
        /// Use this method when you need random binary data to generate another
        /// value. If you need an integer value within a specific range, use the
        /// static `random(in:using:)` method on that integer type instead of this
        /// method.
        ///
        /// - Parameter upperBound: The upper bound for the randomly generated value.
        ///   Must be non-zero.
        /// - Returns: A random value of `T` in the range `0..<upperBound`. Every
        ///   value in the range `0..<upperBound` is equally likely to be returned.
        public mutating func next<T>(upperBound: T) -> T where T : FixedWidthInteger, T : UnsignedInteger {
            precondition(upperBound != 0, "upperBound cannot be zero.")
            /*let tmp = (T.max % upperBound) + 1
            let range = tmp == upperBound ? 0 : tmp
            var random: T = 0
 
            repeat {
                random = next()
            } while random < range
 
            return random % upperBound*/

            #if (arch(x86_64) || arch(arm64)) && swift(>=4.1.4)
                var random: T = next()
                var m = random.multipliedFullWidth(by: upperBound)
                if m.low < upperBound {
                    let t = (0 &- upperBound) % upperBound
                    while m.low < t {
                        random = next()
                        m = random.multipliedFullWidth(by: upperBound)
                    }
                }
                return m.high
            #else
                let tmp = (T.max % upperBound) + 1
                let range = tmp == upperBound ? 0 : tmp
                var random: T = 0

                repeat {
                    random = next()
                } while random < range

                return random % upperBound
            #endif
/*
            #if arch(i386) || arch(arm) // TODO(FIXME) SR-10912
                let tmp = (T.max % upperBound) + 1
                let range = tmp == upperBound ? 0 : tmp
                var random: T = 0

                repeat {
                    random = next()
                } while random < range

                return random % upperBound
            #elseif arch(x86_64) || arch(arm64)
                var random: T = next()
                var m = random.multipliedFullWidth(by: upperBound)
                if m.low < upperBound {
                    let t = (0 &- upperBound) % upperBound
                    while m.low < t {
                        random = next()
                        m = random.multipliedFullWidth(by: upperBound)
                    }
                }
                return m.high
            #else
                let tmp = (T.max % upperBound) + 1
                let range = tmp == upperBound ? 0 : tmp
                var random: T = 0

                repeat {
                    random = next()
                } while random < range

                return random % upperBound
            #endif
*/
        }
    }


    internal struct SystemRandomNumberGenerator : RandomNumberGenerator {
        /// Creates a new instance of the system's default random number generator.
        public init() { }

        /// Returns a value from a uniform, independent distribution of binary data.
        ///
        /// - Returns: An unsigned 64-bit random value.
        public mutating func next() -> UInt64 {
            var random: UInt64 = 0
            _swift_random(&random)
            return random
        }
    }

    internal extension FixedWidthInteger where Self.Magnitude : FixedWidthInteger, Self.Magnitude : UnsignedInteger {

        /// Returns a random value within the specified range, using the given
        /// generator as a source for randomness.
        ///
        /// Use this method to generate an integer within a specific range when you
        /// are using a custom random number generator. This example creates three
        /// new values in the range `1..<100`.
        ///
        ///     for _ in 1...3 {
        ///         print(Int.random(in: 1..<100, using: &myGenerator))
        ///     }
        ///     // Prints "7"
        ///     // Prints "44"
        ///     // Prints "21"
        ///
        /// - Note: The algorithm used to create random values may change in a future
        ///   version of Swift. If you're passing a generator that results in the
        ///   same sequence of integer values each time you run your program, that
        ///   sequence may change when your program is compiled using a different
        ///   version of Swift.
        ///
        /// - Parameters:
        ///   - range: The range in which to create a random value.
        ///     `range` must not be empty.
        ///   - generator: The random number generator to use when creating the
        ///     new random value.
        /// - Returns: A random value within the bounds of `range`.
        static func random<T: RandomNumberGenerator>(
            in range: Range<Self>,
            using generator: inout T
            ) -> Self {
            precondition(
                !range.isEmpty,
                "Can't get random value with an empty range"
            )


            // Compute delta, the distance between the lower and upper bounds. This
            // value may not representable by the type Bound if Bound is signed, but
            // is always representable as Bound.Magnitude.
            let delta = Self.Magnitude.init(truncatingIfNeeded: UInt(range.upperBound &- range.lowerBound))

            // The mathematical result we want is lowerBound plus a random value in
            // 0 ..< delta. We need to be slightly careful about how we do this
            // arithmetic; the Bound type cannot generally represent the random value,
            // so we use a wrapping addition on Bound.Magnitude. This will often
            // overflow, but produces the correct bit pattern for the result when
            // converted back to Bound.
            return Self.init(truncatingIfNeeded:
                (self.Magnitude.init(truncatingIfNeeded: range.lowerBound) &+
                    generator.next(upperBound: delta))
            )
        }

        /// Returns a random value within the specified range.
        ///
        /// Use this method to generate an integer within a specific range. This
        /// example creates three new values in the range `1..<100`.
        ///
        ///     for _ in 1...3 {
        ///         print(Int.random(in: 1..<100))
        ///     }
        ///     // Prints "53"
        ///     // Prints "64"
        ///     // Prints "5"
        ///
        /// This method is equivalent to calling the version that takes a generator,
        /// passing in the system's default random generator.
        ///
        /// - Parameter range: The range in which to create a random value.
        ///   `range` must not be empty.
        /// - Returns: A random value within the bounds of `range`.
        static func random(in range: Range<Self>) -> Self {
            var g = SystemRandomNumberGenerator()
            return Self.random(in: range, using: &g)
        }

        /// Returns a random value within the specified range, using the given
        /// generator as a source for randomness.
        ///
        /// Use this method to generate an integer within a specific range when you
        /// are using a custom random number generator. This example creates three
        /// new values in the range `1...100`.
        ///
        ///     for _ in 1...3 {
        ///         print(Int.random(in: 1...100, using: &myGenerator))
        ///     }
        ///     // Prints "7"
        ///     // Prints "44"
        ///     // Prints "21"
        ///
        /// - Parameters:
        ///   - range: The range in which to create a random value.
        ///   - generator: The random number generator to use when creating the
        ///     new random value.
        /// - Returns: A random value within the bounds of `range`.
        static func random<T: RandomNumberGenerator>(
            in range: ClosedRange<Self>,
            using generator: inout T
            ) -> Self {
            precondition(
                !range.isEmpty,
                "Can't get random value with an empty range"
            )
            // Compute delta, the distance between the lower and upper bounds. This
            // value may not representable by the type Bound if Bound is signed, but
            // is always representable as Bound.Magnitude.
            var delta = Magnitude.init(truncatingIfNeeded: (range.upperBound &- range.lowerBound))

            // Subtle edge case: if the range is the whole set of representable values,
            // then adding one to delta to account for a closed range will overflow.
            // If we used &+ instead, the result would be zero, which isn't helpful,
            // so we actually need to handle this case separately.
            if delta == Self.Magnitude.max {
                return Self.init(truncatingIfNeeded: generator.next())
            }
            // Need to widen delta to account for the right-endpoint of a closed range.
            delta += 1

            // The mathematical result we want is lowerBound plus a random value in
            // 0 ..< delta. We need to be slightly careful about how we do this
            // arithmetic; the Bound type cannot generally represent the random value,
            // so we use a wrapping addition on Bound.Magnitude. This will often
            // overflow, but produces the correct bit pattern for the result when
            // converted back to Bound.
            return Self.init(truncatingIfNeeded:
                (Magnitude(truncatingIfNeeded: range.lowerBound) &+
                    generator.next(upperBound: delta))
            )
        }

        /// Returns a random value within the specified range.
        ///
        /// Use this method to generate an integer within a specific range. This
        /// example creates three new values in the range `1...100`.
        ///
        ///     for _ in 1...3 {
        ///         print(Int.random(in: 1...100))
        ///     }
        ///     // Prints "53"
        ///     // Prints "64"
        ///     // Prints "5"
        ///
        /// This method is equivalent to calling `random(in:using:)`, passing in the
        /// system's default random generator.
        ///
        /// - Parameter range: The range in which to create a random value.
        /// - Returns: A random value within the bounds of `range`.
        static func random(in range: ClosedRange<Self>) -> Self {
            var g = SystemRandomNumberGenerator()
            return Self.random(in: range, using: &g)
        }


    }

    extension BinaryFloatingPoint where Self.RawSignificand: FixedWidthInteger {

      /// Returns a random value within the specified range, using the given
      /// generator as a source for randomness.
      ///
      /// Use this method to generate a floating-point value within a specific
      /// range when you are using a custom random number generator. This example
      /// creates three new values in the range `10.0 ..< 20.0`.
      ///
      ///     for _ in 1...3 {
      ///         print(Double.random(in: 10.0 ..< 20.0, using: &myGenerator))
      ///     }
      ///     // Prints "18.1900709259179"
      ///     // Prints "14.2286325689993"
      ///     // Prints "13.1485686260762"
      ///
      /// The `random(in:using:)` static method chooses a random value from a
      /// continuous uniform distribution in `range`, and then converts that value
      /// to the nearest representable value in this type. Depending on the size
      /// and span of `range`, some concrete values may be represented more
      /// frequently than others.
      ///
      /// - Note: The algorithm used to create random values may change in a future
      ///   version of Swift. If you're passing a generator that results in the
      ///   same sequence of floating-point values each time you run your program,
      ///   that sequence may change when your program is compiled using a
      ///   different version of Swift.
      ///
      /// - Parameters:
      ///   - range: The range in which to create a random value.
      ///     `range` must be finite and non-empty.
      ///   - generator: The random number generator to use when creating the
      ///     new random value.
      /// - Returns: A random value within the bounds of `range`.
      public static func random<T: RandomNumberGenerator>(
        in range: Range<Self>,
        using generator: inout T
      ) -> Self {
        _precondition(
          !range.isEmpty,
          "Can't get random value with an empty range"
        )
        let delta = range.upperBound - range.lowerBound
        //  TODO: this still isn't quite right, because the computation of delta
        //  can overflow (e.g. if .upperBound = .maximumFiniteMagnitude and
        //  .lowerBound = -.upperBound); this should be re-written with an
        //  algorithm that handles that case correctly, but this precondition
        //  is an acceptable short-term fix.
        _precondition(
          delta.isFinite,
          "There is no uniform distribution on an infinite range"
        )
        let rand: Self.RawSignificand
        if Self.RawSignificand.bitWidth == Self.significandBitCount + 1 {
          rand = generator.next()
        } else {
          let significandCount = Self.significandBitCount + 1
          let maxSignificand: Self.RawSignificand = 1 << significandCount
          // Rather than use .next(upperBound:), which has to work with arbitrary
          // upper bounds, and therefore does extra work to avoid bias, we can take
          // a shortcut because we know that maxSignificand is a power of two.
          rand = generator.next() & (maxSignificand - 1)
        }
        let unitRandom = Self.init(Double(Int(rand))) * (Self.ulpOfOne / 2)
        let randFloat = delta * unitRandom + range.lowerBound
        if randFloat == range.upperBound {
          return Self.random(in: range, using: &generator)
        }
        return randFloat
      }

      /// Returns a random value within the specified range.
      ///
      /// Use this method to generate a floating-point value within a specific
      /// range. This example creates three new values in the range
      /// `10.0 ..< 20.0`.
      ///
      ///     for _ in 1...3 {
      ///         print(Double.random(in: 10.0 ..< 20.0))
      ///     }
      ///     // Prints "18.1900709259179"
      ///     // Prints "14.2286325689993"
      ///     // Prints "13.1485686260762"
      ///
      /// The `random()` static method chooses a random value from a continuous
      /// uniform distribution in `range`, and then converts that value to the
      /// nearest representable value in this type. Depending on the size and span
      /// of `range`, some concrete values may be represented more frequently than
      /// others.
      ///
      /// This method is equivalent to calling `random(in:using:)`, passing in the
      /// system's default random generator.
      ///
      /// - Parameter range: The range in which to create a random value.
      ///   `range` must be finite and non-empty.
      /// - Returns: A random value within the bounds of `range`.
      public static func random(in range: Range<Self>) -> Self {
        var g = SystemRandomNumberGenerator()
        return Self.random(in: range, using: &g)
      }
      
      /// Returns a random value within the specified range, using the given
      /// generator as a source for randomness.
      ///
      /// Use this method to generate a floating-point value within a specific
      /// range when you are using a custom random number generator. This example
      /// creates three new values in the range `10.0 ... 20.0`.
      ///
      ///     for _ in 1...3 {
      ///         print(Double.random(in: 10.0 ... 20.0, using: &myGenerator))
      ///     }
      ///     // Prints "18.1900709259179"
      ///     // Prints "14.2286325689993"
      ///     // Prints "13.1485686260762"
      ///
      /// The `random(in:using:)` static method chooses a random value from a
      /// continuous uniform distribution in `range`, and then converts that value
      /// to the nearest representable value in this type. Depending on the size
      /// and span of `range`, some concrete values may be represented more
      /// frequently than others.
      ///
      /// - Note: The algorithm used to create random values may change in a future
      ///   version of Swift. If you're passing a generator that results in the
      ///   same sequence of floating-point values each time you run your program,
      ///   that sequence may change when your program is compiled using a
      ///   different version of Swift.
      ///
      /// - Parameters:
      ///   - range: The range in which to create a random value. Must be finite.
      ///   - generator: The random number generator to use when creating the
      ///     new random value.
      /// - Returns: A random value within the bounds of `range`.
      public static func random<T: RandomNumberGenerator>(
        in range: ClosedRange<Self>,
        using generator: inout T
      ) -> Self {
        _precondition(
          !range.isEmpty,
          "Can't get random value with an empty range"
        )
        let delta = range.upperBound - range.lowerBound
        //  TODO: this still isn't quite right, because the computation of delta
        //  can overflow (e.g. if .upperBound = .maximumFiniteMagnitude and
        //  .lowerBound = -.upperBound); this should be re-written with an
        //  algorithm that handles that case correctly, but this precondition
        //  is an acceptable short-term fix.
        _precondition(
          delta.isFinite,
          "There is no uniform distribution on an infinite range"
        )
        let rand: Self.RawSignificand
        if Self.RawSignificand.bitWidth == Self.significandBitCount + 1 {
          rand = generator.next()
          let tmp: UInt8 = generator.next() & 1
          if rand == Self.RawSignificand.max && tmp == 1 {
            return range.upperBound
          }
        } else {
          let significandCount = Self.significandBitCount + 1
          let maxSignificand: Self.RawSignificand = 1 << significandCount
          rand = generator.next(upperBound: maxSignificand + 1)
          if rand == maxSignificand {
            return range.upperBound
          }
        }
        let unitRandom = Self.init(Double(Int(rand))) * (Self.ulpOfOne / 2)
        let randFloat = delta * unitRandom + range.lowerBound
        return randFloat
      }
      
      /// Returns a random value within the specified range.
      ///
      /// Use this method to generate a floating-point value within a specific
      /// range. This example creates three new values in the range
      /// `10.0 ... 20.0`.
      ///
      ///     for _ in 1...3 {
      ///         print(Double.random(in: 10.0 ... 20.0))
      ///     }
      ///     // Prints "18.1900709259179"
      ///     // Prints "14.2286325689993"
      ///     // Prints "13.1485686260762"
      ///
      /// The `random()` static method chooses a random value from a continuous
      /// uniform distribution in `range`, and then converts that value to the
      /// nearest representable value in this type. Depending on the size and span
      /// of `range`, some concrete values may be represented more frequently than
      /// others.
      ///
      /// This method is equivalent to calling `random(in:using:)`, passing in the
      /// system's default random generator.
      ///
      /// - Parameter range: The range in which to create a random value. Must be finite.
      /// - Returns: A random value within the bounds of `range`.
      public static func random(in range: ClosedRange<Self>) -> Self {
        var g = SystemRandomNumberGenerator()
        return Self.random(in: range, using: &g)
      }
    }

    internal extension Sequence {
          /// Returns the elements of the sequence, shuffled using the given generator
          /// as a source for randomness.
          ///
          /// You use this method to randomize the elements of a sequence when you are
          /// using a custom random number generator. For example, you can shuffle the
          /// numbers between `0` and `9` by calling the `shuffled(using:)` method on
          /// that range:
          ///
          ///     let numbers = 0...9
          ///     let shuffledNumbers = numbers.shuffled(using: &myGenerator)
          ///     // shuffledNumbers == [8, 9, 4, 3, 2, 6, 7, 0, 5, 1]
          ///
          /// - Parameter generator: The random number generator to use when shuffling
          ///   the sequence.
          /// - Returns: An array of this sequence's elements in a shuffled order.
          ///
          /// - Complexity: O(*n*), where *n* is the length of the sequence.
          /// - Note: The algorithm used to shuffle a sequence may change in a future
          ///   version of Swift. If you're passing a generator that results in the
          ///   same shuffled order each time you run your program, that sequence may
          ///   change when your program is compiled using a different version of
          ///   Swift.
          func shuffled<T: RandomNumberGenerator>(using generator: inout T) -> [Element] {
                var result = ContiguousArray(self)
                result.shuffle(using: &generator)
                return Array(result)
          }

          /// Returns the elements of the sequence, shuffled.
          ///
          /// For example, you can shuffle the numbers between `0` and `9` by calling
          /// the `shuffled()` method on that range:
          ///
          ///     let numbers = 0...9
          ///     let shuffledNumbers = numbers.shuffled()
          ///     // shuffledNumbers == [1, 7, 6, 2, 8, 9, 4, 3, 5, 0]
          ///
          /// This method is equivalent to calling `shuffled(using:)`, passing in the
          /// system's default random generator.
          ///
          /// - Returns: A shuffled array of this sequence's elements.
          ///
          /// - Complexity: O(*n*), where *n* is the length of the sequence.
          func shuffled() -> [Element] {
                var g = SystemRandomNumberGenerator()
                return shuffled(using: &g)
          }
    }

    internal extension Collection {
        /// Returns a random element of the collection, using the given generator as
        /// a source for randomness.
        ///
        /// Call `randomElement(using:)` to select a random element from an array or
        /// another collection when you are using a custom random number generator.
        /// This example picks a name at random from an array:
        ///
        ///     let names = ["Zoey", "Chloe", "Amani", "Amaia"]
        ///     let randomName = names.randomElement(using: &myGenerator)!
        ///     // randomName == "Amani"
        ///
        /// - Parameter generator: The random number generator to use when choosing a
        ///   random element.
        /// - Returns: A random element from the collection. If the collection is
        ///   empty, the method returns `nil`.
        ///
        /// - Complexity: O(1) if the collection conforms to
        ///   `RandomAccessCollection`; otherwise, O(*n*), where *n* is the length
        ///   of the collection.
        /// - Note: The algorithm used to select a random element may change in a
        ///   future version of Swift. If you're passing a generator that results in
        ///   the same sequence of elements each time you run your program, that
        ///   sequence may change when your program is compiled using a different
        ///   version of Swift.
        func randomElement<T>(using generator: inout T) -> Self.Element? where T : RandomNumberGenerator {
            guard !self.isEmpty else { return nil }

            let position = Int.random(in: 0..<Int(self.count), using: &generator )
            #if !swift(>=4.0.4)
                return self[self.index(self.startIndex, offsetBy: IndexDistance(position))]
            #else
                return self[self.index(self.startIndex, offsetBy: position)]
            #endif
        }
        /// Returns a random element of the collection.
        ///
        /// Call `randomElement()` to select a random element from an array or
        /// another collection. This example picks a name at random from an array:
        ///
        ///     let names = ["Zoey", "Chloe", "Amani", "Amaia"]
        ///     let randomName = names.randomElement()!
        ///     // randomName == "Amani"
        ///
        /// This method is equivalent to calling `randomElement(using:)`, passing in
        /// the system's default random generator.
        ///
        /// - Returns: A random element from the collection. If the collection is
        ///   empty, the method returns `nil`.
        ///
        /// - Complexity: O(1) if the collection conforms to
        ///   `RandomAccessCollection`; otherwise, O(*n*), where *n* is the length
        ///   of the collection.
        func randomElement() -> Element? {
            var g = SystemRandomNumberGenerator()
            return self.randomElement(using: &g)
        }

    }

    internal extension MutableCollection where Self : RandomAccessCollection {
          /// Shuffles the collection in place, using the given generator as a source
          /// for randomness.
          ///
          /// You use this method to randomize the elements of a collection when you
          /// are using a custom random number generator. For example, you can use the
          /// `shuffle(using:)` method to randomly reorder the elements of an array.
          ///
          ///     var names = ["Alejandro", "Camila", "Diego", "Luciana", "Luis", "Sofía"]
          ///     names.shuffle(using: &myGenerator)
          ///     // names == ["Sofía", "Alejandro", "Camila", "Luis", "Diego", "Luciana"]
          ///
          /// - Parameter generator: The random number generator to use when shuffling
          ///   the collection.
          ///
          /// - Complexity: O(*n*), where *n* is the length of the collection.
          /// - Note: The algorithm used to shuffle a collection may change in a future
          ///   version of Swift. If you're passing a generator that results in the
          ///   same shuffled order each time you run your program, that sequence may
          ///   change when your program is compiled using a different version of
          ///   Swift.
          mutating func shuffle<T: RandomNumberGenerator>(using generator: inout T) {
                guard self.count > 1 else { return }
                var amount = Int(self.count)
                var currentIndex = startIndex
                while amount > 1 {
                      let random = Int.random(in: 0 ..< amount, using: &generator)
                      amount -= 1

                      #if !swift(>=4.0.4)
                      let swappedIndex = self.index(currentIndex, offsetBy: IndexDistance(random))
                      #else
                      let swappedIndex = self.index(currentIndex, offsetBy: random)
                      #endif
                      self.swapAt(currentIndex, swappedIndex)
                      formIndex(after: &currentIndex)
                }
          }

          /// Shuffles the collection in place.
          ///
          /// Use the `shuffle()` method to randomly reorder the elements of an array.
          ///
          ///     var names = ["Alejandro", "Camila", "Diego", "Luciana", "Luis", "Sofía"]
          ///     names.shuffle(using: myGenerator)
          ///     // names == ["Luis", "Camila", "Luciana", "Sofía", "Alejandro", "Diego"]
          ///
          /// This method is equivalent to calling `shuffle(using:)`, passing in the
          /// system's default random generator.
          ///
          /// - Complexity: O(*n*), where *n* is the length of the collection.
          mutating func shuffle() {
                var g = SystemRandomNumberGenerator()
                shuffle(using: &g)
          }
    }

    internal extension Bool {
        /// Returns a random Boolean value, using the given generator as a source for randomness.
        ///
        /// - Parameter generator: The random number generator to use when creating the
        ///     new random value.
        /// - Returns: Either true or false, randomly chosen with equal probability.
        static func random<T: RandomNumberGenerator>(using generator: inout T) -> Bool {
            //let range = Int.random(in: 0..<Int.max, using: &generator)
            //return ((range % 2) == 0)
            let v = Int.random(in: 0...1, using: &generator)
            return (v==1)
        }

        /// Returns a random Boolean value.
        ///
        /// - Returns: Either true or false, randomly chosen with equal probability.
        static func random() -> Bool {
            var g = SystemRandomNumberGenerator()
            return self.random(using: &g)
        }
    }

#endif

#if swift(>=5.5)
internal extension FixedWidthInteger {
    
    /// Returns a random value within the min and max of the Integer type.
    ///
    /// This is a helper method and is not part of Swift
    ///
    /// This method is equivalent to calling `random(in:using:)`, passing in the
    /// system's default random generator.
    ///
    /// - Parameter generator: The random number generator to use when creating the
    ///     new random value.
    /// - Returns: A random value within the bounds of Self.min...Self.max.
    static func random<T: RandomNumberGenerator>(using generator: inout T) -> Self {
        return self.random(in: Self.min...Self.max, using: &generator)
    }
    
    /// Returns a random value within the min and max of the Integer type.
    ///
    /// This is a helper method and is not part of Swift
    ///
    /// This method is equivalent to calling `random(using:)`, passing in the
    /// system's default random generator.
    ///
    /// - Returns: A random value within the bounds of Self.min...Self.max.
    static func random() -> Self {
        var g = SystemRandomNumberGenerator()
        return self.random(using: &g)
    }
}
#else
internal extension FixedWidthInteger where Self.Magnitude : FixedWidthInteger, Self.Magnitude : UnsignedInteger {
    
    /// Returns a random value within the min and max of the Integer type.
    ///
    /// This is a helper method and is not part of Swift
    ///
    /// This method is equivalent to calling `random(in:using:)`, passing in the
    /// system's default random generator.
    ///
    /// - Parameter generator: The random number generator to use when creating the
    ///     new random value.
    /// - Returns: A random value within the bounds of Self.min...Self.max.
    static func random<T: RandomNumberGenerator>(using generator: inout T) -> Self {
        return self.random(in: Self.min...Self.max, using: &generator)
    }
    
    /// Returns a random value within the min and max of the Integer type.
    ///
    /// This is a helper method and is not part of Swift
    ///
    /// This method is equivalent to calling `random(using:)`, passing in the
    /// system's default random generator.
    ///
    /// - Returns: A random value within the bounds of Self.min...Self.max.
    static func random() -> Self {
        var g = SystemRandomNumberGenerator()
        return self.random(using: &g)
    }
}
#endif
