//
//  HTTPCommunicatorV1_1.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-20.
//

import Foundation
import Dispatch

public extension LittleWebServer.HTTP.Communicators {
    /// A HTTP/1.1 Server
    class V1_1: LittleWebServerHTTPCommunicator {
        
        public let httpVersion: LittleWebServer.HTTP.Version = .v1_1
        
        private let queueSyncList: _SyncLock<[LittleWebServer.WorkerQueue: NSLock]> = .init()
        
        private let threads: _SyncLock<[Thread]> = .init()
        
        public var threadStopTimeout: TimeInterval = 30.0
        
        private let queueOprationCount: _SyncLock<[LittleWebServer.WorkerQueue: UInt]> = .init()
        
        
        private var _maxWorkerCounts: [LittleWebServer.WorkerQueue: Int] = [:] {
            willSet {
                guard let requestCount = newValue[.request] else {
                    preconditionFailure("Missing Count for  worker queue Request")
                }
                precondition(requestCount == -1 || requestCount > 0,
                             "Max '\(LittleWebServer.WorkerQueue.request)' Worker Queue Count must be -1 or greater than 0")
                
                for (key, val) in newValue {
                    if key != .request  {
                        precondition(requestCount >= -1,
                                     "Max '\(val)' Worker Queue Count must be >= -1")
                    }
                    
                }
            }
        }
        private let maxWorkerCountsLock = NSLock()
        public var maxWorkerCounts: [LittleWebServer.WorkerQueue: Int] {
            get {
                self.maxWorkerCountsLock.lock()
                defer { self.maxWorkerCountsLock.unlock() }
                return self._maxWorkerCounts
            }
            set {
                self.maxWorkerCountsLock.lock()
                defer { self.maxWorkerCountsLock.unlock() }
                self._maxWorkerCounts = newValue
            }
        }
        
        public var maxTotalWorkerCount: Int = -1
        public var totalWorkerCount: UInt {
            return self.queueOprationCount.lockingForWithValue { ptr in
                return ptr.pointee.reduce(0, { return $0 + $1.value })
            }
        }
        
        func getTotalWorkerCount() -> UInt? {
            return self.totalWorkerCount
        }
        
        private func getWorkerCount(for queue: LittleWebServer.WorkerQueue) -> UInt {
            return self.queueOprationCount.lockingForWithValue { ptr in
                return ptr.pointee[queue] ?? 0
            }
        }
        
        private func incrementWorkerCount(for queue: LittleWebServer.WorkerQueue) {
            self.queueOprationCount.lockingForWithValue { ptr in
                ptr.pointee[queue] = (ptr.pointee[queue] ?? 0) + 1
            }
        }
        
        private func decrementWorkerCount(for queue: LittleWebServer.WorkerQueue) {
            self.queueOprationCount.lockingForWithValue { ptr in
                if let val = ptr.pointee[queue], val > 0 {
                    ptr.pointee[queue] = val - 1
                }
            }
            
        }
        
        private func getQueueSyncLock(for queue: LittleWebServer.WorkerQueue) -> NSLock {
            return self.queueSyncList.lockingForWithValue { ptr in
                guard let rtn = ptr.pointee[queue] else {
                    let rtn = NSLock()
                    ptr.pointee[queue] = rtn
                    return rtn
                }
                return rtn
            }
            
        }
        
        
        
        private func getMaxWorkerCount(for queue: LittleWebServer.WorkerQueue) -> Int? {
            return self.maxWorkerCounts[queue] ?? Int.max
        }
        
        public func waitForQueueToBeAvailable(queue: LittleWebServer.WorkerQueue,
                                              on server: LittleWebServer) {
            let lock = self.getQueueSyncLock(for: queue)
            lock.lock()
            defer { lock.unlock() }
                
            // get the max worker count each time
            while let mxWorkerCount = self.getMaxWorkerCount(for: queue),
                  let totalWorkerCount = self.getTotalWorkerCount(),
                  (
                      (
                        // If max worker count == -1, means no maximum
                        mxWorkerCount > -1 &&
                        // if current count > max count
                        mxWorkerCount <= self.getWorkerCount(for: queue)
                      )
                    || // OR
                      (
                        // If maxTotalWorkerCount == -1, means no maximum
                        self.maxTotalWorkerCount > -1 &&
                        self.maxTotalWorkerCount <= totalWorkerCount
                      )
                  ) &&
                  !server.isStoppingOrStopped &&
                  !Thread.current.isCancelled {
                Thread.sleep(forTimeInterval: 0.1)
            }
            
        }
        
        /// Moves the processing of a request from the main request queue to a different queue
        /// - Parameters:
        ///   - queue: The queue to move the current processing to
        ///   - request: The request we're working on
        ///   - response: The response for the requeset
        ///   - uploadedFiles: Reference to any uploaded files for this request to be removed when done
        ///   - controller: The route controller used to process the request
        ///   - server: The server the request was made on
        ///   - sessionManager: The session manager being used
        ///   - client: The client connection the request came from
        ///   - signalServerEvent: Callback used to receive information of what was written to the client
        ///   - signalServerError: Callback used when there was an error when writing
        /// - Returns: Returns an indicator if the processing actually moved to a different queue
        private func hopToQueue(queue: LittleWebServer.HTTP.Response.ProcessQueue,
                                request: LittleWebServer.HTTP.Request,
                                response: LittleWebServer.HTTP.Response,
                                uploadedFiles: [LittleWebServer.HTTP.Request.UploadedFileReference],
                                in controller: LittleWebServer.Routing.Requests.RouteController,
                                server: LittleWebServer,
                                sessionManager: LittleWebServerSessionManager,
                                client: LittleWebServerClient,
                                signalServerEvent: @escaping (_ event: LittleWebServer.ServerEvent) -> Void,
                                signalServerError: @escaping (Error, String, Int) -> Void) throws -> Bool {
            guard !queue.isCurrent else { return false }
            
           
            self.waitForQueueToBeAvailable(queue: queue.workerQueue, on: server)
            guard !server.isStoppingOrStopped && !Thread.current.isCancelled else {
                return false
            }
            self.incrementWorkerCount(for: queue.workerQueue)
            DispatchQueue(label: "[\(queue)]: \(client.uid)").async { [server, response, client] in
                autoreleasepool {
                    self.threads.append(Thread.current)
                
                    Thread.current.littleWebServerClient = client
                    let oldServer = Thread.current.littleWebServerDetails.webServer
                    Thread.current.littleWebServerDetails.webServer = server
                    
                    defer {
                        
                        //Thread.current.threadDictionary.removeObject(forKey: "LittleWebServerClient")
                        Thread.current.littleWebServerClient = nil
                        Thread.current.littleWebServerDetails.webServer = oldServer
                        
                        if client.isConnected {
                            //try? client.writeUTF8("\r\n")
                            client.close()
                        }
                        
                        self.decrementWorkerCount(for: queue.workerQueue)
                        self.threads.remove(Thread.current)
                        
                        for file in uploadedFiles {
                            try? FileManager.default.removeItem(at: file.location)
                        }
                        signalServerEvent(.clientDisconnected(client.connectionDetails,
                                                              .normal))
                        
                        
                        
                    }

                    var hasPreviouslyWrittenHeaders: Bool = false
                    do {
                        try self.write(request,
                                       response,
                                       in: controller,
                                       server: server,
                                       sessionManager: sessionManager,
                                       to: client,
                                       hasPreviouslyWrittenHeaders: &hasPreviouslyWrittenHeaders,
                                       keepAlive: true,
                                       signalServerEvent: signalServerEvent)
                    } catch {
                        let err = LittleWebServer.WebRequestError.queueProcessError(queue,
                                                                                      .request(request,
                                                                                               connectionId: client.uid),
                                                                                      error)
                        #if swift(>=5.3)
                        signalServerError(err, #filePath, #line)
                        #else
                        signalServerError(err, #file, #line)
                        #endif
                    }
                }
            }
            
            return true
        }
        
        
        /// Write the response to the client connection
        /// - Parameters:
        ///   - request: The request we're working on
        ///   - response: The response for the requeset
        ///   - controller: The route controller used to process the request
        ///   - server: The server the request was made on
        ///   - sessionManager: The session manager being used
        ///   - client: The client connection the request came from
        ///   - hasPreviouslyWrittenHeaders: Indicator if a header has already been written for the given request (Could occur if includes where called)
        ///   - keepAlive: Indicator if the client connection should be kept alive
        ///   - signalServerEvent: Callback used to receive information of what was written to the client
        private func write(_ request: LittleWebServer.HTTP.Request?,
                           _ response: LittleWebServer.HTTP.Response,
                           in controller: LittleWebServer.Routing.Requests.RouteController,
                           server: LittleWebServer,
                           sessionManager: LittleWebServerSessionManager,
                           to client: LittleWebServerClient,
                           hasPreviouslyWrittenHeaders: inout Bool,
                           keepAlive: Bool? = nil,
                           writeResponseEnding: Bool = false,
                           signalServerEvent: @escaping (_ event: LittleWebServer.ServerEvent) -> Void) throws {
            
            
            try autoreleasepool {
                let startWriting = Date()
                defer {
                    if Debugging.isInXcode {
                        let interval = (startWriting.timeIntervalSinceNow * -1)
                        print("Write response took \(interval) seconds")
                    }
                    
                }
                var workingHeaders = response.head.headers
                if let req = request {
                    
                    
                    for sessionId in req.headers.cookies.sessionIds {
                        // Clear out any old lingering session ids
                        if sessionId != req.getSession(false)?.id {
                            workingHeaders.cookies.append(.init(expiredSessionId: sessionId))
                        }
                    }
                    
                    if let session = req.getSession(false) {
                        if !session.isInvalidated {
                            
                            // We have a session thats not invalidated with content
                            
                            let dt = Date()
                            sessionManager.saveSession(session)
                            workingHeaders.cookies.append(.init(sessionId: session.id,
                                                                expires: dt + sessionManager.sessionTimeOutLimit,
                                                                maxAge: Int(sessionManager.sessionTimeOutLimit),
                                                                domain: req.headers.host?.name,
                                                                path: "/",
                                                                httpOnly: true))
                            
                        } else if !req.isNewSession && session.isInvalidated {
                            //  If we have an existing session, we tell the user to remove the cookie
                            workingHeaders.cookies.append(.init(expiredSessionId: session.id))
                            sessionManager.removeSession(session)
                        } else if req.isNewSession && session.count == 0 {
                            // this is a new unsued session. lets just remove it
                            sessionManager.removeSession(session)
                        }
                    }
                }
                if workingHeaders.contentType == nil,
                   let bodyContentType = response.body.contentType {
                    workingHeaders.contentType = bodyContentType
                } else if workingHeaders.contentType == nil,
                          let filePath = response.body.filePath {
                    if FileManager.default.fileExists(atPath: filePath) {
                        let ext = NSString(string: filePath).pathExtension
                        if let fileContentType = server.contentResourceType(forExtension: ext) {
                            workingHeaders.contentType = .init(fileContentType)
                        }
                    }
                }
                
                if workingHeaders[.upgrade] == nil {
                    if request == nil || request!.version == .v1_0 {
                        workingHeaders.connection = .close
                    } else if let b = keepAlive {
                        if b {
                            workingHeaders.connection = .keepAlive
                            if self.httpVersion < .v2_0 {
                                workingHeaders.keepAlive = server.keepAliveDetails
                            }
                        } else {
                            workingHeaders.connection = .close
                        }
                    }
                }
                
                if let s = server.serverName {
                    workingHeaders[.server] = s
                }
                
                workingHeaders[.date] = server.dateHeaderFormatter.string(from: .now)
                
                let bodyDetails = try response.body.content(in: controller, on: server)
                if let ctl = bodyDetails?.length/*, ctl > 0*/ {
                    workingHeaders.contentLength = ctl //+ 2 // Add CRLF
                }
                if let ct: LittleWebServer.HTTP.Headers.ContentType = bodyDetails?.contentType,
                   workingHeaders.contentType == nil {
                    workingHeaders.contentType = ct
                }
                
                if workingHeaders.contentLength == nil && workingHeaders[.upgrade] == nil {
                    workingHeaders.transferEncodings += .chunked
                    //workingHeaders.transferEncodings = ((workingHeaders.transferEncodings ?? .init())!) + .chunked
                }
                
                response.headers = workingHeaders
                
                
                
                if !hasPreviouslyWrittenHeaders {
                    var msg = response.head.message ?? ""
                    if !msg.isEmpty { msg = " " + msg }
                    let respLine = "\(self.httpVersion.httpRespnseValue) \(response.head.responseCode)\(msg)"
                    try client.writeUTF8Line(respLine)
                    if !workingHeaders.isEmpty {
                        try client.writeUTF8(workingHeaders.http1xContent)
                    }
                    try client.writeUTF8Line("")
                    hasPreviouslyWrittenHeaders = true
                    
                    //print(respLine)
                    //print(workingHeaders.httpContent)
                    
                    signalServerEvent(.requestEvent(client.connectionDetails,
                                                    .outgoingResposne(.init(response),
                                                                      for: request)))
                    
                    
                }
                
                let writer = HTTPLittleWebServerOutputStreamV1_1(client: client,
                                                                 transferEncodings: workingHeaders.transferEncodings)
                
                
                
                if bodyDetails != nil && bodyDetails!.content != nil {
                    try writer.write(bodyDetails!.content!)
                } else if let pth = response.body.filePath,
                          let speedLimit = response.body.fileTransferSpeedLimit {
                    try writer.writeContentsOfFile(atPath: pth, range: response.body.fileRange, speedLimit: speedLimit)
                } else if let custom = response.body.customBody {
                    try custom(request?.inputStream ?? LittleWebServerEmptyInputStream(), writer)
                    // ensures that after a custom body write has occured
                    // that the end of reponse (zero byte) is send
                    // if not done so by the custom body write
                    if writer.isConnected && !writer.hasWrittenZeroChunk {
                        try? writer.write([])
                    }
                }
                
                if workingHeaders.contentLength != nil && writeResponseEnding {
                    //try writer.writeUTF8("\r\n")
                }
                
                
                //if let ctl = bodyDetails?.length, ctl > 0 {
                //if writer.isConnected {
                //    try writer.writeUTF8Line("")
                //}
                //}
            }
            
        }
        
        public func onAcceptedClient(_ client: LittleWebServerClient,
                                     from listener: LittleWebServerListener,
                                     server: LittleWebServer,
                                     sessionManager: LittleWebServerSessionManager,
                                     signalServerEvent: @escaping (_ event: LittleWebServer.ServerEvent) -> Void,
                                     signalServerError: @escaping (Error, String, Int) -> Void) {
            self.incrementWorkerCount(for: .request)
            
            DispatchQueue(label: "[request]: \(client.uid)").async { [server, client, signalServerEvent ] in
                autoreleasepool {
                    /*self.threadLock.lock()
                    self.threads.append(Thread.current)
                    self.threadLock.unlock()*/
                    self.threads.append(Thread.current)
                    
                    
                    Thread.current.littleWebServerClient = client
                    var hoppingQueue: Bool = false
                    var clientDisconnectReason: LittleWebServer.ServerEvent.ClientDisconnectReason = .normal
                    
                    let oldServer = Thread.current.littleWebServerDetails.webServer
                    Thread.current.littleWebServerDetails.webServer = server
                    defer {
                        
                        
                        //print("Opt Count: \(q.operationCount)")
                        self.decrementWorkerCount(for: .request)
                        self.threads.remove(Thread.current)
                        
                        Thread.current.littleWebServerDetails.webServer = oldServer
                        
                        if !hoppingQueue {
                            
                            if client.isConnected {
                                //try? client.writeUTF8("\r\n")
                                client.close()
                            }
                            signalServerEvent(.clientDisconnected(client.connectionDetails,
                                                                  clientDisconnectReason))
                        }
                        
                        //Thread.current.threadDictionary.removeObject(forKey: "LittleWebServerClient")
                        Thread.current.littleWebServerClient = nil
                    }
                    //print("[\(client.uid)]: Starting processing of client")
                    signalServerEvent(.clientConnected(client.connectionDetails))
                    
                    
                    var keepAlive: Bool = true
                    
                    var firstRequest: Bool = true
                    var requestCount: UInt = 0
                    let maxRequestCount = (server.keepAliveDetails?.max ?? UInt.max)
                    var sessionId: String? = nil
                    
                    while keepAlive && // while we want to keep the connection alive
                          client.isConnected && // while the socket is still connected
                          requestCount < maxRequestCount && // while we haven't reach the max requests per connection
                          !server.isStoppingOrStopped &&
                          !Thread.current.isCancelled { // If the thread is being cancelled.  Ususallay means that we're shutting down
                        //print("[\(client.uid)]: Starting Request")
                        clientDisconnectReason = .normal
                        
                        /*#if !_runtime(_ObjC) && swift(>=5.1) && !swift(>=5.4)
                        keepAlive = false
                        #endif*/
                        
                        let startTime = Date()
                        defer {
                            if client.isConnected {
                                Debugging.printIfXcode("Request took \(startTime.timeIntervalSinceNow.magnitude) seconds")
                            }
                        }
                        
                        let canContinue: Bool = autoreleasepool {
                            //print("[\(client.uid)]: Starting Request Error: \(LittleWebServerSocketSystemError.current())")
                            var uploadedFiles: [LittleWebServer.HTTP.Request.UploadedFileReference] = []
                            defer {
                                if !hoppingQueue {
                                    for file in uploadedFiles {
                                        try? FileManager.default.removeItem(at: file.location)
                                    }
                                }
                            }
                            var requestHead: LittleWebServer.HTTP.Request.Head! = nil
                            var headReadError: Error? = nil
                            var sentResponseHead: Bool = false
                            // We have a time limit for the first request to come in
                            if firstRequest && server.initialRequestTimeoutInSeconds > 0 {
                                let semaphore = DispatchSemaphore(value: 0)
                                let waitResults = DispatchQueue.new(label: "[request]: \(client.uid) - Read First Request",
                                                                    timeout: .now() + server.initialRequestTimeoutInSeconds) {
                                //let newQueue = DispatchQueue(label: "[request]: \(client.uid) - Read First Request")
                                //newQueue.async {
                                    //print("[\(client.uid)]: Reading First Request")
                                    do {
                                        requestHead = try HTTPParserV1_1.readRequestHead(from: client)
                                    } catch {
                                        headReadError = error
                                        if let e = error as? LittleWebServerClientHTTPReadError {
                                            if case LittleWebServerClientHTTPReadError.invalidRequestHead(let str) = e {
                                                clientDisconnectReason = .badRequest(str)
                                            }
                                        } else if !client.isConnected {
                                            headReadError = nil
                                            clientDisconnectReason = .clientDisconnected
                                        }
                                        client.close()
                                    }
                                    semaphore.signal()
                                }
                                
                                //guard semaphore.wait(timeout: (.now() + server.initialRequestTimeoutInSeconds)) == .success else {
                                guard waitResults == .success else {
                                    clientDisconnectReason = .readRequestTimedOut
                                    server.signalServerError(error: LittleWebServer.WebRequestError.connectionTimedOut(.connectionId(client.uid)))
                                    if client.isConnected {
                                        client.close()
                                    }
                                    
                                    return false
                                }
                                if !client.isConnected {
                                    return false
                                }
                                
                            } else {
                                //print("[\(client.uid)]: Reading Additional Request")
                                do {
                                    requestHead = try HTTPParserV1_1.readRequestHead(from: client)
                                } catch {
                                    //print("Caught Error: \(error)")
                                    // error parsing request
                                    headReadError = error
                                    if let e = error as? LittleWebServerClientHTTPReadError {
                                        if case LittleWebServerClientHTTPReadError.invalidRequestHead(let str) = e {
                                            clientDisconnectReason = .badRequest(str)
                                        }
                                        
                                    } else if !client.isConnected {
                                        headReadError = nil
                                        clientDisconnectReason = .clientDisconnected
                                    }
                                    
                                    return false
                                }
                            }
                            
                            //print("[\(client.uid)]: Post Request Head Error: \(LittleWebServerSocketSystemError.current())")
                            
                            guard let httpHead = requestHead else {
                                
                                server.signalServerError(error: LittleWebServer.WebRequestError.badRequest(.connectionId(client.uid), headReadError))
                                
                                if client.isConnected {
                                    try? self.write(nil, LittleWebServer.HTTP.Response.badRequest(),
                                                   in: server.defaultHost,
                                                   server: server,
                                                   sessionManager: sessionManager,
                                                   to: client,
                                                   hasPreviouslyWrittenHeaders: &sentResponseHead,
                                                   signalServerEvent: signalServerEvent)
                                }
                                
                                
                                client.close()
                                keepAlive = false
                                return false
                            }
                            
                            //print("[\(client.uid)]: Request Head: \(httpHead)")
                            
                            var request: LittleWebServer.HTTP.Request! = nil
                            var headers: LittleWebServer.HTTP.Request.Headers! = nil
                            let bodyInputStream = HTTPLittleWebServerInputStreamV1_1(client: client)
                            var contentLength: UInt? = nil
                            
                            // Indicator if we should kill connectioh
                            // If the current request has no specific content length
                            // We don't know when the request ends so we can't
                            // move on to the next.  Therefore the connection will
                            // be killed
                            var killConnection: Bool = false
                            var router: LittleWebServer.Routing.Requests.RouteController? = nil
                            
                            do {
                                //print("[\(client.uid)]: Pre Request Headers Error: \(LittleWebServerSocketSystemError.current())")
                                headers = try HTTPParserV1_1.readRequestHeaders(from: client)
                                //print("[\(client.uid)]: Post Request Headers Error: \(LittleWebServerSocketSystemError.current())")
                                if headers.connection == nil || headers.connection == .close {
                                    keepAlive = false
                                }
                                contentLength = headers.contentLength
                                bodyInputStream.chunked = headers.transferEncodings.contains(.chunked)
                                bodyInputStream.reportedContentLength = contentLength
                                
                                
                                //print("[\(client.uid)]: Pre TempDirURL.1 Error: \(LittleWebServerSocketSystemError.current())")
                                let tempDirURL: URL = server.temporaryFileUploadLocation.appendingPathComponent(headers.host?.name.description ?? "default")
                                //Foundation.errno = 0
                               
                                //print("[\(client.uid)]: Post TempDirURL.1 Error: \(LittleWebServerSocketSystemError.current())")
                                if headers.contentType?.resourceType == .multiPartForm {
                                    // Only check and create temp folder if the request is a multi-part
                                    // content type
                                    //print("[\(client.uid)]: Pre TempDirURL ('\(tempDirURL.path))') Create Error: \(LittleWebServerSocketSystemError.current())")
                                    if !FileManager.default.fileExists(atPath: tempDirURL.path) {
                                        //print("[\(client.uid)]: Creating folder '\(tempDirURL.path)'")
                                        try? FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
                                    }
                                    
                                    //print("[\(client.uid)]: Post TempDirURL Create Error: \(LittleWebServerSocketSystemError.current())")
                                }
                                
                                // Patch so that multiple session don't get created for each separate
                                // request on the same connection
                                if let sId = sessionId,
                                   !headers.cookies.sessionIds.contains(sId) {
                                    headers.cookies.sessionIds.append(sId)
                                }
                                //print("[\(client.uid)]: Pre Request Parsed Error: \(LittleWebServerSocketSystemError.current())")
                                request = try Timer.xcodeDuration(of: try HTTPParserV1_1.parseRequest(scheme: listener.scheme,
                                                                                        head: httpHead,
                                                                                        headers: headers,
                                                                                        bodyStream: bodyInputStream,
                                                                                        uploadedFiles: &uploadedFiles,
                                                                                        tempLocation: tempDirURL)) { duration, r, _ in
                                    
                                    print("[\(client.uid)]: Parse request body took \(duration) seconds")
                                    if let rq = r {
                                        print(rq.string)
                                    }
                                    
                                }
                                
                                //print("[\(client.uid)]: After Request Parsed Error: \(LittleWebServerSocketSystemError.current())")
                                
                                sessionId = request.getSession(false)?.id
                                
                                //signalRequestResponseEvent(.incomminRequest(request))
                                signalServerEvent(.requestEvent(client.connectionDetails,
                                                                .incomminRequest(request)))
                                
                                
                                router = Timer.xcodeDuration(of: server.hosts.getRoutes(for: request,
                                                                                  withDefault: server.defaultHost)) { duration, _, _ in
                                    print("[\(client.uid)]: Getting router took \(duration) seconds")
                                }
                                //print("[\(client.uid)]: Pre Response Error: \(LittleWebServerSocketSystemError.current())")
                                let response = try Timer.xcodeDuration(of: try router!.processRequest(for: request,
                                                                                                 on: server)) { duration, _, _ in
                                    print("[\(client.uid)]: Getting response took \(duration) seconds")
                                }
                                if (try self.hopToQueue(queue: response.writeQueue,
                                                        request: request,
                                                        response: response,
                                                        uploadedFiles: uploadedFiles,
                                                        in: router!,
                                                        server: server,
                                                        sessionManager: sessionManager,
                                                        client: client,
                                                        signalServerEvent: signalServerEvent,
                                                        signalServerError: signalServerError)) {
                                    hoppingQueue = true
                                    return false
                                } else {
                                    //print("[\(client.uid)]: Pre Writing Response Error: \(LittleWebServerSocketSystemError.current())")
                                    try Timer.xcodeDuration(of: try self.write(request, response,
                                                                          in: router!,
                                                                          server: server,
                                                                          sessionManager: sessionManager,
                                                                          to: client,
                                                                          hasPreviouslyWrittenHeaders: &sentResponseHead,
                                                                          keepAlive: keepAlive,
                                                                          writeResponseEnding: true,
                                                                          signalServerEvent:  signalServerEvent)) { duration, _, _ in
                                        print("[\(client.uid)]: Writing response (\(response.head.responseCode) took \(duration) seconds")
                                        //print(response.head.string(for: server))
                                        //response
                                    }
                                    //print("[\(client.uid)]: Writing Response End Error: \(LittleWebServerSocketSystemError.current())")
                                    
                                    //try client.writeUTF8("\r\n\r\n\r\n")
                                }
                                
                                if (request.getSession(false)?.isInvalidated ?? true) {
                                    sessionId = nil
                                }
                                
                            } catch {
                                let requestIdentifier: LittleWebServer.WebRequestIdentifier
                                if let req = request {
                                    requestIdentifier = .request(req, connectionId: client.uid)
                                } else {
                                    requestIdentifier = .requestHead(httpHead, headers, connectionId: client.uid)
                                }
                                let processError: LittleWebServer.WebRequestError = .processRequestFailure(requestIdentifier,
                                                                                           serverIdentifier: listener.uid,
                                                                                           clientIdentifier: client.uid,
                                                                                           error: error)
                                server.signalServerError(error: processError)
                                
                                if client.isConnected {
                                    do {
                                        
                                        let resp = (router ?? server.defaultHost).internalError(for: request,
                                                                                              error: error,
                                                                                              signalServerErrorHandler: false)
                                        
                                        
                                        try self.write(request, resp,
                                                       in: (router ?? server.defaultHost),
                                                       server: server,
                                                       sessionManager: sessionManager,
                                                       to: client,
                                                       hasPreviouslyWrittenHeaders: &sentResponseHead,
                                                       signalServerEvent: signalServerEvent)
                                    } catch {
                                        killConnection = true
                                    }
                                }
                                
                            }
                            
                            guard client.isConnected else {
                                return false
                            }
                            
                            if !killConnection && !hoppingQueue {
                                // Try and ready anything left in the request body so we can move on to
                                // any next request within the same connection
                                if bodyInputStream.chunked && bodyInputStream.lastChunkSize != 0 {
                                    do {
                                        // Try getting next chunked. to ensure
                                        // lastChunkSize should be populated
                                        try bodyInputStream.readChunk()
                                        // Make sure lastChunkSize is populated or something
                                        // went wrong
                                        if bodyInputStream.lastChunkSize != nil {
                                            // Read each chunk until we get the 0 chunk
                                            while bodyInputStream.lastChunkSize != 0 {
                                                try bodyInputStream.readChunk()
                                            }
                                        } else {
                                            // Failed to get to end of chunks
                                            killConnection = true
                                        }
                                    } catch {
                                        // Failed to get to end of chunks
                                        killConnection = true
                                    }
                                    
                                } else if let ctl = contentLength, // We can only do this if the header gave us a total body content length
                                   (ctl - bodyInputStream.actualByteRead) > 0 { // Make sure we haven't read the whole body
                                    
                                    var remainingBodyToRead = ctl - bodyInputStream.actualByteRead
                                    var tempBody = Array<UInt8>(repeating: 0, count: 10)
                                    
                                    while remainingBodyToRead > 0 {
                                        var requestingReadSize = tempBody.count
                                        if remainingBodyToRead < tempBody.count {
                                            requestingReadSize = Int(remainingBodyToRead)
                                        }
                                        do {
                                            let ret = try client.readBuffer(into: &tempBody, count: requestingReadSize)
                                            if ret == 0 { break }
                                            remainingBodyToRead -= ret
                                            
                                        } catch {
                                            killConnection = true
                                            break
                                        }
                                    }
                                }
                            }
                            
                            if killConnection {
                                client.close()
                                keepAlive = false
                                return false
                            } else {
                                // Must read last \r\n of request?
                                /*
                                if ((request?.contentLength ?? 0) > 0) || (request?.isChunked ?? false) {
                                    let _ = try? client.read(exactly: 2)
                                }
                                */
                            }
                            
                            return true
                        }
                        
                        
                        if !canContinue {
                            return
                        }
                        
                        firstRequest = false
                        requestCount += 1
                    }
                }
            }
        
        }
        
        public func serverStopping() {
            
            //let startStop = Date.now
            //print("Starting Communicator Stop")
            let threadGroup = DispatchGroup()
            let queue = DispatchQueue(label: "HTTPCommunicatorV1_1.ServerStopping.ThreadShutdown",
                                      attributes: .concurrent)
            for thread in self.threads.unsafeValue {
                //DispatchQueue(label: "HTTPCommunicatorV1_1.ServerStopping.ThreadShutdown").async {
                queue.async {
                    // enter work group so that we wait for all to complete
                    threadGroup.enter()
                    // tells when we leave work group
                    defer { threadGroup.leave() }
                    // Tell the thread logic that we want to cancel
                    thread.cancel()
                    let startWait: Date = .now
                    
                    // Wait until thread has left list OR we have waited out limit
                    while self.threads.contains(thread) &&
                            Date.now.timeIntervalSince(startWait).magnitude < self.threadStopTimeout {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    
                    // Check to see if given thread is still within the monitor list
                    if self.threads.contains(thread) {
                        // Try and get the client connection
                        if let client: LittleWebServerClient = thread.littleWebServerClient {
                            // Make sure the client connection is still connected
                            if client.isConnected {
                                // Close the client connection
                                client.close()
                            }
                            //thread.threadDictionary.removeObject(forKey: "LittleWebServerClient")
                            thread.littleWebServerClient = nil
                        }
                    }
                }
            }
            // Wait until all thread cancellations have finished
            threadGroup.wait()
            //print("Finished Communicator Stop took \(Date.now.timeIntervalSince(startStop).magnitude)")
            
        }
    }
}
