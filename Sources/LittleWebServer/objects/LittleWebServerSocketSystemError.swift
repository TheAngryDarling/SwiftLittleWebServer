//
//  LittleWebServerSocketSystemError.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-24.
//

import Foundation

/// Represents a System error with the given file and line it was created
public struct LittleWebServerSocketSystemError: Swift.Error/*, RawRepresentable*/, CustomStringConvertible {
    /// The system Error Code
    public let errno: CInt
    /// The file this SocketSystemError was created from
    public let file: String
    /// THe line this SocketSystemError was created from
    public let line: Int
    /// The message for this error code
    public var message: String {
        guard self.errno != 0 else {
            return "NOT AN ERROR"
        }
        return String(cString: UnsafePointer(strerror(self.errno)))
    }
    
    public var description: String {
        return "\(self.errno): \(self.message)"
    }
    #if swift(>=5.3)
    public init(errno: CInt, file: StaticString = #filePath, line: Int = #line) {
        self.errno = errno
        self.file = "\(file)"
        self.line = line
    }
    
    /// The current system error
    public static func current(file: StaticString = #filePath,
                               line: Int = #line) -> LittleWebServerSocketSystemError {
        return .init(errno: Foundation.errno, file: file, line: line)
    }
    #else
    public init(errno: CInt, file: StaticString = #file, line: Int = #line) {
        self.errno = errno
        self.file = "\(file)"
        self.line = line
    }
    /// The current system error
    public static func current(file: StaticString = #file,
                               line: Int = #line) -> LittleWebServerSocketSystemError {
        return .init(errno: Foundation.errno, file: file, line: line)
    }
    #endif
    
    public static func ==(lhs: LittleWebServerSocketSystemError, rhs: LittleWebServerSocketSystemError) -> Bool {
        return lhs.errno == rhs.errno
    }
}

public extension LittleWebServerSocketSystemError {
    static var brokenPipe: LittleWebServerSocketSystemError { return .init(errno: 32) }
    static var addressAlreadyInUse: LittleWebServerSocketSystemError { return .init(errno: 48) }
}


