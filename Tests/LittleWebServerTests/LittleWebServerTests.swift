import XCTest
import Dispatch
@testable import LittleWebServer
import UnitTestingHelper
#if swift(>=4.1)
    #if canImport(FoundationNetworking)
    import FoundationNetworking
    #endif
#endif


class LittleWebServerTests: XCExtenedTestCase {
    
    struct ServerAPIError: Encodable {
        let id: Int
        let message: String
    }
    struct ServerDetails: Codable, Equatable {
        let version: String
        let isWindows: Bool
        let isLinux: Bool
        let isMac: Bool
        
        public init() {
            self.version = "1.0"
            
            #if os(Linux)
            self.isWindows = false
            self.isLinux = true
            self.isMac = false
            #elseif os(macOS)
            self.isWindows = false
            self.isLinux = false
            self.isMac = true
            #elseif os(Windows)
            self.isWindows = true
            self.isLinux = false
            self.isMac = false
            #else
            self.isWindows = false
            self.isLinux = false
            self.isMac = false
            #endif
        }
        
        public static func ==(lhs: ServerDetails, rhs: ServerDetails) -> Bool {
            return lhs.version == rhs.version &&
                   lhs.isWindows == rhs.isWindows &&
                   lhs.isLinux == rhs.isLinux &&
                   lhs.isMac == rhs.isMac
        }
    }
    
    public struct ModifiableObject: Codable,
                                    Comparable,
                                    LittleWebServerIdentifiableObject {
        public var id: Int
        public var description: String
        
        public static func ==(lhs: ModifiableObject, rhs: ModifiableObject) -> Bool {
            return lhs.id == rhs.id
        }
        public static func <(lhs: ModifiableObject, rhs: ModifiableObject) -> Bool {
            return lhs.id < rhs.id
        }
    }
    
    public static let serverDetails = ServerDetails()
    public static var modifiableList: [ModifiableObject] = []
    public static var modifiableObject = ModifiableObject(id: 0, description: "New")
    
    
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    
    
    private static var server: LittleWebServer? = nil
    private static let initPort: LittleWebServerSocketConnection.Address.TCPIPPort = .firstAvailable //64308
    private static var triedServerInit: Bool = false
    private static let serverSync = DispatchQueue(label: "LittleWebServerTests.server.sync")
    
    private static let serverRootIndexHTML: String = """
                                                    <html>
                                                    <head><title>Welcome</title></head>
                                                    <body>
                                                    <center><h1>Welcome to the Test Server</h1></center>
                                                    </body>
                                                    </html>
                                                    """
    
    private static var serverRootIndexHTMLCRLF: String {
        return self.serverRootIndexHTML.replacingOccurrences(of: "\n", with: "\r\n")
    }
    
    private static let testIndexHTML: String = """
                                               <html>
                                               <head><title>Static File</title></head>
                                               <body>
                                               <center><h1>This is a static file</h1></center>
                                               </body>
                                               </html>
                                               """
    private static var testIndexHTMLCRLF: String {
        return self.testIndexHTML.replacingOccurrences(of: "\n", with: "\r\n")
    }
    
    override class func setUp() {
        self.initTestingFile()
        super.setUp()
    }
    
    override class func tearDown() {
        self.server?.stop()
        super.tearDown()
    }
    
    private static func getServer() -> LittleWebServer? {
        return self.serverSync.sync {
            if let s = self.server { return s }
            guard !self.triedServerInit else { return nil }
            self.triedServerInit = true
            var retryCount: Int = 0
            repeat {
                do {
                    let listener = try LittleWebServerHTTPListener(specificIP: .anyIPv4,
                                                                   port: self.initPort,
                                                                   reuseAddr: true)
                    let rtn = LittleWebServer(listener)
                    rtn.serverHeader = "CoolServer"
                    rtn.serverErrorHandler = { err in
                        Swift.debugPrint("SERVER ERROR: \(err)")
                    }
                    try rtn.start()
                
                    self.setupTestRoutes(on: rtn)
                    
                    self.server = rtn
                    
                    for listener in rtn.listeners {
                        print("[Server]: Listening on '\(listener.uid)'")
                    }
                    if retryCount > 0 {
                        var waitTime: Double = 0.0
                        for i in 1...retryCount {
                            waitTime += Double(5 * i)
                        }
                        print("[Server]: Total time wating on socket: \(waitTime)s")
                    }
                    return rtn
                } catch LittleWebServerSocketConnection.SocketError.socketBindFailed(let error) {
                    
                    if let sysError = error as? LittleWebServerSocketSystemError,
                       sysError == .addressAlreadyInUse && retryCount < 3 {
                        retryCount += 1
                        switch retryCount {
                        case 1:
                            print("Socket is currently in use.  Wating to see if it gets released...")
                        case 2:
                            print("Socket is still in use.  Wating a little longer to see if it gets released...")
                        case 3:
                            print("Socket is still in use.  Wating even longer to see if it gets released...")
                        default:
                            print("Still waiting on socket.  It might actualy be in use :(")
                        }
                        
                        // Wait for a couple of seconds so see if the socket gets released
                        Thread.sleep(forTimeInterval: Double(5 * retryCount))
                        // We don't return so that we can loop around
                        print("Re-Trying(\(retryCount)) to listen")
                    } else {
                        print("Failed to create server: \(error)")
                        return nil
                    }
                } catch {
                    print("Failed to create server: \(error)")
                    return nil
                }
            } while true
            
        }
    }
    
    private static func setupTestRoutes(on server: LittleWebServer) {
        enum SharePathError: Swift.Error, CustomStringConvertible {
            
            case objectAlreadyExists(Int)
            
            public var description: String {
                switch self {
                    case .objectAlreadyExists(let id): return "Object with id '\(id)' already exists"
                }
            }
        }
        func errorResponse(_ event: LittleWebServer.ObjectSharing.ErrorResponseEvent,
                           _ error: Swift.Error) -> ServerAPIError {
            return ServerAPIError(id: -1, message: "\(error)")
        }
        func notFoundResponse(_ request: LittleWebServer.HTTP.Request,
                              _ stringId: String,
                              _ objectId: Int?) -> ServerAPIError {
            return ServerAPIError(id: -404, message: "Object with ID '\(stringId)' not found")
        }
        func notFoundResponse(_ stringId: String,
                              _ objectId: Int?) -> ServerAPIError {
            return ServerAPIError(id: -404, message: "Object with ID '\(stringId)' not found")
        }
        // Test root response
        server.defaultHost["/"] = { (request: LittleWebServer.HTTP.Request) -> LittleWebServer.HTTP.Response in
            return .ok(body: .html(LittleWebServerTests.serverRootIndexHTML))
        }
        
        // Test sending json events
        server.defaultHost["/events"] = { (request: LittleWebServer.HTTP.Request) -> LittleWebServer.HTTP.Response in
            
            func eventWriter(_ input: LittleWebServerInputStream, _ output: LittleWebServerOutputStream) {
                var count: Int = 1
                while server.isRunning && count < 100 {
                    let eventData = "{ \"event_type\": \"system\", \"event_count\": \(count), \"event_up\": true }\n"
                    count += 1
                    //let dta = eventData.data(using: .utf8)!
                    
                    do {
                        try output.write(eventData.data(using: .utf8)!)
                        
                        print("Sent event: \(count - 1)")
                    } catch {
                        if output.isConnected {
                            XCTFail("OH NO: \(error)")
                        }
                        break
                    }
                    Thread.sleep(forTimeInterval: 1)
                }
            }
            
            return .ok(body: .custom(eventWriter))
        }
        
        // Share readonly encodable object
        server.defaultHost["/status"] = LittleWebServer.ObjectSharing.shareObject(encoder: self.encoder,
                                                                                  object: self.serverDetails,
                                                                                  errorResponse: errorResponse)
        
        
        
        server.defaultHost["/object"] = LittleWebServer.ObjectSharing.shareObject(encoder: self.encoder,
                                                                                  decoder: self.decoder,
                                                                                  object: &self.modifiableObject,
                                                                                  errorResponse: errorResponse)
        
        server.defaultHost["/objects"] = LittleWebServer.ObjectSharing.sharePathObjects(encoder: self.encoder,
                                                                                        decoder: self.decoder,
                                                                                        objects: &self.modifiableList,
                                                                                        objectExistError: { id in
                                                                                            return SharePathError.objectAlreadyExists(id)
                                                                                        },
                                                                                        objectSorter: <,
                                                                                        notFoundResponse: notFoundResponse,
                                                                                        errorResponse: errorResponse)
        
        server.defaultHost["/sub"] = { (request: LittleWebServer.HTTP.Request) -> LittleWebServer.HTTP.Response in
            return .ok(body: .html(
            """
            <html>
            <head><title>Welcome to the Sub</title></head>
            <body>
            <center><h1>Welcome to the Sub</h1></center>
            </body>
            </html>
            """
            ))
        }
        
        server.defaultHost["/stop"] = { (request: LittleWebServer.HTTP.Request) -> LittleWebServer.HTTP.Response in
            DispatchQueue.global().async {
                LittleWebServerTests.server?.stop()
            }
            return .ok(body: .html(
            """
            <html>
            <head><title>Stopping Server</title></head>
            <body>
            <center><h1>Shutting down Server</h1></center>
            </body>
            </html>
            """
            ))
        }
        
        // Test basic path response
        server.defaultHost["/path/staticfile.html"] = { (request: LittleWebServer.HTTP.Request) -> LittleWebServer.HTTP.Response in
            return .ok(body: .html(LittleWebServerTests.testIndexHTML))
        }
        
        // Test anything hereafter path
        server.defaultHost["/path/anythingAfter/:path{**}"] = { (request: LittleWebServer.HTTP.Request) -> LittleWebServer.HTTP.Response in
            guard let path = request.identities["path"] else {
                return .internalError(body: .html("""
                <html>
                <head><title>Internal Error</title></head>
                <body>
                <center><h1>Unable to find path identifier</h1></center>
                </body>
                </html>
                """
                ))
            }
            
            
            
            let html = """
                       <html>
                       <head><title>Shared Path</title></head>
                       <body>
                       <center><h1>Current Shared Path is '\(path)'</h1></center>
                       </body>
                       </html>
                       """
            return .ok(body: .html(html))
        }
        
        // Test basic response wihting an anthing hereafter path
        server.defaultHost["/path/anythingAfter/staticfile.html"] = { (request: LittleWebServer.HTTP.Request) -> LittleWebServer.HTTP.Response in
            return .ok(body: .html(LittleWebServerTests.testIndexHTML))
        }
        
        // Test form upload
        server.defaultHost["/path/upload"] = { (request: LittleWebServer.HTTP.Request) -> LittleWebServer.HTTP.Response in
            
            var html = """
                       <html>
                       <head><title>Upload File</title></head>
                       <body>
                       <center><h1>Upload File</h1></center>
                       <form method="post">
                       <input name="uploadedFile" type="file"/><br/>
                       <input type="submit" value="Upload"/>
                       </form>
                       
                       """
            for file in request.uploadedFiles {
                html += "<center><h2>" + file.path + "</h2></center>\n"
                if let dta = try? Data(contentsOf: file.location),
                   let str = String(data: dta, encoding: .ascii) {
                    html += "<div>\(str)</div>\n"
                } else {
                    html += "<div>Error: Unable to load file content</div>\n"
                }
            }
            
            html += """
                    </body>
                    </html>
                    """
            return .ok(body: .html(html))
        }
        
        let speedLimiter: LittleWebServer.FileTransferSpeedLimiter = .unlimited
        // Test share location
        server.defaultHost["/path/public/"] = LittleWebServer.FSSharing.share(resource: self.testsURL,
                                                                                                speedLimiter: speedLimiter)
        
        server.defaultHost["/socket"] = LittleWebServer.WebSocket.endpoint { client, event in
            switch event {
                case .connected:
                    print("[Server]: Client Connected")
                case .disconnected:
                    print("[Server]: Client Disconnected")
                case .binary(let b):
                    do {
                        try client.writeBinary(b)
                    } catch {
                        XCTFail("Unable to write response binary")
                        try? client.writeClose()
                    }
                case .text(let txt):
                    do {
                        try client.writeText(txt)
                    } catch {
                        XCTFail("Unable to write response text")
                        try? client.writeClose()
                    }
                default:
                    break
            }
        }
    }
    
    
    private func cleanUpUploadedFiles(_ uploadedFiles:  [LittleWebServer.HTTP.Request.UploadedFileReference]) {
        for f in uploadedFiles {
            try? FileManager.default.removeItem(at: f.location)
        }
    }
    
    func testParseGetRequests() {
        
        let headString: String = "GET /?param1=1&param2=Test%20Spaces&param3=1&param3=2&param3=3 HTTP/1.1\r\nHost: localhost:59528\r\nUpgrade-Insecure-Requests: 1\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\nUser-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15\r\nAccept-Language: en-ca\r\nAccept-Encoding: gzip, deflate\r\nConnection: keep-alive\r\n\r\n"
        if self.isXcodeTesting {
            print("String:")
            print(headString)
        }
        
        let client = DataWebServerClient(headString)!
        
        
        var uploadedFiles: [LittleWebServer.HTTP.Request.UploadedFileReference] = []
        defer {
            cleanUpUploadedFiles(uploadedFiles)
        }
            
        guard let request = XCTAssertsNoThrow(try LittleWebServer.HTTP.Request.parse(from: client,
                                                                                     uploadedFiles: &uploadedFiles))  else {
            return
        }
        
        XCTAssertEqual(request.contextPath, "/")
        XCTAssertEqual(request.version, .v1_1)
        XCTAssertEqual(request.headers.host, "localhost:59528")
        XCTAssertEqual(request.headers.host?.name, "localhost")
        XCTAssertEqual(request.headers.host?.port, 59528)
        XCTAssertEqual(request.headers.connection, .keepAlive)
        
        if let acceptLanguages = request.headers.acceptLanguages {
            XCTAssertTrue(acceptLanguages.contains(where: { return $0 == "en-ca" }),
                          "Accept Languages '\(acceptLanguages)' does not contain 'en-ca'")
            XCTAssertTrue(acceptLanguages.contains(where: { return $0 ~= "en" }),
                          "Accept Languages '\(acceptLanguages)' does not contain 'en'")
            XCTAssertTrue(acceptLanguages.first?.locale != nil)
        } else {
            XCTFail("Missing Accept Languages")
        }
        if let acceptEncodings = request.headers.acceptEncodings {
            XCTAssertTrue(acceptEncodings.contains(.gzip),
                          "Accept Encodings '\(acceptEncodings)' does not contain 'gzip'")
            XCTAssertTrue(acceptEncodings.contains(.deflate),
                          "Accept Encodings '\(acceptEncodings)' does not contain 'deflate'")
        } else {
            XCTFail("Missing Accept Encodings")
        }
        
        XCTAssertEqual(request.queryParameter(for: "param1"), "1")
        XCTAssertEqual(request.queryParameter(for: "param2"), "Test Spaces")
        XCTAssertEqual(request.queryParameter(for: "param3"), "1")
        XCTAssertEqual(request.queryParameters(for: "param3"), ["1","2","3"])
    }
    
    
    
    func testParsePostFormURLEncodingRequests() {
        let postBody: String = "param4=true&param5=Test+Spaces"
        let headString: String = "POST /?param1=1&param2=Test%20Spaces&param3=1&param3=2&param3=3 HTTP/1.1\r\nHost: localhost:59528\r\nUpgrade-Insecure-Requests: 1\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\nUser-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15\r\nAccept-Language: en-ca\r\nAccept-Encoding: gzip, deflate\r\nConnection: keep-alive\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: \(postBody.utf8.count)\r\n\r\n\(postBody)\r\n\r\n"
        if self.isXcodeTesting {
            print("String:")
            print(headString)
        }
        
        let client = DataWebServerClient(headString)!
        
        var uploadedFiles: [LittleWebServer.HTTP.Request.UploadedFileReference] = []
        defer {
            cleanUpUploadedFiles(uploadedFiles)
        }
            
        guard let request = XCTAssertsNoThrow(try LittleWebServer.HTTP.Request.parse(from: client,
                                                                                     uploadedFiles: &uploadedFiles))  else {
            return
        }
        
        XCTAssertEqual(request.contextPath, "/")
        XCTAssertEqual(request.version, .v1_1)
        XCTAssertEqual(request.headers.host, "localhost:59528")
        XCTAssertEqual(request.headers.host?.name, "localhost")
        XCTAssertEqual(request.headers.host?.port, 59528)
        XCTAssertEqual(request.headers.connection, .keepAlive)
        if let acceptLanguages = request.headers.acceptLanguages {
            XCTAssertTrue(acceptLanguages.contains(where: { return $0 == "en-ca" }),
                          "Accept Languages '\(acceptLanguages)' does not contain 'en-ca'")
            XCTAssertTrue(acceptLanguages.contains(where: { return $0 ~= "en" }),
                          "Accept Languages '\(acceptLanguages)' does not contain 'en'")
            XCTAssertTrue(acceptLanguages.first?.locale != nil)
        } else {
            XCTFail("Missing Accept Languages")
        }
        if let acceptEncodings = request.headers.acceptEncodings {
            XCTAssertTrue(acceptEncodings.contains(.gzip),
                          "Accept Encodings '\(acceptEncodings)' does not contain 'gzip'")
            XCTAssertTrue(acceptEncodings.contains(.deflate),
                          "Accept Encodings '\(acceptEncodings)' does not contain 'deflate'")
        } else {
            XCTFail("Missing Accept Encodings")
        }
        
        XCTAssertEqual(request.queryParameter(for: "param1"), "1")
        XCTAssertEqual(request.queryParameter(for: "param2"), "Test Spaces")
        XCTAssertEqual(request.queryParameter(for: "param3"), "1")
        XCTAssertEqual(request.queryParameters(for: "param3"), ["1","2","3"])
        XCTAssertEqual(request.queryParameter(for: "param4"), "true")
        XCTAssertEqual(request.queryParameter(for: "param5"), "Test Spaces")
    }
    
    public func testParsePostFormURLEncodingRequestsRepeated() {
        let postBody: String = "param4=true&param5=Test+Spaces"
        let headString: String = "POST /?param1=1&param2=Test%20Spaces&param3=1&param3=2&param3=3 HTTP/1.1\r\nHost: localhost:59528\r\nUpgrade-Insecure-Requests: 1\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\nUser-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15\r\nAccept-Language: en-ca\r\nAccept-Encoding: gzip, deflate\r\nConnection: keep-alive\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: \(postBody.utf8.count)\r\n\r\n\(postBody)\r\n\r\n"
        if self.isXcodeTesting {
            print("String:")
            print(headString)
        }
        
        let client = DataWebServerClient(headString)!
        
        var doStop: Bool = false
        var loopSize = 1000
        if self.isXcodeTesting {
            loopSize = 100000
        }
        for _ in 0..<loopSize where !doStop {
            client.currentReadIndex = 0
            try! autoreleasepool {
                var uploadedFiles: [LittleWebServer.HTTP.Request.UploadedFileReference] = []
                defer {
                    cleanUpUploadedFiles(uploadedFiles)
                }
                if nil == XCTAssertsNoThrow(try LittleWebServer.HTTP.Request.parse(from: client,
                                                                                   uploadedFiles: &uploadedFiles)) {
                    XCTFail("Failed to parse request")
                    doStop = true
                    return
                }
            }
        }
    }
    
    public func testParsePostFormURLEncodingRequestsMeasured() {
        let postBody: String = "param4=true&param5=Test+Spaces"
        let headString: String = "POST /?param1=1&param2=Test%20Spaces&param3=1&param3=2&param3=3 HTTP/1.1\r\nHost: localhost:59528\r\nUpgrade-Insecure-Requests: 1\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\nUser-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15\r\nAccept-Language: en-ca\r\nAccept-Encoding: gzip, deflate\r\nConnection: keep-alive\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: \(postBody.utf8.count)\r\n\r\n\(postBody)\r\n\r\n"
        if self.isXcodeTesting {
            print("String:")
            print(headString)
        }
        
        let client = DataWebServerClient(headString)!
        
        measure {
            client.currentReadIndex = 0
            try! autoreleasepool {
                var uploadedFiles: [LittleWebServer.HTTP.Request.UploadedFileReference] = []
                defer {
                    cleanUpUploadedFiles(uploadedFiles)
                }
                if nil == XCTAssertsNoThrow(try LittleWebServer.HTTP.Request.parse(from: client,
                                                                                   uploadedFiles: &uploadedFiles)) {
                    XCTFail("Failed to parse request")
                    self.stopMeasuring()
                    return
                }
            }
        }
    }
    
    func testBasicFiles() {
        guard let server = LittleWebServerTests.getServer() else {
            XCTFail("Unable to get server")
            return
        }
        
        var urlBase = (server.listeners[0] as! LittleWebServerTCPIPListener).url
        if urlBase.host == "0.0.0.0" {
            var urlString = urlBase.absoluteString
            urlString = urlString.replacingOccurrences(of: "0.0.0.0", with: "127.0.0.1")
            urlBase = URL(string: urlString)!
        }
        
        let session = URLSession(configuration: URLSessionConfiguration.default)
        
        let semaphore = DispatchSemaphore(value: 0)
        // Test Root Path
        var task = session.dataTask(with: urlBase) { data, response, error in
            defer { semaphore.signal() }
            guard let dta = data else {
                var msg = "Unable to retrive response from '\(urlBase.absoluteString)'"
                if let err = error {
                    msg += "\nWith the following Error: \(err)"
                }
                XCTFail(msg)
                return
            }
            guard let stringContent = String(data: dta, encoding: .utf8) else {
                XCTFail("Unable to convert resposne from '\(urlBase)' to string")
                return
            }
            
            XCTAssertEqual(stringContent, LittleWebServerTests.serverRootIndexHTMLCRLF)
        }
        task.resume()
        semaphore.wait()
        
        // Test basic path
        let basicFileURL = urlBase.appendingPathComponent("path")
                                  .appendingPathComponent("staticfile.html")
        task = session.dataTask(with: basicFileURL) { data, response, error in
            defer { semaphore.signal() }
            guard let dta = data else {
                var msg = "Unable to retrive response from '\(basicFileURL.absoluteString)'"
                if let err = error {
                    msg += "\nWith the following Error: \(err)"
                }
                XCTFail(msg)
                return
            }
            guard let stringContent = String(data: dta, encoding: .utf8) else {
                XCTFail("Unable to convert resposne from '\(basicFileURL)' to string")
                return
            }
            
            XCTAssertEqual(stringContent, LittleWebServerTests.testIndexHTMLCRLF)
        }
        task.resume()
        semaphore.wait()
        
        
        // Test basic path
        let anythingHereafterStaticFile = urlBase.appendingPathComponent("path")
                                                 .appendingPathComponent("anythingAfter")
                                                 .appendingPathComponent("staticfile.html")
        task = session.dataTask(with: anythingHereafterStaticFile) { data, response, error in
            defer { semaphore.signal() }
            guard let dta = data else {
                var msg = "Unable to retrive response from '\(anythingHereafterStaticFile)'"
                if let err = error {
                    msg += "\nWith the following Error: \(err)"
                }
                XCTFail(msg)
                return
            }
            guard let stringContent = String(data: dta, encoding: .utf8) else {
                XCTFail("Unable to convert resposne from '\(anythingHereafterStaticFile)' to string")
                return
            }
            
            XCTAssertEqual(stringContent, LittleWebServerTests.testIndexHTMLCRLF)
        }
        task.resume()
        semaphore.wait()
    }
    
    
    
    func testBrowseSharedFolder() {
        
        func testFile(session: URLSession, realLocation: URL, webLocation: URL) {
            let semaphore = DispatchSemaphore(value: 0)
            // Test Root Path
            var request = URLRequest(url: webLocation)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let task = session.dataTask(with: request) { data, response, error in
                defer { semaphore.signal() }
                guard let dta = data else {
                    var msg = "Unable to retrive response from '\(webLocation)'"
                    if let err = error {
                        msg += "\nWith the following Error: \(err)"
                    }
                    XCTFail(msg)
                    return
                }
                
                let responseStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                
                guard XCTAssertsEqual(responseStatusCode, 200,
                                      "'\(webLocation.absoluteString)' did not return a 200. Intead returned \(responseStatusCode)") else {
                    return
                }
                
                do {
                    let fileData = try Data(contentsOf: realLocation)
                
                    XCTAssertEqual(dta, fileData,
                                   "Content of '\(webLocation.absoluteString)' does not equal '\(realLocation.path)'")
                } catch {
                    XCTFail("Failed to read local file '\(realLocation.path)': \(error)")
                }
                
                
            }
            task.resume()
            semaphore.wait()
        }
        func browseFolder(session: URLSession, realLocation: URL, webLocation: URL) {
            do {
                let contents = (try FileManager.default.contentsOfDirectory(atPath: realLocation.path)).map({ return realLocation.appendingPathComponent($0) })
                
                
                let semaphore = DispatchSemaphore(value: 0)
                // Test Root Path
                var request = URLRequest(url: webLocation)
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                let task = session.dataTask(with: request) { data, response, error in
                    defer { semaphore.signal() }
                    guard let dta = data else {
                        var msg = "Unable to retrive response from '\(webLocation)'"
                        if let err = error {
                            msg += "\nWith the following Error: \(err)"
                        }
                        XCTFail(msg)
                        return
                    }
                    guard let stringContent = String(data: dta, encoding: .utf8) else {
                        XCTFail("Unable to convert resposne from '\(webLocation)' to string")
                        return
                    }
                    
                    for resource in contents {
                        XCTAssertTrue(stringContent.contains(resource.lastPathComponent),
                                      "Could not find reference to '\(resource.lastPathComponent)' in '\(webLocation)'")
                    }
                }
                task.resume()
                semaphore.wait()
                
                for resource in contents {
                    var isDir: Bool = false
                    _ = FileManager.default.fileExists(atPath: resource.path,
                                                       isDirectory: &isDir)
                    
                    if isDir {
                        browseFolder(session: session,
                                     realLocation: resource,
                                     webLocation: webLocation.appendingPathComponent(resource.lastPathComponent))
                    } else {
                        testFile(session: session,
                                 realLocation: resource,
                                 webLocation: webLocation.appendingPathComponent(resource.lastPathComponent))
                    }
                }
            } catch {
                XCTFail("Unable to retrieve contents of location '\(realLocation.path)': \(error)")
            }
        }
        
        guard let server = LittleWebServerTests.getServer() else {
            XCTFail("Unable to get server")
            return
        }
        
        var urlBase = (server.listeners[0] as! LittleWebServerTCPIPListener).url
        if urlBase.host == "0.0.0.0" {
            var urlString = urlBase.absoluteString
            urlString = urlString.replacingOccurrences(of: "0.0.0.0", with: "127.0.0.1")
            urlBase = URL(string: urlString)!
        }
        
        let webRoot = urlBase.appendingPathComponent("path").appendingPathComponent("public")
        let session = URLSession(configuration: URLSessionConfiguration.default)
        
        
        browseFolder(session: session, realLocation: self.testsURL, webLocation: webRoot)
        
    }
    
    
    func testWebSocket() {
        #if _runtime(_ObjC)
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
            guard let server = LittleWebServerTests.getServer() else {
                XCTFail("Unable to get server")
                return
            }
            
            var urlBase = (server.listeners[0] as! LittleWebServerTCPIPListener).url
            if urlBase.host == "0.0.0.0" {
                var urlString = urlBase.absoluteString
                urlString = urlString.replacingOccurrences(of: "http", with: "ws")
                urlString = urlString.replacingOccurrences(of: "0.0.0.0", with: "127.0.0.1")
                urlBase = URL(string: urlString)!
            }
            
            let session = URLSession(configuration: URLSessionConfiguration.default)
        
            
            let wsURL = urlBase.appendingPathComponent("socket")
            print("[Client]: Connecting to '\(wsURL.absoluteString)'")
            let webSocket = session.webSocketTask(with: wsURL)
            webSocket.resume()
            
            let bindaryData = Data([1, 3, 5, 7, 9, 11, 13])
            let textData = "Hellow World"
            
            
            if true {
                let waitMessageSemaphore = DispatchSemaphore(value: 0)
                
                print("[Client]: Sending Binary Data")
                    
                webSocket.send(.data(bindaryData)) { err in
                    defer { waitMessageSemaphore.signal() }
                    if let e = err {
                        self.print("\(webSocket.closeCode): \(webSocket.closeCode.rawValue)")
                        XCTFail("[Client]: Binary message returned error: \(e)")
                    }
                }
                
                waitMessageSemaphore.wait()
                print("[Client]: Sent Binary Data")
            }
            if true {
                let waitMessageSemaphore = DispatchSemaphore(value: 0)
                print("[Client]: Waiting For Binary Data Response")
                webSocket.receive { results in
                    defer { waitMessageSemaphore.signal() }
                    do {
                        let s = try results.get()
                        guard case .data(let dta) = s else {
                            XCTFail("[Client]: Unexpected web socket event \(s)")
                            return
                        }
                        
                        if XCTAssertsEqual(dta, bindaryData) {
                            self.print("[Client]: Received Binary data")
                        }
                        
                    } catch {
                        self.print("\(webSocket.closeCode): \(webSocket.closeCode.rawValue)")
                        XCTFail("[Client]: Websocket Receive Error: \(error)")
                    }
                }
                
                waitMessageSemaphore.wait()
            }
            
            if true {
                let waitMessageSemaphore = DispatchSemaphore(value: 0)
                print("[Client]: Sending Ping")
                webSocket.sendPing { err in
                    defer { waitMessageSemaphore.signal() }
                    if let e = err {
                        self.print("\(webSocket.closeCode): \(webSocket.closeCode.rawValue)")
                        XCTFail("[Client]: Ping message returned error: \(e)")
                    }
                }
                
                waitMessageSemaphore.wait()
                print("[Client]: Sent Ping")
            }
            
            if true {
                let waitMessageSemaphore = DispatchSemaphore(value: 0)
                print("[Client]: Sending Text Data")
                webSocket.send(.string(textData)) { err in
                    defer { waitMessageSemaphore.signal() }
                    if let e = err {
                        self.print("\(webSocket.closeCode): \(webSocket.closeCode.rawValue)")
                        XCTFail("[Client]: Text message returned error: \(e)")
                    }
                    
                }
                waitMessageSemaphore.wait()
                print("[Client]: Sent Text Data")
            }
            
            if true {
                let waitMessageSemaphore = DispatchSemaphore(value: 0)
                print("[Client]: Waiting For Text Data Response")
                webSocket.receive { results in
                    defer { waitMessageSemaphore.signal() }
                    do {
                        let s = try results.get()
                        guard case .string(let txt) = s else {
                            XCTFail("[Client]: Unexpected web socket event \(s)")
                            return
                        }
                        
                        if XCTAssertsEqual(txt, textData) {
                            self.print("[Client]: Received Text Response")
                        }
                        
                    } catch {
                        self.print("\(webSocket.closeCode): \(webSocket.closeCode.rawValue)")
                        XCTFail("[Client]: Websocket Receive Error: \(error)")
                    }
                }
                
                waitMessageSemaphore.wait()
            }
            
            //waitAllSemaphore.wait()
            print("[Client]: Closing Connection")
            webSocket.cancel(with: .normalClosure, reason: Data([1,2,3,4]))
            
            
            print(webSocket.closeCode.rawValue)
            print(webSocket.closeReason)
            
        } else {
            print("WARNING: testWebSocket Unavailable to test due to no client support on the current platform")
        }
        #else
        print("WARNING: testWebSocket Unavailable to test due to no client support on the current platform")
        #endif
        
    }
    
    
    private func downloadObject<T>(objectType: T.Type,
                                   at address: URL,
                                   using session: URLSession,
                                   file: StaticString,
                                   line: UInt) -> T? where T: Decodable {
        
        let decoder = JSONDecoder()
        
        var rtn: T? = nil
        let waitSemaphore = DispatchSemaphore(value: 0)
        let task = session.dataTask(with: address) { (dta, resp, err) -> Void in
            
            defer { waitSemaphore.signal() }
            
            guard err == nil else {
                XCTFail("Received Error: \(err!)", file: file, line: line)
                return
            }
            
            guard let data = dta else {
                XCTFail("No data returned for object", file: file, line: line)
                return
            }
            do {
                // do catch should not be required because XCTAssertsNoThrow does not throw
                // but there seems to be some compile bug that requires it since we are
                // in a closure
                rtn = XCTAssertsNoThrow(try decoder.decode(T.self, from: data),
                                        "Unable to decode object of type '\(T.self)'",
                                        file: file,
                                        line: line)
                
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        
        task.resume()
        waitSemaphore.wait()
        
        return rtn
    }
    
    #if swift(>=5.3)
    private func downloadObject<T>(_ objectType: T.Type,
                                   at url: URL,
                                   using session: URLSession,
                                   file: StaticString = #filePath,
                                   line: UInt = #line) -> T? where T: Decodable {
        return self.downloadObject(objectType: objectType,
                                   at: url,
                                   using: session,
                                   file: file,
                                   line: line)
    }
    #else
    private func downloadObject<T>(_ objectType: T.Type,
                                   at url: URL,
                                   using session: URLSession,
                                   file: StaticString = #file,
                                   line: UInt = #line) -> T? where T: Decodable {
        return self.downloadObject(objectType: objectType,
                                   at: url,
                                   using: session,
                                   file: file,
                                   line: line)
    }
    #endif
    
    private func uploadData(data bodyData: Data,
                            at url: URL,
                            method: String,
                            using session: URLSession,
                            file: StaticString,
                            line: UInt) -> (data: Data?,
                                                 response: URLResponse?,
                                                 error: Swift.Error?,
                                                 statusCode: Int)? {
       
        
        var data: Data? = nil
        var response: URLResponse? = nil
        var error: Swift.Error? = nil
        var statusCode: Int = 0
        
        var req = URLRequest(url: url)
        req.httpMethod = method
        if bodyData.count > 0 {
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = bodyData
        }
        
        let waitSemaphore = DispatchSemaphore(value: 0)
        let task = session.dataTask(with: req) { (dta, resp, err) -> Void in
            
            defer { waitSemaphore.signal() }
            
            guard err == nil else {
                var errBody: String = ""
                if let str = String(data: dta!, encoding: .utf8) {
                    errBody = str
                }
                var errMsg: String = "Received Error: \(err!)"
                if !errBody.isEmpty { errMsg += "\n" + errBody }
                XCTFail(errMsg,
                        file: file,
                        line: line)
                
                return
            }
            
            guard let r = resp else {
                XCTFail("No response object returned",
                        file: file,
                        line: line)
                return
            }
            
            guard let status = (r as? HTTPURLResponse)?.statusCode else {
                XCTFail("Response was not a HTTPURLResponse",
                        file: file,
                        line: line)
                return
            }
            
            data = dta
            response = resp
            error = err
            statusCode = status
        }
        
        task.resume()
        waitSemaphore.wait()
        
        return (data: data, response: response, error: error, statusCode: statusCode)
        
    }
    
    private func uploadDataNoContentReturn(data bodyData: Data,
                                           at url: URL,
                                           method: String,
                                           using session: URLSession,
                                           file: StaticString,
                                           line: UInt) -> (data: Data?,
                                                           response: URLResponse?,
                                                           error: Swift.Error?,
                                                           statusCode: Int)? {
        
        guard let rtn = self.uploadData(data: bodyData,
                                        at: url,
                                        method: method,
                                        using: session,
                                        file: file,
                                        line: line) else {
            return nil
        }
        
        
        
        guard rtn.data == nil || rtn.data!.count == 0 else {
            var strData: String = ""
            if let str = String(data: rtn.data!, encoding: .utf8) {
                strData = ":\nUnexpected String: '\(str)'"
            }
            XCTFail("Received unexpected body data\(strData)",
                    file: file,
                    line: line)
            return nil
        }
        
        return rtn
    }
    
    private func uploadObject<T>(object: T,
                                 at url: URL,
                                 method: String,
                                 using session: URLSession,
                                 file: StaticString,
                                 line: UInt) -> (data: Data?,
                                                 response: URLResponse?,
                                                 error: Swift.Error?,
                                                 statusCode: Int)? where T: Encodable {
        let encoder = JSONEncoder()
        
        guard let objectData = XCTAssertsNoThrow(try encoder.encode(object),
                                                 "Unable to encode objcet of type '\(T.self)'",
                                                 file: file,
                                                 line: line) else {
            return nil
        }
        /*
        return uploadDataNoContentReturn(data: objectData,
                                         at: url,
                                         method: method,
                                         using: session,
                                         file: file,
                                         line: line)
        */
        return uploadData(data: objectData,
                          at: url,
                          method: method,
                          using: session,
                          file: file,
                          line: line)
        
    }
    
    #if swift(>=5.3)
    private func uploadObject<T>(_ object: T,
                                 at url: URL,
                                 method: String = "POST",
                                 using session: URLSession,
                                 file: StaticString = #filePath,
                                 line: UInt = #line) -> (data: Data?,
                                                         response: URLResponse?,
                                                         error: Swift.Error?,
                                                         statusCode: Int)? where T: Encodable {
        return self.uploadObject(object: object,
                                 at: url,
                                 method: method,
                                 using: session,
                                 file: file,
                                 line: line)
    }
    #else
    private func uploadObject<T>(_ object: T,
                                 at url: URL,
                                 method: String = "POST",
                                 using session: URLSession,
                                 file: StaticString = #file,
                                 line: UInt = #line) -> (data: Data?,
                                                         response: URLResponse?,
                                                         error: Swift.Error?,
                                                         statusCode: Int)? where T: Encodable {
        return self.uploadObject(object: object,
                                 at: url,
                                 method: method,
                                 using: session,
                                 file: file,
                                 line: line)
    }
    #endif
    
    #if swift(>=5.3)
    private func deleteObject(at url: URL,
                              using session: URLSession,
                              file: StaticString = #filePath,
                              line: UInt = #line) -> (data: Data?,
                                                         response: URLResponse?,
                                                         error: Swift.Error?,
                                                         statusCode: Int)? {
        return self.uploadData(data: Data(),
                                 at: url,
                                 method: "DELETE",
                                 using: session,
                                 file: file,
                                 line: line)
    }
    #else
    private func deleteObject(at url: URL,
                              using session: URLSession,
                              file: StaticString = #file,
                              line: UInt = #line) -> (data: Data?,
                                                         response: URLResponse?,
                                                         error: Swift.Error?,
                                                         statusCode: Int)? {
        return self.uploadData(data: Data(),
                                 at: url,
                                 method: "DELETE",
                                 using: session,
                                 file: file,
                                 line: line)
    }
    #endif
    
    func testObjectAccessing() {
        guard let server = LittleWebServerTests.getServer() else {
            XCTFail("Unable to get server")
            return
        }
        
        var urlBase = (server.listeners[0] as! LittleWebServerTCPIPListener).url
        if urlBase.host == "0.0.0.0" {
            var urlString = urlBase.absoluteString
            urlString = urlString.replacingOccurrences(of: "0.0.0.0", with: "127.0.0.1")
            urlBase = URL(string: urlString)!
        }
        
        let session = URLSession(configuration: URLSessionConfiguration.default)
        
        
        
        // Get readonly object
        if let obj = downloadObject(ServerDetails.self,
                                    at: urlBase.appendingPathComponent("status"),
                                    using: session) {
            XCTAssertEqual(obj, LittleWebServerTests.serverDetails)
        } else {
            XCTFail("Unable to retrieve status")
        }
        
        // Get modifyable Object
        if let obj = downloadObject(ModifiableObject.self,
                                    at: urlBase.appendingPathComponent("object"),
                                    using: session) {
            XCTAssertEqual(obj, LittleWebServerTests.modifiableObject)
        } else {
            XCTFail("Unable to retrieve modifyable object")
        }
        
        // Updating Object
        let updatedModifiableObject = ModifiableObject(id: 2, description: "Updated Object")
        if let updated = uploadObject(updatedModifiableObject,
                                      at: urlBase.appendingPathComponent("object"),
                                      using: session) {
            
            guard XCTAssertsEqual(204, updated.statusCode) else {
                return
            }
            
            
            XCTAssertEqual(updatedModifiableObject, LittleWebServerTests.modifiableObject)
            
        } else {
            XCTFail("Failed to update modifiable object")
        }
        
        let objectsURL = urlBase.appendingPathComponent("objects")
        
        // Get object list
        if let obj = downloadObject([ModifiableObject].self,
                                    at: objectsURL,
                                    using: session) {
            XCTAssertEqual(obj, LittleWebServerTests.modifiableList)
        } else {
            XCTFail("Unable to retrieve modifyable object list")
        }
        
        
        // Add object to list
        let addId = (LittleWebServerTests.modifiableList.last?.id ?? 0) + 1
        
        let addObject = ModifiableObject(id: addId, description: "Added Object \(addId)")
        if let updated = uploadObject(addObject,
                                      at: objectsURL,
                                      method: "PUT",
                                      using: session) {
            
            guard XCTAssertsEqual(201, updated.statusCode) else {
                return
            }
            
            if !XCTAssertsTrue(LittleWebServerTests.modifiableList.contains(addObject)) {
                // We will stop here since there was a failure on the list
                return
            }
            
        } else {
            XCTFail("Failed to add modifiable object")
            // We will stop here since there was a failure on the list
            return
        }
        
        // Update last object in list
        let updateObject = ModifiableObject(id: LittleWebServerTests.modifiableList.last!.id,
                                            description: "Updated \(LittleWebServerTests.modifiableList.last!.id)")
        
        if let updated = uploadObject(updateObject,
                                      at: objectsURL.appendingPathComponent("\(updateObject.id)"),
                                      using: session) {
            
            
            guard XCTAssertsTrue([200, 204].contains(updated.statusCode)) else {
                return
            }
            
            //print(LittleWebServerTests.modifiableList)
            
            if !XCTAssertsTrue(LittleWebServerTests.modifiableList.contains(where: {
                return $0.id == updateObject.id &&
                       $0.description == updateObject.description
            })) {
                // We will stop here since there was a failure on the list
                return
            }
            
        } else {
            XCTFail("Failed to update modifiable object in list")
            // We will stop here since there was a failure on the list
            return
        }
        
        // Get specific object in list
        if let obj = downloadObject(ModifiableObject.self,
                                    at: objectsURL.appendingPathComponent("\(updateObject.id)"),
                                    using: session) {
            XCTAssertEqual(obj.id, updateObject.id)
            XCTAssertEqual(obj.description, updateObject.description)
        } else {
            XCTFail("Unable to retrieve modifyable object from list")
        }
        
        // Delete specific object from list
        guard let deleted = deleteObject(at: objectsURL.appendingPathComponent("\(updateObject.id)"),
                                         using: session) else {
            XCTFail("Unable to delete modifyable object from list")
            return
        }
        
        guard XCTAssertsEqual(204, deleted.statusCode) else {
            return
        }
        
        XCTAssertTrue(!LittleWebServerTests.modifiableList.contains(updateObject))
        
        
        //asdfasdfasdf
    }
    
    func testCustomResponse() {
        
        class DataTaskDelegate: NSObject, URLSessionDataDelegate {
            private var receivedDataFlag: UnsafeMutablePointer<Bool>
            public init(_ receivedDataFlag: UnsafeMutablePointer<Bool>) {
                self.receivedDataFlag = receivedDataFlag
                super.init()
            }
            func urlSession(_ session: URLSession,
                            dataTask: URLSessionDataTask,
                            didReceive data: Data) {
                self.receivedDataFlag.pointee = true
                guard let str = String(data: data, encoding: .utf8) else {
                    XCTFail("Unable to convert data into string")
                    return
                }
                Swift.print(str)
            }
        }
        guard let server = LittleWebServerTests.getServer() else {
            XCTFail("Unable to get server")
            return
        }
        
        var urlBase = (server.listeners[0] as! LittleWebServerTCPIPListener).url
        if urlBase.host == "0.0.0.0" {
            var urlString = urlBase.absoluteString
            urlString = urlString.replacingOccurrences(of: "0.0.0.0", with: "127.0.0.1")
            urlBase = URL(string: urlString)!
        }
        var didReceiveData: Bool = false
        let delegate = DataTaskDelegate(&didReceiveData)
        let session = URLSession(configuration: URLSessionConfiguration.default,
                                 delegate: delegate,
                                 delegateQueue: nil)
        
        let eventRequest = URLRequest(url: urlBase.appendingPathComponent("events"),
                                      cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                      timeoutInterval: .infinity)
        
        let task = session.dataTask(with: eventRequest)
        task.resume()
        
        // We wait to allow streaming to occur
        Thread.sleep(forTimeInterval: 20)
        if task.state == .running {
            // Lets stop the task if its still running
            task.cancel()
        }
        
        XCTAssertTrue(didReceiveData, "Did not receive any data from stream")
        
    }
    
    func testParallelRequests() {
        let operations = OperationQueue()
        // pause all operaions
        operations.isSuspended = true
        
        guard let server = LittleWebServerTests.getServer() else {
            XCTFail("Unable to get server")
            return
        }
        
        var urlBase = (server.listeners[0] as! LittleWebServerTCPIPListener).url
        if urlBase.host == "0.0.0.0" {
            var urlString = urlBase.absoluteString
            urlString = urlString.replacingOccurrences(of: "0.0.0.0", with: "127.0.0.1")
            urlBase = URL(string: urlString)!
        }
        let webLocation = urlBase.appendingPathComponent("status")
        let parallelCount: Int = 5
        var taskCompleted: [Bool] = [Bool](repeating: false, count: parallelCount)
        for i in 0..<parallelCount {
            operations.addOperation {
                let session = URLSession(configuration: URLSessionConfiguration.default)
                
                let semaphore = DispatchSemaphore(value: 0)
                Swift.print("[\(i)](\(webLocation.absoluteString)): Starting Request")
                let task = session.dataTask(with: webLocation) { data, response, error in
                    defer {
                        Swift.print("[\(i)](\(webLocation.absoluteString)): Finished Request")
                        semaphore.signal()
                        taskCompleted[i] = true
                    }
                    if let e =  error {
                        XCTFail("[\(i)](\(webLocation.absoluteString)): Request Failed with the following error: \(e)")
                    }
                    guard let d = data else {
                        XCTFail("[\(i)](\(webLocation.absoluteString)): Request Failed. No data returned")
                        return
                    }
                    guard d.count > 0 else {
                        XCTFail("[\(i)](\(webLocation.absoluteString)): Request Failed. Data reutrned 0 bytes")
                        return
                    }
                    
                }
                
                task.resume()
                semaphore.wait()
            }
        }
        
        // start operations
        operations.maxConcurrentOperationCount = parallelCount
        operations.isSuspended = false
        
        
        // We wait until all tasks have returned
        while !(taskCompleted.allSatisfy({ return $0 == true })) {
            Thread.sleep(forTimeInterval: 1)
        }
        
        
    }
    
    func testMultiRequestConnection() {
        guard let server = LittleWebServerTests.getServer() else {
            XCTFail("Unable to get server")
            return
        }
        
        var urlBase = (server.listeners[0] as! LittleWebServerTCPIPListener).url
        if urlBase.host == "0.0.0.0" {
            var urlString = urlBase.absoluteString
            urlString = urlString.replacingOccurrences(of: "0.0.0.0", with: "127.0.0.1")
            urlBase = URL(string: urlString)!
        }
        let webLocation = urlBase.appendingPathComponent("status")
        let session = URLSession(configuration: URLSessionConfiguration.default)
        
        for i in 0..<5 {
            let semaphore = DispatchSemaphore(value: 0)
            Swift.print("[\(i)](\(webLocation.absoluteString)): Starting Request")
            let task = session.dataTask(with: webLocation) { data, response, error in
                defer {
                    Swift.print("[\(i)](\(webLocation.absoluteString)): Finished Request")
                    semaphore.signal()
                }
                if let e =  error {
                    XCTFail("[\(i)](\(webLocation.absoluteString)): Request Failed with the following error: \(e)")
                }
                guard let d = data else {
                    XCTFail("[\(i)](\(webLocation.absoluteString)): Request Failed. No data returned")
                    return
                }
                guard d.count > 0 else {
                    XCTFail("[\(i)](\(webLocation.absoluteString)): Request Failed. Data reutrned 0 bytes")
                    return
                }
                
            }
            
            task.resume()
            semaphore.wait()
        }
    }
    
    
    func testAddressValues() {
        // Test IP's
        let ip4LoopBack = LittleWebServerSocketConnection.Address.IP.ipV4Loopback
        XCTAssertEqual(ip4LoopBack.node, "127.0.0.1")
        
        let ip4Any = LittleWebServerSocketConnection.Address.IP.anyIPv4
        XCTAssertEqual(ip4Any.node, "0.0.0.0")
        
        let ip6LoopBack = LittleWebServerSocketConnection.Address.IP.ipV6Loopback
        XCTAssertEqual(ip6LoopBack.node, "::1")
        
        let ip6Any = LittleWebServerSocketConnection.Address.IP.anyIPv6
        XCTAssertEqual(ip6Any.node, "::")
        
        
        // Test Addresses
        let unixPath: String = "/var/etc/docker.sock"
        let unixAddress = try!LittleWebServerSocketConnection.Address.init("unix://\(unixPath)")
        XCTAssertEqual(unixAddress.description, "unix://\(unixPath)")
        XCTAssertEqual(unixAddress.unixPath, unixPath)
        
        let ip4AddressWithPort: LittleWebServerSocketConnection.Address = "127.0.0.1:443"
        if XCTAssertsTrue(ip4AddressWithPort.ipAddress != nil) {
            XCTAssertEqual(ip4AddressWithPort.description, "127.0.0.1:443")
            XCTAssertEqual(ip4AddressWithPort.ipAddress!.node, "127.0.0.1")
            XCTAssertEqual(ip4AddressWithPort.tcpPort, 443)
        }
        
        let ip4AddressWithoutPort: LittleWebServerSocketConnection.Address = "127.0.0.1"
        if XCTAssertsTrue(ip4AddressWithoutPort.ipAddress != nil) {
            XCTAssertEqual(ip4AddressWithoutPort.description, "127.0.0.1")
            XCTAssertEqual(ip4AddressWithoutPort.ipAddress!.node, "127.0.0.1")
            XCTAssertEqual(ip4AddressWithoutPort.tcpPort, 0)
        }
        
        let ip6AddressWithPort: LittleWebServerSocketConnection.Address = "[2001:db8:85a3:0000:0000:8a2e:370:7334]:443"
        if XCTAssertsTrue(ip6AddressWithPort.ipAddress != nil) {
            XCTAssertEqual(ip6AddressWithPort.description, "[2001:db8:85a3::8a2e:370:7334]:443")
            XCTAssertEqual(ip6AddressWithPort.ipAddress!.node, "2001:db8:85a3::8a2e:370:7334")
            XCTAssertEqual(ip6AddressWithPort.tcpPort, 443)
        }
        let ip6AddressWithoutPort1: LittleWebServerSocketConnection.Address = "[2001:db8:85a3:0000:0000:8a2e:370:7334]"
        if XCTAssertsTrue(ip6AddressWithoutPort1.ipAddress != nil) {
            XCTAssertEqual(ip6AddressWithoutPort1.description, "2001:db8:85a3::8a2e:370:7334")
            XCTAssertEqual(ip6AddressWithoutPort1.ipAddress!.node, "2001:db8:85a3::8a2e:370:7334")
            XCTAssertEqual(ip6AddressWithoutPort1.tcpPort, 0)
        }
        let ip6AddressWithoutPort2: LittleWebServerSocketConnection.Address = "2001:db8:85a3:0000:0000:8a2e:370:7334"
        if XCTAssertsTrue(ip6AddressWithoutPort2.ipAddress != nil) {
            XCTAssertEqual(ip6AddressWithoutPort2.description, "2001:db8:85a3::8a2e:370:7334")
            XCTAssertEqual(ip6AddressWithoutPort2.ipAddress!.node, "2001:db8:85a3::8a2e:370:7334")
            XCTAssertEqual(ip6AddressWithoutPort2.tcpPort, 0)
        }
        
    }
    
    
    
    func testPathCondition() {
        let condition: LittleWebServerRoutePathConditions = "/path/public/:path{**}"
        print(condition)
        print(condition.count)
        print(condition.testPath("/path/public/"))
    }
    
    
    @discardableResult
    func validateRouteConditions(fullPath: String,
                                 route: LittleWebServerRoutePathConditions,
                                 pathRegCondition: String,
                                 pathTransformer: String,
                                 paramRegCondition: String,
                                 paramTransformer: String,
                                 file: StaticString,
                                 line: UInt = #line) -> Bool {
        
        let pathComponents = fullPath.split(separator: "/").map(String.init)
        guard pathComponents.count > 0 else {
            guard route.count == 1 else {
                XCTFail("Invalid Route Size",
                        file: file,
                        line: line)
                return false
            }
            guard route[0].pathCondition == .folder else {
                XCTFail("Invalid Route Path Condition '\(route[0].pathCondition)'",
                        file: file,
                        line: line)
                return false
            }
            guard route[0].identifier == nil else {
                XCTFail("Expected no Identifier.  Found '\(route[0].identifier!)'",
                        file: file,
                        line: line)
                return false
            }
            guard route[0].parameterConditions.count == 0 else {
                XCTFail("Expected no parameter conditions.  Found '\(route[0].parameterConditions)'",
                        file: file,
                        line: line)
                return false
            }
            
            return true
        }
        
        guard pathComponents.count == route.count else {
            XCTFail("Path component count and route condition count don't match.  \(pathComponents.count) != \(route.count)",
                    file: file,
                    line: line)
            return false
        }
        for i in 0..<pathComponents.count {
            let pthCmp = pathComponents[i]
            let cmp = route[i]
            
            if pthCmp.hasPrefix(":") {
                var strIdent = pthCmp
                strIdent.removeFirst()
                if let r = strIdent.range(of: "{") {
                    strIdent = String(strIdent[..<r.lowerBound])
                }
                if cmp.identifier != strIdent {
                    XCTFail("Invalid identifier. Expected: '\(pthCmp.dropFirst())', Found: '\(cmp.identifier ?? "nil")'.  Testing '\(pthCmp)'",
                            file: file,
                            line: line)
                    return false
                }
                
            } else if pthCmp == "**" {
                if cmp.pathCondition != .anythingHereafter {
                    XCTFail("Invalid path condition. Expected: '**', Found: '\(cmp.pathCondition)'.  Testing '\(pthCmp)'",
                            file: file,
                            line: line)
                    return false
                }
                
            } else if pthCmp == "*" {
                if cmp.pathCondition != .anything {
                    XCTFail("Invalid path condition. Expected: '*', Found: '\(cmp.pathCondition)'.  Testing '\(pthCmp)'",
                            file: file,
                            line: line)
                    return false
                }
            } else {
                var realPth = pthCmp
                if let r = realPth.range(of: "{") {
                    realPth = String(realPth[realPth.startIndex..<r.lowerBound])
                }
                if realPth.isEmpty {
                    
                    let containsRegEx = pthCmp.contains(pathRegCondition)
                    if !containsRegEx && cmp.pathCondition != .anything {
                        XCTFail("Invalid path condition. Expected: '*', Found: '\(cmp.pathCondition)'.  Testing '\(pthCmp)'",
                                file: file,
                                line: line)
                        return false
                    } else if containsRegEx && cmp.pathCondition.pattern?.singlePattern?.expressionString != pathRegCondition {
                        XCTFail("Invalid path condition. Expected: '\(pathRegCondition)', Found: '\(cmp.pathCondition)'.  Testing '\(pthCmp)'",
                                file: file,
                                line: line)
                        return false
                    }
                } else {
                    if realPth == "*" {
                        if !cmp.pathCondition.isAnything {
                            XCTFail("Invalid path condition. Expected: '\(realPth)', Found: \(cmp.pathCondition).  Testing '\(pthCmp)'",
                                    file: file,
                                    line: line)
                            return false
                        }
                    } else if realPth == "**" {
                        if !cmp.pathCondition.isAnythingHereafter {
                            XCTFail("Invalid path condition. Expected: '\(realPth)', Found: \(cmp.pathCondition).  Testing '\(pthCmp)'",
                                    file: file,
                                    line: line)
                            return false
                        }
                    } else {
                        if cmp.pathCondition.pattern?.singlePattern?.exactMatch != realPth {
                            XCTFail("Invalid path condition. Expected: '\(realPth)', Found: \(cmp.pathCondition).  Testing '\(pthCmp)'",
                                    file: file,
                                    line: line)
                            return false
                        }
                    }
                }
                
                //XCTFail("Need to implement")
            }
            
            if pthCmp.contains(pathRegCondition) &&
                cmp.pathCondition.pattern?.singlePattern?.expressionString != pathRegCondition {
                XCTFail("Invalid path condition. Expected: '\(pathRegCondition)', Found: \(cmp.pathCondition).  Testing '\(pthCmp)'",
                        file: file,
                        line: line)
                return false
            }
            
            if pthCmp.contains("<\(pathTransformer)>") &&
                cmp.transformation?.string != pathTransformer {
                XCTFail("Invalid path tranformer. Expected: '\(pathTransformer)', Found: \(cmp.transformation?.string ?? "nil").  Testing '\(pthCmp)'",
                        file: file,
                        line: line)
                return false
                
            }
            
            if pthCmp.contains("?") ||
                pthCmp.contains(paramRegCondition) ||
                pthCmp.contains(paramTransformer) {
                
                
                if cmp.parameterConditions.isEmpty {
                    XCTFail("Missing parameter conditions.  Testing '\(pthCmp)'",
                            file: file,
                            line: line)
                    return false
                }
                
                if pthCmp.contains("?") &&
                    !cmp.parameterConditions.first!.value.optional {
                    XCTFail("Parameter '\(cmp.parameterConditions.first!.key)' marked as option but not set.  Testing '\(pthCmp)'",
                            file: file,
                            line: line)
                    return false
                }
                
                
                if pthCmp.contains(paramRegCondition) &&
                    cmp.parameterConditions.first!.value.conditions.count != 1 {
                    XCTFail("Parameter '\(cmp.parameterConditions.first!.key)' does not have proper condition count.  Expected 1, Found \(cmp.parameterConditions.first!.value.conditions.count).  Testing '\(pthCmp)'",
                            file: file,
                            line: line)
                    return false
                }
                
                if pthCmp.contains(paramRegCondition) &&
                    cmp.parameterConditions.first!.value.conditions[0].singlePattern?.expressionString != paramRegCondition {
                    XCTFail("Invalid parameter '\(cmp.parameterConditions.first!.key)' condition. Expected: '\(paramRegCondition)', Found: \(cmp.parameterConditions.first!.value.conditions[0]).  Testing '\(pthCmp)'",
                            file: file,
                            line: line)
                    return false
                }
                
                if pthCmp.contains("<\(paramTransformer)>") &&
                  cmp.parameterConditions.first!.value.transformation?.string != paramTransformer {
                    XCTFail("Invalid parameter '\(cmp.parameterConditions.first!.key)' tranformer. Expected: '\(paramTransformer)', Found: '\(cmp.parameterConditions.first!.value.transformation?.string ?? "")'.  Testing '\(pthCmp)'",
                            file: file,
                            line: line)
                    return false
                }
                
            }
        
        }
        
        return true
    }
    
    
    let pathTransformer = "Int"
    let paramTransformer = "UInt"
    
    let pathRegCondition = "^[0-4]$"
    let paramRegCondition = "^[6-9]$"

    func testRoutePaths() {
        func generateParameterAttributeList(for parameter: String,
                         availableParameterAttributes: [String],
                         _ generated: (String) throws -> Bool) rethrows -> Bool {
            for i in 0..<availableParameterAttributes.count {

                if !(try generated(availableParameterAttributes[i])) {
                    return false
                }
                
                if i > 0 {
                    var attribs: String = ""
                    for x in 0...i {
                        if !attribs.isEmpty { attribs += " " }
                        attribs += availableParameterAttributes[x]
                    }
                    
                    if !(try generated(attribs)) {
                        return false
                    }
                    
                }
            }
            return true

        }
        func generatePathAttributeList(for path: String,
                                       availablePathAttributes: [String],
                                       availableParameters: [String],
                                       availableParameterAttributes: [String],
                                       _ generated: (String) throws -> Bool) rethrows -> Bool {
            // no special requirements
            if !(try generated(path)) { return false }
            
            var paramAttribs: [String] = []
            
            for param in availableParameters {
                let ret = try generateParameterAttributeList(for: param,
                                               availableParameterAttributes: availableParameterAttributes) {
                    
                    let param = "@\(param) : { \($0) }"
                    // save param attrib combinations for later
                    paramAttribs.append(param)
                    return try generated(path + "{ { \(param) } }")
                }
                if !ret { return false }
            }
            for i in 0..<availablePathAttributes.count {
                if path.hasSuffix("*") {
                    continue
                }
                
                if availablePathAttributes[i].contains("^") && !NSString(string: path).lastPathComponent.hasPrefix(":") {
                    continue
                }
                
                for paramAttrib in paramAttribs {
                    let ret = try generated(path + "{ \(availablePathAttributes[i]) { \(paramAttrib) } }")
                    if !ret { return false }
                }
                
                if i > 0 {
                    var pathAttribs: String = ""
                    for x in 0...i {
                        // if path attrib is a regex condition we make sure path component is an identifier
                        if !pathAttribs.isEmpty { pathAttribs += " " }
                        pathAttribs += availablePathAttributes[x]
                    }
                    if pathAttribs.contains("^") && !NSString(string: path).lastPathComponent.hasPrefix(":") {
                        continue
                    }
                    
                    for paramAttrib in paramAttribs {
                        
                        let ret = try generated(path + "{ \(pathAttribs) { \(paramAttrib) } }")
                        if !ret { return false }
                    }
                }
            }
            return true
        }
        
        let pathAtributes = ["{\(pathRegCondition)}", "<\(pathTransformer)>"]
        let paramAttributes = ["?", "[ {\(paramRegCondition)} ]", "<\(paramTransformer)>"]
        
        
    
        let paths = ["/", "/sub", "/pages", "/shared", "/page/:ident", "/any/*", "/after/**"]
        let subPaths = ["sub", "sub2","*","**"]
        
        let stopOnFailure: Bool = true
        var keepGoing: Bool = true
        for path in paths where keepGoing {
            keepGoing = try! generatePathAttributeList(for: path,
                                      availablePathAttributes: pathAtributes,
                                      availableParameters: ["param"],
                                      availableParameterAttributes: paramAttributes) { string in
                //print("Testing Path '\(string)'")
                guard let route = XCTAssertsNoThrow(try LittleWebServerRoutePathConditions(value: string)) else {
                    return !stopOnFailure // Stop testing
                }
                
                #if swift(>=5.3)
                guard validateRouteConditions(fullPath: string,
                                              route: route,
                                              pathRegCondition: pathRegCondition,
                                              pathTransformer: pathTransformer,
                                              paramRegCondition: paramRegCondition,
                                              paramTransformer: paramTransformer,
                                              file: #filePath) else {
                    return !stopOnFailure
                }
                #else
                guard validateRouteConditions(fullPath: string,
                                              route: route,
                                              pathRegCondition: pathRegCondition,
                                              pathTransformer: pathTransformer,
                                              paramRegCondition: paramRegCondition,
                                              paramTransformer: paramTransformer,
                                              file: #file) else {
                    return !stopOnFailure
                }
                #endif
                
                if !(path == "/") && !path.hasSuffix("**") {
                    for sub in subPaths {
                        var newPath = string
                        if !newPath.hasSuffix("/") { newPath += "/" }
                        newPath += sub
                        let isValidSubRoute = try! generatePathAttributeList(for: newPath,
                                                  availablePathAttributes: pathAtributes,
                                                  availableParameters: ["param2"],
                                                  availableParameterAttributes: paramAttributes) { string in
                            
                            //print("Testing Sub Path '\(string)'")
                            guard let route2 = XCTAssertsNoThrow(try LittleWebServerRoutePathConditions(value: string),
                                                                 "Failed parsing route sub path '\(string)'") else {
                                return !stopOnFailure
                            }
                            #if swift(>=5.3)
                            return validateRouteConditions(fullPath: string,
                                                           route: route2,
                                                           pathRegCondition: pathRegCondition,
                                                           pathTransformer: pathTransformer,
                                                           paramRegCondition: paramRegCondition,
                                                           paramTransformer: paramTransformer,
                                                           file: #filePath)
                            #else
                            return validateRouteConditions(fullPath: string,
                                                           route: route2,
                                                           pathRegCondition: pathRegCondition,
                                                           pathTransformer: pathTransformer,
                                                           paramRegCondition: paramRegCondition,
                                                           paramTransformer: paramTransformer,
                                                           file: #file)
                            #endif
                            
                        }
                        if !isValidSubRoute {
                            return !stopOnFailure
                        }
                        
                    }
                }
                return true
            }
            
            
        }
        
    }
    
    func testSHA1() {
        let secWebSocketKey = "x3JJHMbDL1EzLkh9GBhXDw=="
        let secretCode = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let expectedValue = "HSmrc0sMlYUkAGmm5OPpG2HaGWk="
        
        let secWebSocketAccept = (secWebSocketKey + secretCode).sha1.base64EncodedString()
        XCTAssertEqual(secWebSocketAccept, expectedValue)
    }
    

    static var allTests = [
        ("testParseGetRequests", testParseGetRequests),
        ("testParsePostFormURLEncodingRequests", testParsePostFormURLEncodingRequests),
        ("testParsePostFormURLEncodingRequestsRepeated", testParsePostFormURLEncodingRequestsRepeated),
        ("testParsePostFormURLEncodingRequestsMeasured", testParsePostFormURLEncodingRequestsMeasured),
        ("testBasicFiles", testBasicFiles),
        ("testBrowseSharedFolder", testBrowseSharedFolder),
        ("testWebSocket", testWebSocket),
        ("testObjectAccessing", testObjectAccessing),
        ("testCustomResponse", testCustomResponse),
        ("testParallelRequests", testParallelRequests),
        ("testMultiRequestConnection", testMultiRequestConnection),
        ("testAddressValues", testAddressValues),
        ("testPathCondition", testPathCondition),
        ("testRoutePaths", testRoutePaths),
        ("testSHA1", testSHA1),
        
        
        
    ]
}
