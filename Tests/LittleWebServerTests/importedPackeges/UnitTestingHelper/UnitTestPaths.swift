//
//  UnitTestPaths.swift
//  UnitTestingHelper
//
//  Created by Tyler Anger on 2020-07-07.
//

import Foundation

public struct UnitTestPaths {
    /// URL to the test target folder
    public let testTargetURL: URL
    
    /// URL to the Tests folder
    public var testsURL: URL { return self.testTargetURL.deletingLastPathComponent() }
    /// URL to the project folder
    public var projectURL: URL { return self.testsURL.deletingLastPathComponent()  }
    
    /// Creates a new instance of UnitTestPaths
    /// - Parameter testTargetPath: Path to the current test target folder
    public init(testTargetPath: String) {
        self.testTargetURL = URL(fileURLWithPath: testTargetPath, isDirectory: true)
    }
    /// Creates a new instance of UnitTestPaths
    /// - Parameter testTargetURL: URL to the current test target folder
    public init(testTargetURL: URL) {
        self.testTargetURL = testTargetURL
    }
    
    #if swift(>=5.3)
    /// Creates a new instance of UnitTestPaths
    /// - Parameter path: The path to a file within the test target path
    public init(fileInTestTargetFolder path: StaticString = #filePath) {
        var url = URL(fileURLWithPath: "\(path)", isDirectory: false)
        while url.deletingLastPathComponent().lastPathComponent != "Tests" && !url.path.isEmpty {
            url = url.deletingLastPathComponent()
        }
        self.testTargetURL = url
    }
    #else
    /// Creates a new instance of UnitTestPaths
    /// - Parameter path: The path to a file within the test target path
    public init(fileInTestTargetFolder path: StaticString = #file) {
        var url = URL(fileURLWithPath: "\(path)", isDirectory: false)
        while url.deletingLastPathComponent().lastPathComponent != "Tests" && !url.path.isEmpty {
            url = url.deletingLastPathComponent()
        }
        self.testTargetURL = url
    }
    #endif
    
    
    
}
