# Swift Little WebServer

![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
[![Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=flat)](LICENSE.md)

A simple cross-platform web server, with little dependencies, that does not require switching its version based on the version of Swift being used.

This is helpful when sequentially testing against many different versions of Swift so different dependencies/versions are not required when switching Swift versions

>**Note**: This package doesn't directly support HTTPS Listeners as of yet.  
>Protocols/classes are in place, like **LittleWebServerListener** and **LittleWebServerSocketListener**, to allow custom listeners to be implemented

## Requirements

* Xcode 9+ (If working within Xcode)
* Swift 4.0+

## Usage

### Create a web server

```swift
import LittleWebServer

// Create a listener
let listener = try LittleWebServerHTTPListener(specificIP: .anyIPv4,
                                               port: .firstAvailable,
                                               reuseAddr: true)
                           
// Create the server
let server = LittleWebServer(listener)
// Lets name the server
server.serverHeader = "CoolServer"
// Setup server error handler
server.serverErrorHandler = { err in
   // Catch errors here for logging
   Swift.debugPrint("SERVER ERROR: \(err)")
}

/// Do handler setup here

server.start()


```

### Add basic request handlers

```swift

// Setup a request handler for the root of the server
server.defaultHost["/"] = { (request: LittleWebServer.HTTP.Request) -> LittleWebServer.HTTP.Response in
    return .ok(body: .html("HTML Content"))
}

// Setup a request handler for the root of the given domain
server.hosts["some.domain.com"]["/"] = { (request: LittleWebServer.HTTP.Request) -> LittleWebServer.HTTP.Response in
    return .ok(body: .html("HTML Content"))
}

```

### Share encodable Objects

```swift

struct ServerAPIError: Encodable {
    let id: Int
    let message: String
}

struct ServerStatus: Encodable {
...
}
public struct ModifiableObject: Codable,
                                Comparable,
                                LittleWebServerIdentifiableObject {
    public var id: Int
    public var description: String
    
    ...
}
enum SharePathError: Swift.Error, CustomStringConvertible {
    
    case objectAlreadyExists(Int)
    
    public var description: String {
        switch self {
            case .objectAlreadyExists(let id): return "Object with id '\(id)' already exists"
        }
    }
}

let objectEncoder = JSONEncoder() 
let objectDecoder = JSONDecoder() 
let status = ServerStatus()

func errorResponse(_ event: LittleWebServer.ObjectSharing.ErrorResponseEvent,
                   _ error: Swift.Error) -> ServerAPIError {
    return ServerAPIError(id: -1, message: "\(error)")
}
func notFoundResponse(_ request: LittleWebServer.HTTP.Request,
                      _ stringId: String,
                      _ objectId: Int?) -> ServerAPIError {
    return ServerAPIError(id: -404, message: "Object with ID '\(stringId)' not found")
}

// Share a readonly object
server.defaultHost["/status"] = LittleWebServer.ObjectSharing.shareObject(encoder: objectEncoder,
                                                                          object: status,
                                                                          errorResponse: errorResponse)
        
// Share an updatable object
var updatableObject = ModifiableObject()
server.defaultHost["/object"] = LittleWebServer.ObjectSharing.shareObject(encoder: objectEncoder,
                                                                          decoder: objectDecoder,
                                                                          object: &updatableObject,
                                                                          errorResponse: errorResponse)
                                                                          
var updatableList: [ModifiableObject] = []
server.defaultHost["/objects"] = LittleWebServer.ObjectSharing.sharePathObjects(encoder: objectEncoder,
                                                                                decoder: objectDecoder,
                                                                                objects: &updatableObject,
                                                                                objectExistError: { id in
                                                                                    return SharePathError.objectAlreadyExists(id)
                                                                                },
                                                                                objectSorter: <,
                                                                                notFoundResponse: notFoundResponse,
                                                                                errorResponse: errorResponse)

```

### Share File System Resources

```swift

// web root => /path/public
// path identity => :path{**}
//  identity name => path (This specific identity is needed for the share method)
//  rule Anything Here After => ** (This allows for any path including/after /path/public/)

// Limit the transfer seed of files
let speedLimiter: LittleWebServer.FileTransferSpeedLimiter = .unlimited
server.defaultHost["/path/public/:path{**}"] = LittleWebServer.FSSharing.share(resource: URL(fileURLWithPath: "..."),
                                                                               speedLimiter: speedLimiter)

```

### Web Sockets

```swift
// Create a web socket endpoint
server.defaultHost["/socket"] = LittleWebServer.WebSocket.endpoint { client, event in
    switch event {
        ...
    }
}

```

## Routing Paths

The Routing Path is the path used to help route requests to the proper request handler
Route paths are used on the subscript of a host router to define a default handler for a request or on the the subscript of a routing method to define the handler on a specific path for the given method

#### Route Path Components

**Route Path Component**

A Route Path Component is an individual path component like a directory name or file name in the path.  It does not contain a /


Basic Formatting: ":**Identifier**{ **Path Condition**? \<**Transformation**\>? { **Parameter Conditions** }? }"

No Identifier Formatting: "**Path Condition**{ \<Transformation\>? { **Parameter Conditions** }? }"
- Note: Path Condition can no be a regular expression when its outside the {}

No Identifier & No Path Condition Formatting: { \<Transformation\>? { **Parameter Conditions** }? }
- Note: In this instance the path condition becomes Anything(\*)

**Identifier**:

A path component can be assigned an identifier for access later from request.identities[...]

Format: ":{identifier name}..."
eg: ":path{\*\*}" <== This say the identifier is path the {} allows to set more properties to the component.  The \*\* indicates any path hereafter

**Path Condition**:

- Fixed Condition: Matches the exact text to the path component
- Regular Expression(**\^**...**\$**): Matches the path component against the regular expression pattern 
- Anything (**\***): Matches any path component
- Anything Hereafter(**\*\***): Matches any path value from here on


When the web server is matching a path to path components the order it checks the path condition is:
 1. Fixed Conditions
 2. Regular Expression Conditions
 3. Anything Condition
 4. Anything Hereafter Condition
 
 This allows for specific route handlers to be set to locations that would normally fall under an Anything Hereafter condition

**Transformation**:

The transformation, which must be wrapped in <...> is a identifier name of a string transforming function that takes the string value and optionally converts it to another type.  If the transforming function returns nil that would mean that the condition failed.

Initial registered transformers are the basic types Bool, Int, Int(8, 16, 32, 64), UInt, UInt(8, 16, 32, 64), Float, Double.<br/>
String formatted Int's are also supported:
- Hex String Int's: Int**X**, Int(8, 16, 32, 64)**X**, UInt**X**, UInt(8, 16, 32, 64)**X**
- Binary String Int's: Int**B**, Int(8, 16, 32, 64)**B**, UInt**B**, UInt(8, 16, 32, 64)**B**

Additional transformers can be registered by calling server.registerStringTransformer

**Parameter Condition**:

The format order of a parameter condition is important

Full Format: "? [ { **Condition / Condition Group**}, ...] \<**Transformation**\>"

Breakdown: 
- ? <- Indicates that this parameter is optional and will only validate if it is present.  If this flag is not set then the condition is required and if the parameter is missing the condition will fail
- Conditions: Optional, if present it contains one or more Conditions/Condition Groups.
    - Condition: An individual condition to match against the parameter
    - Condition Group: A group of conditions that must match against the parameter
- Transformation: See Transformation above

Examples:
- ? [ { ^[0-9]+$ } ] \<Int\> <-- Can be optional, must be numeric and will convert to Int
- ? [ { ^[0-9]+,[0-9]+$ } ] \<Point\> <-- Can be optional must be numeric,numeric and will convert to Point (x: Int, y: Int)
- [ { ^[0-9]+,[0-9]+$ } ] \<Point\> <-- Must be numeric,numeric and will convert to Point (x: Int, y: Int)
- [ { ^(valueA)|(valueB)$ } ] <-- Must match pattern ^(valueA)|(valueB)$ meaning must equal valueA or valueB
- [ { valueC } ] <-- Must match valueC
- \<Int\> <-- Must convert to Int

**Condition**: An individual parameter condition to match <br/>
A condition can be a regular expression (Must start with ^ and end with $) or an exact text match <br/>
Conditions must be encapsulated in { ... }


**Condition Group**: A group of Conditions / Condition Groups to match<br/>
Conditions / Condition Groups can be AND' (&&) and OR'd (||) to make a more complex match

Condition Groups must be encapsulated in { ... }

**Transformation** See Transformation above

**Parameter Conditions**:

Parameter conditions is a collection of of individual parameter conditions encapsulated within { } and separated by ,

Each Parameter name has a prefix of @ that denotes the start of a parameter name/condition<br/>

Parameter Names should not contain the ':' character

eg: { @**Parameter Name** : { **Parameter Condition / Condition Group** } , ... }

##### Route Path Slice

A Route Path Slice is a collection of Route Path Components and must not start with /

Examples:
- Basic Static Slice => "sub/path/to/resource"
- Path to any Sub Item => "sub/path/two/*"
- Path to anything here after => "sub/path/three/**"


#### Route Path Conditions

A Route Path Condition is the complete path from the root (/) to the endpoint to where a handler is to be set


## Dependencies

* **[Nillable](https://github.com/TheAngryDarling/SwiftNillable)** - Protocol attached to Optional and NSNull which allows developers to check if an object is nil or not.
* **[StringIANACharacterSetEncoding](https://github.com/TheAngryDarling/SwiftStringIANACharacterSetEncoding)** - IANA Character Set Encoding Conversion
* **[UnitTestingHelper](https://github.com/TheAngryDarling/SwiftUnitTestingHelper)** - Provides helper classes and methods to simplify unit testing

## Author

* **Tyler Anger** - *Initial work*  - [TheAngryDarling](https://github.com/TheAngryDarling)

## License

*Copyright 2021 Tyler Anger*

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[HERE](LICENSE.md) or [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Acknowledgments

* **[Swifter](https://github.com/httpswift/swifter/)** was heavily reference for how the sockets read and write as well as SHA1 algorithm specifics
* **[Wikipedia-SHA1](https://en.wikipedia.org/wiki/SHA-1)** was referenced for the SHA1 algorithm specification
