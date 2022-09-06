//
//  XCTAssertsTrueFalse.swift
//  UnitTestingHelper
//
//  Created by Tyler Anger on 2020-12-02.
//

import XCTest

#if swift(>=5.3)
/// Same as its XCTAssert equivilant but will return a bool indicator if the test passed or not
public func XCTAsserts(_ expression: @autoclosure () throws -> Bool,
                       _ message: @autoclosure () -> String = "",
                        file: StaticString = #filePath,
                        line: UInt = #line) rethrows -> Bool {
    let e1 = try expression()
    
    XCTAssert(e1, message(), file: file, line: line)
    
    return e1
}

/// Same as its XCTAssert equivilant but will return a bool indicator if the test passed or not
public func XCTAssertsTrue(_ expression: @autoclosure () throws -> Bool,
                       _ message: @autoclosure () -> String = "",
                        file: StaticString = #filePath,
                        line: UInt = #line) rethrows -> Bool {
    let e1 = try expression()
    
    XCTAssertTrue(e1, message(), file: file, line: line)
    
    return e1
}

/// Same as its XCTAssert equivilant but will return a bool indicator if the test passed or not
@discardableResult
public func XCTAssertsFalse(_ expression: @autoclosure () throws -> Bool,
                       _ message: @autoclosure () -> String = "",
                        file: StaticString = #filePath,
                        line: UInt = #line) rethrows -> Bool {
    let e1 = try expression()
    
    XCTAssertFalse(e1, message(), file: file, line: line)
    
    return !e1
}
#else
/// Same as its XCTAssert equivilant but will return a bool indicator if the test passed or not
public func XCTAsserts(_ expression: @autoclosure () throws -> Bool,
                       _ message: @autoclosure () -> String = "",
                        file: StaticString = #file,
                        line: UInt = #line) rethrows -> Bool {
    let e1 = try expression()
    
    XCTAssert(e1, message(), file: file, line: line)
    
    return e1
}

/// Same as its XCTAssert equivilant but will return a bool indicator if the test passed or not
public func XCTAssertsTrue(_ expression: @autoclosure () throws -> Bool,
                       _ message: @autoclosure () -> String = "",
                        file: StaticString = #file,
                        line: UInt = #line) rethrows -> Bool {
    let e1 = try expression()
    
    XCTAssertTrue(e1, message(), file: file, line: line)
    
    return e1
}

/// Same as its XCTAssert equivilant but will return a bool indicator if the test passed or not
@discardableResult
public func XCTAssertsFalse(_ expression: @autoclosure () throws -> Bool,
                       _ message: @autoclosure () -> String = "",
                        file: StaticString = #file,
                        line: UInt = #line) rethrows -> Bool {
    let e1 = try expression()
    
    XCTAssertFalse(e1, message(), file: file, line: line)
    
    return !e1
}
#endif
