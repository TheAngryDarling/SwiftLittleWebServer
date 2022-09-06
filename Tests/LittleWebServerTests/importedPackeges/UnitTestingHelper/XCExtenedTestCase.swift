
import XCTest

/// New Test Case class that provides provides URL's to specific locations within the project
/// For easy loading of test files to a relative path.  (Great for when testing between projects at different locations, like for different users, or going from host to docker tests)
/// Also provides overridable properties and functions for printing ((canPrint, print), (canVerbosePrint, verbosePrint), and (canDebugPrint, debugPrint))
open class XCExtenedTestCase: XCTestCase {
    
    open override class func setUp() {
        super.setUp()
        precondition(type(of: self) != XCExtenedTestCase.self,
                     "Can not initiate abstract class XCExtenedTestCase.  Please use class that inherits it.")
    }
    //private static var testingFile: String? = nil
    private static var testingFiles: [String: UnitTestPaths] = [:]
    #if swift(>=5.3)
    /// Used to initiate paths based on the test case file
    /// This method shoudl be called in the setUp method
    public class func initTestingFile(_ file: StaticString = #filePath) {
        //print(self)
        //testingFile = "\(file)"
        
        //print("\(self): \(file)")
        //testingFiles["\(self)"] = "\(file)"
        let strFile = "\(file)"
        guard let testsRange = strFile.range(of: "/Tests/") else {
            fatalError("Unable to identify 'Tests' folder in '\(strFile)'")
        }
        
        guard let unitTestEnding = strFile.range(of: "/",range: testsRange.upperBound..<strFile.endIndex) else {
            fatalError("Unable to identify TestTarget folder in '\(strFile)'")
        }
        
        let testTargetPath = String(strFile[...unitTestEnding.lowerBound])
        
        testingFiles["\(self)"] = UnitTestPaths(testTargetPath: testTargetPath)
    }
    #else
    /// Used to initiate paths based on the test case file
    /// This method shoudl be called in the setUp method
    public class func initTestingFile(_ file: StaticString = #file) {
        //print(self)
        //testingFile = "\(file)"
        
        //print("\(self): \(file)")
        //testingFiles["\(self)"] = "\(file)"
        let strFile = "\(file)"
        guard let testsRange = strFile.range(of: "/Tests/") else {
            fatalError("Unable to identify 'Tests' folder in '\(strFile)'")
        }
        
        guard let unitTestEnding = strFile.range(of: "/",range: testsRange.upperBound..<strFile.endIndex) else {
            fatalError("Unable to identify TestTarget folder in '\(strFile)'")
        }
        
        let testTargetPath = String(strFile[...unitTestEnding.lowerBound])
        
        testingFiles["\(self)"] = UnitTestPaths(testTargetPath: testTargetPath)
    }
    #endif
    /// Returns the Test Target File path.
    private class func testFilePath() -> UnitTestPaths {
        guard let s = testingFiles["\(self)"] else {
            //print("\(self)")
            fatalError("Testing File is not setup.  Please call initTestingFile first. Usually done by overriding the class setUp method")
        }
        return s
    }
    
    /// URL to the test target folder
    public static var testTargetURL: URL {
        return self.testFilePath().testTargetURL
    }
    
    
    
    /// URL to the project folder
    public static var projectURL: URL  {
        return self.testFilePath().projectURL
    }
    
     
    /// URL to the Tests folder
    public static var testsURL: URL {
        return self.testFilePath().testsURL
    }
    
    /// Returns the name ofthe Test Target
    public static var testTargetName: String {
        return self.testFilePath().testTargetURL.lastPathComponent
    }
    
    /// An indicator if we are runnning within Xcode
    ///
    /// Checks to see if the environmental variable XCTestConfigurationFilePath exists
    ///
    /// This property can be overridden for custom returns
    open class var isXcodeTesting: Bool {
        return (ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil)
    }
    
    
    /// URL to the project folder (Instance version of XCExtenedTestCase.projectURL)
    //public private(set) lazy var projectURL: URL = XCExtenedTestCase.projectURL
    public var projectURL: URL {
        //return Self.projectURL
        return type(of: self).projectURL
    }
    /// URL to the Tests folder (Instance version of XCExtenedTestCase.testsURL)
    public var testsURL: URL {
        return type(of: self).testsURL
    }
    /// URL to the test target folder (Instance version of XCExtenedTestCase.testTargetURL)
    public var testTargetURL: URL {
        return type(of: self).testTargetURL
    }
    
    /// Returns the name ofthe Test Target
    public var testTargetName: String {
        return type(of: self).testTargetName
    }
    
    /// An indicator if we are runnning within Xcode (Instance version of XCExtenedTestCase.isXcodeTesting)
    public var isXcodeTesting: Bool {
        return type(of: self).isXcodeTesting
    }
    
    /*
    internal enum PrintOverride {
        case none
        case override
        case disable
        
        fileprivate func canPrint(_ value: Bool) -> Bool {
            switch self {
            case .none: return value
            case .override: return true
            case .disable: return false
            }
            
        }
    }
    */
    /// An indicator if messages should be printed
    ///
    /// Note: Default returns true
    /// This property can be overridden for custom returns
    open var canPrint: Bool { return true }
    //private var overrideCanPrint: PrintOverride = .none
    
    /// An indicator if verbose messages should be printed
    ///
    /// Note: Default returns false
    /// This property can be overridden for custom returns
    open var canVerbosePrint: Bool { return false }
    //private var overrideCanVerbosePrint: PrintOverride = .none
    /// An indicator if debug messages should be printed
    ///
    /// Note: Default returns false
    /// This property can be overridden for custom returns
    open var canDebugPrint: Bool { return false }
    //private var overrideCanDebugPrint: PrintOverride = .none
    
    internal struct STDOut: TextOutputStream {
      internal init() {}

        mutating func write(_ string: String) {
            fputs(string, stdout)
        }
    }
    internal struct STDErr: TextOutputStream {
      internal init() {}

        mutating func write(_ string: String) {
            fputs(string, stderr)
        }
    }
    
    private static func _print<Target>(_ items: [Any],
                                separator: String = " ",
                                terminator: String = "\n",
                                to: inout Target) where Target: TextOutputStream {
        let msg = items.map({ return "\($0)"}).joined(separator: separator)
        to.write(msg + terminator)
    }
    
    private func _print<Target>(_ items: [Any],
                                separator: String = " ",
                                terminator: String = "\n",
                                to: inout Target) where Target: TextOutputStream {
        XCExtenedTestCase._print(items,
                                 separator: separator,
                                 terminator: terminator,
                                 to: &to)
    }
    
    private func _debugPrint<Target>(_ items: [Any],
                                     separator: String = " ",
                                terminator: String = "\n",
                                to: inout Target) where Target: TextOutputStream {
        let msg = items.map {
            if let d = $0 as? CustomDebugStringConvertible {
                return d.debugDescription
            } else if let d = $0 as? CustomStringConvertible {
                return d.description
            } else {
                return String(reflecting: $0)
            }
        }.joined(separator: separator)
        
        to.write(msg + terminator)
    }
    
    /// Prints the  message
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: A string to print between each item. The default is a single
    ///     space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The
    ///     default is a newline (`"\n"`).
    public static func print<Target>(_ items: Any...,
                                     separator: String = " ",
                                     terminator: String = "\n",
                                     to stream: inout Target) where Target: TextOutputStream {
        _print(items, separator: separator, terminator: terminator, to: &stream)
        
    }
    /// Prints the  message
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: A string to print between each item. The default is a single
    ///     space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The
    ///     default is a newline (`"\n"`).
    public static func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        var target = STDOut()
        _print(items, separator: separator, terminator: terminator, to: &target)
    }
    
    /// Prints the  message if and only if the canPrint property returns true
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: A string to print between each item. The default is a single
    ///     space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The
    ///     default is a newline (`"\n"`).
    public func print<Target>(_ items: Any...,
                              separator: String = " ",
                              terminator: String = "\n",
                              to stream: inout Target) where Target: TextOutputStream {
        guard Thread.current.overrideCanPrint.canPrint(self.canPrint) else { return }
        _print(items, separator: separator, terminator: terminator, to: &stream)
        
    }
    /// Prints the  message if and only if the canPrint property returns true
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: A string to print between each item. The default is a single
    ///     space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The
    ///     default is a newline (`"\n"`).
    public func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard Thread.current.overrideCanPrint.canPrint(self.canPrint) else { return }
        var target = STDOut()
        self._print(items, separator: separator, terminator: terminator, to: &target)
    }
    
    /// Prints the  message if and only if the canPrint property returns true
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - seperator: A string to print between each item. The default is a single
    ///     space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The
    ///     default is a newline (`"\n"`).
    @available(*, deprecated, renamed: "print", message: "The parameter seperator has changed to separator fixing spelling mistake")
    public func print<Target>(_ items: Any...,
                              seperator: String,
                              terminator: String = "\n",
                              to stream: inout Target) where Target: TextOutputStream {
        guard Thread.current.overrideCanPrint.canPrint(self.canPrint) else { return }
        _print(items, separator: seperator, terminator: terminator, to: &stream)
        
    }
    /// Prints the  message if and only if the canPrint property returns true
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - seperator: A string to print between each item. The default is a single
    ///     space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The
    ///     default is a newline (`"\n"`).
    @available(*, deprecated, renamed: "print", message: "The parameter seperator has changed to separator fixing spelling mistake")
    public func print(_ items: Any..., seperator: String, terminator: String = "\n") {
        guard Thread.current.overrideCanPrint.canPrint(self.canPrint) else { return }
        var target = STDOut()
        self._print(items, separator: seperator, terminator: terminator, to: &target)
    }
    
    /// Prints the verbose message if and only if the canVerbosePrint property returns true
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: A string to print between each item. The default is a single
    ///     space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The
    ///     default is a newline (`"\n"`).
    public func verbosePrint<Target>(_ items: Any...,
                                     separator: String = " ",
                                     terminator: String = "\n",
                                     to stream: inout Target) where Target: TextOutputStream {
        guard Thread.current.overrideCanVerbosePrint.canPrint(self.canVerbosePrint) else { return }
        _print(items, separator: separator, terminator: terminator, to: &stream)
        
    }
    /// Prints the verbose message if and only if the canVerbosePrint property returns true
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: A string to print between each item. The default is a single
    ///     space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The
    ///     default is a newline (`"\n"`).
    public func verbosePrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard Thread.current.overrideCanVerbosePrint.canPrint(self.canVerbosePrint) else { return }
        var target = STDOut()
        _print(items, separator: separator, terminator: terminator, to: &target)
    }
    
    /// Prints the verbose message if and only if the canVerbosePrint property returns true
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - seperator: A string to print between each item. The default is a single
    ///     space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The
    ///     default is a newline (`"\n"`).
    @available(*, deprecated, renamed: "verbosePrint", message: "The parameter seperator has changed to separator fixing spelling mistake")
    public func verbosePrint<Target>(_ items: Any...,
                                     seperator: String,
                                     terminator: String = "\n",
                                     to stream: inout Target) where Target: TextOutputStream {
        guard Thread.current.overrideCanVerbosePrint.canPrint(self.canVerbosePrint) else { return }
        _print(items, separator: seperator, terminator: terminator, to: &stream)
        
    }
    /// Prints the verbose message if and only if the canVerbosePrint property returns true
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - seperator: A string to print between each item. The default is a single
    ///     space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The
    ///     default is a newline (`"\n"`).
    @available(*, deprecated, renamed: "verbosePrint", message: "The parameter seperator has changed to separator fixing spelling mistake")
    public func verbosePrint(_ items: Any..., seperator: String, terminator: String = "\n") {
        guard Thread.current.overrideCanVerbosePrint.canPrint(self.canVerbosePrint) else { return }
        var target = STDOut()
        _print(items, separator: seperator, terminator: terminator, to: &target)
    }
    
    /// Prints the verbose message if and only if the canDebugPrint property returns true
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: A string to print between each item. The default is a single
    ///     space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The
    ///     default is a newline (`"\n"`).
    public func debugPrint<Target>(_ items: Any...,
                                   separator: String = " ",
                                     terminator: String = "\n",
                                     to stream: inout Target) where Target: TextOutputStream {
        guard Thread.current.overrideCanDebugPrint.canPrint(self.canDebugPrint) else { return }
        _debugPrint(items, separator: separator, terminator: terminator, to: &stream)
        
    }
    
    /// Prints the debug message if and only if the canDebugPrint property returns true
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: A string to print between each item. The default is a single
    ///     space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The
    ///     default is a newline (`"\n"`).
    public func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard Thread.current.overrideCanDebugPrint.canPrint(self.canDebugPrint) else { return }
        var target = STDOut()
        _debugPrint(items, separator: separator, terminator: terminator, to: &target)
    }
    
    /// Prints the verbose message if and only if the canDebugPrint property returns true
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - seperator: A string to print between each item. The default is a single
    ///     space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The
    ///     default is a newline (`"\n"`).
    @available(*, deprecated, renamed: "debugPrint", message: "The parameter seperator has changed to separator fixing spelling mistake")
    public func debugPrint<Target>(_ items: Any...,
                                     seperator: String,
                                     terminator: String = "\n",
                                     to stream: inout Target) where Target: TextOutputStream {
        guard Thread.current.overrideCanDebugPrint.canPrint(self.canDebugPrint) else { return }
        _debugPrint(items, separator: seperator, terminator: terminator, to: &stream)
        
    }
    
    /// Prints the debug message if and only if the canDebugPrint property returns true
    ///
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - seperator: A string to print between each item. The default is a single
    ///     space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The
    ///     default is a newline (`"\n"`).
    @available(*, deprecated, renamed: "debugPrint", message: "The parameter seperator has changed to separator fixing spelling mistake")
    public func debugPrint(_ items: Any..., seperator: String, terminator: String = "\n") {
        guard Thread.current.overrideCanDebugPrint.canPrint(self.canDebugPrint) else { return }
        var target = STDOut()
        _debugPrint(items, separator: seperator, terminator: terminator, to: &target)
    }
    
    /// Executes the given block of code while temporarily enabling canPrint
    public func withPrint(_ block: () -> Void) -> Void {
        let prevValue = Thread.current.overrideCanPrint
        Thread.current.overrideCanPrint = .override
        defer {
            Thread.current.overrideCanPrint = prevValue
        }
        block()
    }
    /// Executes the given block of code while temporarily disabling canPrint
    public func withoutPrint(_ block: () -> Void) -> Void {
        let prevValue = Thread.current.overrideCanPrint
        Thread.current.overrideCanPrint = .disable
        defer {
            Thread.current.overrideCanPrint = prevValue
        }
        block()
    }
    /// Executes the given block of code while temporarily enabling canVerbosePrint
    public func withVerbosePrint(_ block: () -> Void) -> Void {
        let prevValue = Thread.current.overrideCanVerbosePrint
        Thread.current.overrideCanVerbosePrint = .override
        defer {
            Thread.current.overrideCanVerbosePrint = prevValue
        }
        block()
    }
    /// Executes the given block of code while temporarily disabling canVerbosePrint
    public func withoutVerbosePrint(_ block: () -> Void) -> Void {
        let prevValue = Thread.current.overrideCanVerbosePrint
        Thread.current.overrideCanVerbosePrint = .disable
        defer {
            Thread.current.overrideCanVerbosePrint = prevValue
        }
        block()
    }
    /// Executes the given block of code while temporarily enabling canVerbosePrint
    public func withDebugPrint(_ block: () -> Void) -> Void {
        let prevValue = Thread.current.overrideCanDebugPrint
        Thread.current.overrideCanDebugPrint = .override
        defer {
            Thread.current.overrideCanDebugPrint = prevValue
        }
        block()
    }
    /// Executes the given block of code while temporarily disabling canVerbosePrint
    public func withoutDebugPrint(_ block: () -> Void) -> Void {
        let prevValue = Thread.current.overrideCanDebugPrint
        Thread.current.overrideCanDebugPrint = .disable
        defer {
            Thread.current.overrideCanDebugPrint = prevValue
        }
        block()
    }
    
    /// Executes the given block of code while temporarily enabling all prints
    public func withAnyPrint(_ block: () -> Void) -> Void {
        let prev = Thread.current.overrideCanPrint
        Thread.current.overrideCanPrint = .override
        let prevVerbose = Thread.current.overrideCanVerbosePrint
        Thread.current.overrideCanVerbosePrint = .override
        let prevDebug = Thread.current.overrideCanDebugPrint
        Thread.current.overrideCanDebugPrint = .override
        defer {
            Thread.current.overrideCanPrint = prev
            Thread.current.overrideCanVerbosePrint = prevVerbose
            Thread.current.overrideCanDebugPrint = prevDebug
        }
        block()
    }
    /// Executes the given block of code while temporarily disabling all prints
    public func withoutAnyPrint(_ block: () -> Void) -> Void {
        let prev = Thread.current.overrideCanPrint
        Thread.current.overrideCanPrint = .disable
        let prevVerbose = Thread.current.overrideCanVerbosePrint
        Thread.current.overrideCanVerbosePrint = .disable
        let prevDebug = Thread.current.overrideCanDebugPrint
        Thread.current.overrideCanDebugPrint = .disable
        defer {
            Thread.current.overrideCanPrint = prev
            Thread.current.overrideCanVerbosePrint = prevVerbose
            Thread.current.overrideCanDebugPrint = prevDebug
        }
        block()
    }
}
