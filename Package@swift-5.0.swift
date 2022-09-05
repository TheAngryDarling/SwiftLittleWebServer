// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LittleWebServer",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "LittleWebServer",
            targets: ["LittleWebServer"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/TheAngryDarling/SwiftStringIANACharacterSetEncoding.git",
                 from: "2.0.4"),
        
        // Packages for Unit Testing
        .package(url: "https://github.com/TheAngryDarling/SwiftUnitTestingHelper.git",
                 from: "1.0.4")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "LittleWebServer",
            dependencies: ["StringIANACharacterSetEncoding"]),
        .testTarget(
            name: "LittleWebServerTests",
            dependencies: ["LittleWebServer",
                           "UnitTestingHelper"]),
    ]
)
