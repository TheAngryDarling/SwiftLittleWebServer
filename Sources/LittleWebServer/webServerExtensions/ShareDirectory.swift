//
//  ShareDirectory.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-10.
//

import Foundation

public extension LittleWebServer {
    /// Methods / Logic used to share file system resources
    struct FSSharing { private init() { }
        
        public enum SendFileError: Swift.Error {
            case urlMustBeFilePath(URL)
            case pathDoesNotExist(URL)
            case pathMustPointToFile(URL)
            case couldNotRetriveFileSize(URL, Swift.Error)
            case fileSizeMissing(URL)
            case invalidByteRangeRequest(URL, String)
            case byteRangeRequestOutOfBounds(URL, UInt, ClosedRange<UInt>)
        }
        /// Resource access cotroll
        public enum ShareDirectoryResourceAccess {
            case authenticationRequired
            case none
            case readonly
        }
    
        /// Handler used to retrive the transfer speed limit for the given resource
        /// - Parameters:
        ///   - request: The current request of the resource
        ///   - resource: The file system resource about to be transfered
        /// - Returns: Returns the speed limiter for the given resource
        public typealias FileTransferSpeedHandler = (_ request: LittleWebServer.HTTP.Request,
                                                     _ resource: URL) -> LittleWebServer.FileTransferSpeedLimiter
        
        /// Senda file as the response
        /// - Parameters:
        ///   - url: The URL to the file system resoure to send
        ///   - request: The current request
        ///   - controller: The route controller thats processing this request
        ///   - speedLimit: The speed limiter used when writing the file
        /// - Returns: Returns a response object used to write to the client response
        public static func sendFile(at url: URL,
                                    from request: LittleWebServer.HTTP.Request,
                                    in controller: LittleWebServer.Routing.Requests.RouteController,
                                    speedLimit: LittleWebServer.FileTransferSpeedLimiter = .unlimited) throws -> LittleWebServer.HTTP.Response {
            guard url.isFileURL else {
                throw SendFileError.urlMustBeFilePath(url)
            }
            let fileManager = FileManager.default
            var isDir: Bool = false
            
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else {
                // Should not get here.
                // File existance should be verified before calling
                // sendFile method
                return .notFound()
            }
            guard !isDir else {
                // Should not get here.
                // File type should be checked before calling
                // sendFile method
                return .forbidden()
                //throw SendFileError.pathMustPointToFile(url)
            }
            
            
            
            let fileAttribs: [FileAttributeKey : Any]
            do {
                fileAttribs = try FileManager.default.attributesOfItem(atPath: url.path)
            } catch {
                throw SendFileError.couldNotRetriveFileSize(url, error)
            }
            
            guard let nsFileSize = fileAttribs[.size] as? NSNumber else {
                throw SendFileError.fileSizeMissing(url)
            }
            
            let fileSize = UInt(truncating: nsFileSize)
            
            var headers = HTTP.Response.Headers()
            let fileModDate = fileAttribs[.modificationDate] as! Date
            headers.lastModified = fileModDate
            headers.eTag = headers.lastModifiedString?.sha1.base64EncodedString()
            
            
            
            //let fileContentType = Thread.current.currentLittleWebServer?.contentType(forExtension: url.pathExtension)
            let fileContentResourceType = Thread.current.littleWebServerDetails.webServer?.contentResourceType(forExtension: url.pathExtension)
            
            var multiPartBoundry: String? = nil
            var fileRanges: [ClosedRange<UInt>]? = nil
            if let strRange = request.headers[.range] {
                let rangeComponents = strRange.splitFirst(separator: "=").map(String.init)
                guard rangeComponents.count == 2, rangeComponents[0].lowercased() == "bytes" else {
                    //throw SendFileError.invalidByteRangeRequest(url, strRange)
                    return .rangeNotSatisfiable(fileSize: fileSize)
                }
                let rangeList = rangeComponents[1].replacingOccurrences(of: ", ", with: ",").split(separator: ",").map(String.init)
                for range in rangeList {
                    let bounds = range.split(separator: "-").map(String.init).compactMap(UInt.init)
                    guard bounds.count >= 1 && bounds.count <= 2 else {
                        //throw SendFileError.invalidByteRangeRequest(url, range)
                        return .rangeNotSatisfiable(fileSize: fileSize)
                    }
                    if bounds.count == 1 {
                        if range.hasPrefix("-") {
                            guard bounds[0] < fileSize else {
                                //throw SendFileError.invalidByteRangeRequest(url, range)
                                return .rangeNotSatisfiable(fileSize: fileSize)
                            }
                            let fileRange: ClosedRange<UInt> = (fileSize - bounds[0])...(fileSize-1)
                            
                            if fileRanges == nil { fileRanges = [] }
                            fileRanges!.append(fileRange)
                            
                        } else if range.hasSuffix("-") {
                            let fileRange: ClosedRange<UInt> = bounds[0]...(fileSize-1)
                            
                            if fileRanges == nil { fileRanges = [] }
                            fileRanges!.append(fileRange)
                            
                        } else {
                            //throw SendFileError.invalidByteRangeRequest(url, range)
                            return .rangeNotSatisfiable(fileSize: fileSize)
                        }
                    } else {
                        guard bounds[0] < bounds[1] && bounds[1] < fileSize else {
                            //throw SendFileError.invalidByteRangeRequest(url, range)
                            return .rangeNotSatisfiable(fileSize: fileSize)
                        }
                        
                        let fileRange: ClosedRange<UInt> = bounds[0]...bounds[1]
                        guard bounds[1] < fileSize else {
                            //throw SendFileError.byteRangeRequestOutOfBounds(url, fileSize, fileRange )
                            return .rangeNotSatisfiable(fileSize: fileSize)
                        }
                        
                        if fileRanges == nil { fileRanges = [] }
                        fileRanges!.append(fileRange)
                        
                    }
                    
                }
            }
            
            
            var boundryBlocks: [Data] = []
            var contentLength = fileSize
            if let frs = fileRanges, frs.count > 0 {
                if frs.count == 1 {
                    contentLength = UInt(frs[0].count)
                    headers[.contentRange] = "bytes \(frs[0].lowerBound)-\(frs[0].upperBound)/\(fileSize)"
                } else {
                    multiPartBoundry = UUID.init().uuidString
                    headers.contentType = .multipartByteRanges(boundry: multiPartBoundry!)
                    
                    var contentTypeData = Data()
                    if let ctrType = fileContentResourceType {
                        contentTypeData.append(contentsOf: "Content-Type: \(ctrType.string)\r\n".utf8)
                    }
                    let boundryData: Data = Data("--\(multiPartBoundry!)\r\n".utf8)
                    
                    for (i, range) in frs.enumerated() {
                        var dta = Data()
                        if i > 0 {
                            // Adds new line after previous boundry content data
                            dta.append(contentsOf: "\r\n".utf8)
                        }
                        dta.append(contentsOf: boundryData)
                        dta.append(contentsOf: contentTypeData)
                        dta.append(contentsOf: "Content-Range: bytes \(range.lowerBound)-\(range.upperBound)/\(fileSize)\r\n".utf8)
                        dta.append(contentsOf: "\r\n".utf8)
                        
                        boundryBlocks.append(dta)
                        
                    }
                    
                    contentLength = boundryBlocks.reduce(0, { return $0 + UInt($1.count) })
                    contentLength += frs.reduce(0, { return $0 + UInt($1.count) })
                    contentLength += UInt(boundryData.count + 2)
                    
                }
            } else {
                headers.contentType = HTTP.Headers.ContentType(resourceType: fileContentResourceType)
            }
            
            headers.contentLength = contentLength
            
            if request.method == .get || request.method == .head {
                if let headerDate = request.headers.ifModifiedSince {
                    // if date is <= headerDate then not modified
                    let results: [ComparisonResult] = [.orderedAscending, .orderedSame]
                    if results.contains(Calendar.current.compare(fileModDate, to: headerDate, toGranularity: .second)) {
                        return .notModified(headers: headers)
                    }
                    
                } else if let headerDate = request.headers.ifUnmodifiedSince {
                    // if date is >= headerDate then not modified
                    let results: [ComparisonResult] = [.orderedDescending, .orderedSame]
                    if results.contains(Calendar.current.compare(fileModDate, to: headerDate, toGranularity: .second)) {
                        return .notModified(headers: headers)
                    }
                } else if let ifMatch = request.headers.ifMatch {
                    if headers.eTag != ifMatch {
                        return .notModified(headers: headers)
                    }
                } else if let noneMatch = request.headers.ifNoneMatch {
                    if headers.eTag == noneMatch {
                        return .notModified(headers: headers)
                    }
                } else if let headerDate = request.headers.ifRangeDate {
                    if Calendar.current.compare(fileModDate, to: headerDate, toGranularity: .second) != .orderedSame {
                        fileRanges = nil
                    }
                } else if let rangeTag = request.headers.ifRange {
                    if headers.eTag != rangeTag {
                        fileRanges = nil
                    }
                }
            }
            
            
            if fileRanges == nil {
                headers[.acceptRanges] = "bytes"
                return .ok(headers: headers,
                           body: .file(url.path,
                                       contentType: HTTP.Headers.ContentType(resourceType: fileContentResourceType),
                                       fileSize: fileSize,
                                       range: nil,
                                       speedLimit: speedLimit))
            } else if fileRanges!.count == 1 {
                return .partialContent(headers: headers,
                           body: .file(url.path,
                                       contentType: HTTP.Headers.ContentType(resourceType: fileContentResourceType),
                                       fileSize: fileSize,
                                       range: .init(fileRanges![0]),
                                       speedLimit: speedLimit))
            } else {
                
                func writeFileToStream(_ input: LittleWebServerInputStream,
                                       _ output: LittleWebServerOutputStream) throws {
                    
                    let file = try LittleWebServer.ReadableFile(path: url.path)
                    defer {
                        file.close()
                    }
                    
                    let fileTransferBufferSize = Int(speedLimit.bufferSize ??  output.defaultFileTransferBufferSize)
                    
                    let buffer = UnsafeMutablePointerContainer<UInt8>(capacity: fileTransferBufferSize)
                    defer {
                        buffer.deallocate()
                    }
                    
                    
                    var readEndOfFile: Bool = false
                    for i in 0..<fileRanges!.count where !readEndOfFile {
                        let range = fileRanges![i]
                        let boundry = boundryBlocks[i]
                        // Goto the location in file
                        try file.seek(to: range.lowerBound)
                        // Output boundry start (Data before range content)
                        try output.write(boundry)
                        
                        // Write Range Content
                        var currentReadSize: UInt = 0
                        while currentReadSize < range.count {
                            let ret = try file.read(into: buffer, upToCount: fileTransferBufferSize)
                            guard ret > 0 else {
                                readEndOfFile = true
                                break
                            }
                            currentReadSize += ret
                            try output.writeBuffer(buffer, length: Int(ret))
                            speedLimit.doPuase()
                        }
                        
                        // No need to do new line because its included in the boundry data after the first element
                        
                    }
                    // Write new line after last range content
                    try output.writeUTF8Line("")
                    // Add end boundry identifier
                    try output.writeUTF8Line("--\(multiPartBoundry!)--")
                    
                }
                return .partialContent(headers: headers,
                                       body: .custom(writeFileToStream))
            }
             
        }
        
        
        /// Handler used to retrive the access permission for the given request on the provided resource
        /// - Parameters:
        ///   - request: The current request of the resource
        ///   - resource: The file system resource about to be accessed
        /// - Returns: The permissions the request has for the given resoruce
        public typealias SharedDirectoryAccessControl = (_ request: HTTP.Request,
                                                         _ resource: URL) -> ShareDirectoryResourceAccess
        
        /// Handler used to generate a resposne to display a directory listing
        /// - Parameters:
        ///   - request: The current request of the directory resource
        ///   - root: The root directory of the shared path
        ///   - dir: The current directory being displayed
        ///   - webRoot: The context path to the root directory
        ///   - accessControl: Handler used to check if the current request has accessed to each child resource of the current directory
        /// - Returns: Returns the Response to be send to the client
        public typealias ShareDirectoryListingResponder = (_ request: HTTP.Request,
                                                           _ root: URL,
                                                           _ dir: URL,
                                                           _ webRoot: String,
                                                           _ accessControl: @escaping SharedDirectoryAccessControl) -> HTTP.Response
        
        /// The default directory listing response
        /// - Parameters:
        ///   - request: The current request of the directory resource
        ///   - root: The root directory of the shared path
        ///   - dir: The current directory being displayed
        ///   - webRoot: The context path to the root directory
        ///   - accessControl: Handler used to check if the current request has accessed to each child resource of the current directory
        /// - Returns: Returns the Response to be send to the client
        private static func listDirectory(request: HTTP.Request,
                                          fsRoot: URL,
                                          fsDir: URL,
                                          webRoot: String,
                                          accessControl: @escaping SharedDirectoryAccessControl) -> HTTP.Response {
            
            do {
                let fileManager = FileManager.default
                /*
                var contents = try fileManager.contentsOfDirectory(at: fsDir,
                                                                   includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                                                                   options: [.skipsSubdirectoryDescendants,
                                                                             .skipsPackageDescendants])
                */
                // Get the content of the current directory
                var contents = (try fileManager.contentsOfDirectory(atPath: fsDir.path)).map({ return fsDir.appendingPathComponent($0) })
                
                // remove any resources the given user does not have access to
                contents.removeAll(where: { return (accessControl(request, $0) == .none) })
                
                // Get the resource of each item in the current directory
                var contentAttributes: [URL: _URLResourceValues] = [:]
                for resource in contents {
                    if let r = try? resource.resourceValues(using: fileManager) {
                        contentAttributes[resource] = r
                    }
                }
                
                
                // sort folders first
                // sort names case insensative
                contents.sort { lhs, rhs -> Bool in
                    
                    
                    /*
                    let lhsR: URLResourceValues = (try? lhs.resourceValues(forKeys: [.isDirectoryKey])) ?? URLResourceValues()
                    let rhsR: URLResourceValues = (try? rhs.resourceValues(forKeys: [.isDirectoryKey])) ?? URLResourceValues()*/
                    
                    let lhsR: _URLResourceValues = contentAttributes[lhs] ?? _URLResourceValues(lhs)
                    let rhsR: _URLResourceValues = contentAttributes[rhs] ?? _URLResourceValues(rhs)
                    
                    let lhsD: Bool = (lhsR.isDirectory ?? false)
                    let rhsD: Bool = (rhsR.isDirectory ?? false)
                    switch (lhsD, rhsD) {
                        case (true, false): return true
                        case (false, true): return false
                        default: return lhs.path.lowercased() < rhs.path.lowercased()
                    }
                }
                
                // Rsponse support for a json response
                if request.headers.accept?.contains(.json) ?? false {
                    var jsonResponse: String = "{\n"
                    jsonResponse += "\tisRoot: \(fsRoot == fsDir),\n"
                    jsonResponse += "\tchildren: [\n"
                    for (index, resource) in contents.enumerated() {
                        
                        /*let resourceValues: URLResourceValues = (try? resource.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])) ?? URLResourceValues()*/
                        
                        let resourceValues: _URLResourceValues = contentAttributes[resource] ?? _URLResourceValues(resource)
                        
                        // Find out if the given resource is a directory or not
                        var isDir: Bool = false
                        if let vD = resourceValues.isDirectory {
                            isDir = vD
                        } else {
                            _ = fileManager.fileExists(atPath: resource.path, isDirectory: &isDir)
                        }
                        
                        let resourceSize = resourceValues.fileSize ?? -1
                        var comma: String = ""
                        if index < (contents.count - 1) {
                            comma = ","
                        }
                        
                        jsonResponse += """
                                            {
                                                name: "\(resource.lastPathComponent)",
                                                isDir: \(isDir),
                                                size: \(resourceSize)
                                            }\(comma)
                                        
                                        """
                        
                    }
                    
                    jsonResponse += "\t]\n}"
                    return .ok(body: .jsonString(jsonResponse))
                } else {
                    // Standard HTML resposne
                    var htmlResponse: String = "<html><body><ul>"
                    if fsDir != fsRoot {
                        htmlResponse += "<li><a href=\"../\">Parent Directory</a></li>"
                    }
                    for resource in contents {
                        
                        // Find out if the given resource is a directory or not
                        var isDir: Bool = false
                        /*
                        if let vD = (try? resource.resourceValues(forKeys: [.isDirectoryKey]).isDirectory),
                           let v = vD {
                            isDir = v
                        } else {
                            _ = fileManager.fileExists(atPath: resource.path, isDirectory: &isDir)
                        }*/
                        if let vd = contentAttributes[resource],
                           let v = vd.isDirectory {
                            isDir = v
                        } else {
                            _ = fileManager.fileExists(atPath: resource.path, isDirectory: &isDir)
                        }
                        
                        let objectName = resource.lastPathComponent
                        var link = objectName
                        if isDir {
                            link += "/"
                        }
                        
                        htmlResponse += "<li><a href=\"\(link)\">" + objectName + "</a></li>"
                    }
                    
                    
                    htmlResponse += "</ul></body></html>"
                    
                    return .ok(body: .html(htmlResponse))
                }
            } catch {
                /// There was an error.  Lets send an internal error response
                return Thread.current.littleWebServerDetails.routeController!.internalError(for: request, error: error)
            }
        }
        
        /// Handler used to generate a resource not found resposne
        /// - Parameters:
        ///   - request: The current request of the resource
        ///   - controller: The route controller the request as processed on
        /// - Returns: Returns the response body for a resource not found
        public typealias ShareDirectoryResourceNotFoundMessageResponder = (_ request: HTTP.Request,
                                                                       _ controller: Routing.Requests.RouteController) -> HTTP.Response.Body
        /// Returns the default content for a file not found message
        /// - Parameters:
        ///   - request: The current request of the resource
        ///   - controller: The route controller the request as processed on
        /// - Returns: Returns the response body for a resource not found
        private static func defaultSharedResourceNotFoundMessage(_ request: HTTP.Request,
                                                             _ controller: Routing.Requests.RouteController) -> HTTP.Response.Body {
            return controller.resourceNotFoundHandler(request).body
        }
        /// Handler used to generate a Directory Listing Not Supported response
        /// - Parameters:
        ///   - request: The current request of the resource
        /// - Returns: Returns the response body for a Directory Listing Not Supported
        public typealias ShareDirectoryNoDirectoryListingMessageResponder = (_ request:HTTP.Request) -> HTTP.Response.Body
        
        /// Returns the default content for Directory Browsing Unsupported
        /// - Parameters:
        ///   - request: The current request of the resource
        /// - Returns: Returns the response body for a Directory Listing Not Supported
        private static func defaultSharedNoDirectoryListing(_ request:HTTP.Request) -> HTTP.Response.Body {
            return LittleWebServer.basicHTMLBodyMessage(message: "Directory Browsing Not Supported")
        }
        
        /// Handler used to returns the content for No Access response
        /// - Parameters:
        ///   - request: The current request of the resource
        /// - Returns: Returns the response body for a No Access message
        public typealias ShareDirectoryNoAccessMessageResponder = (_ request: HTTP.Request) -> HTTP.Response.Body
        /// Returns the default content for No Access response
        /// - Parameters:
        ///   - request: The current request of the resource
        /// - Returns: Returns the response body for a No Access message
        private static func defaultNoAccess(_ request:HTTP.Request) -> HTTP.Response.Body {
            return LittleWebServer.basicHTMLBodyMessage(message: "You do not have access to the given resource")
        }
        
        /// Share a file system resource at the given path
        /// - Parameters:
        ///   - resource: The resource (File or Directory) to share
        ///   - request: The current request
        ///   - defaultIndexFiles: The default index files used when sharing directories
        ///   - allowDirectoryBrowsing: Indicator if directory browsing is allowed
        ///   - treatForbiddenAsNotFound: Indicator if trating access forbidded should be treated as not found
        ///   - accessControl: Access control handler used to see if the requet has access to a resource
        ///   - speedLimiter: Speed limiter used to control how fast files are downloaded
        ///   - directoryListing: Handler used to generate output of the a given directory
        ///   - fileNotFoundMessage: Handler used to generate the not found response
        ///   - noDirBrowsingMessage: Handler used to generate the directory browsing not supported response
        ///   - noAccessMessage: Handler used to generate the no access response
        /// - Returns: Returns a handler method for added all the Request/Response handlers used for sharing a resource
        public static func share(resource: @escaping (_ request: HTTP.Request) -> URL?,
                                 defaultIndexFiles: [String] = [],
                                 allowDirectoryBrowsing: Bool = true,
                                 treatForbiddenAsNotFound: Bool = false,
                                 accessControl: @escaping SharedDirectoryAccessControl = { _, _ in return .readonly },
                                 speedLimiter: @escaping FileTransferSpeedHandler = { _, _ in return .unlimited},
                                 directoryListing: ShareDirectoryListingResponder? = nil,
                                 fileNotFoundMessage: ShareDirectoryResourceNotFoundMessageResponder? = nil,
                                 noDirBrowsingMessage: ShareDirectoryNoDirectoryListingMessageResponder? = nil,
                                 noAccessMessage: ShareDirectoryNoAccessMessageResponder? = nil) -> (LittleWebServerRoutePathConditions, LittleWebServer.Routing.Requests.RouteController) -> Void {
            
            let fileNotFound = fileNotFoundMessage ?? FSSharing.defaultSharedResourceNotFoundMessage
            let noDirBrowsing = noDirBrowsingMessage ?? FSSharing.defaultSharedNoDirectoryListing
            let noAccess = noAccessMessage ?? FSSharing.defaultNoAccess
            let directoryListing = directoryListing ?? FSSharing.listDirectory
            
            func shareHandler(request: HTTP.Request, controller: Routing.Requests.RouteController) -> HTTP.Response {
                guard let path = request.identities["path"] as? String else {
                    // Should never get here
                    return controller.internalError(for: request, message: "Unable to find path identifier")
                }
                
                guard let fsRoot = resource(request) else {
                    return .notFound(body: fileNotFound(request, controller))
                }
                
                var webRoot = request.contextPath
                if let r = webRoot.range(of: path, options: .backwards) {
                    webRoot = String(webRoot[..<r.lowerBound])
                }
                
                var fsLocation = fsRoot
                var appendPath = path
                if appendPath.hasPrefix("/") { appendPath.removeFirst() }
                if !appendPath.isEmpty { fsLocation.appendPathComponent(appendPath) }
                
                
                let fileAccess = accessControl(request, fsLocation)
                guard fileAccess != .none else {
                    if treatForbiddenAsNotFound {
                        return .notFound(body: fileNotFound(request, controller))
                    } else {
                        return .forbidden(body: noAccess(request))
                    }
                }
                
                let defaultGetResponesMethods: [HTTP.Method] = [.head, .get]
                //let defaultUpdateResponseMethod: [HTTP.Method] = [.put, .patch]
                if defaultGetResponesMethods.contains(request.method) {
                    var isDir: Bool = false
                    guard FileManager.default.fileExists(atPath: fsLocation.path, isDirectory: &isDir) else {
                        return .notFound(body: fileNotFound(request, controller))
                    }
                    
                    if isDir {
                        for index in defaultIndexFiles {
                            let indexLocation = fsLocation.appendingPathComponent(index)
                            if FileManager.default.fileExists(atPath: indexLocation.path) {
                                fsLocation = indexLocation
                                isDir = false
                                break
                            }
                        }
                    }
                    
                    if !isDir {
                        do {
                            return try sendFile(at: fsLocation,
                                                from: request,
                                                in: controller,
                                                speedLimit: speedLimiter(request, fsLocation))
                            
                        } catch {
                            return controller.internalError(for: request, error: error)
                        }
                    } else {
                        guard allowDirectoryBrowsing else {
                            return .ok(body: noDirBrowsing(request))
                        }
                        return directoryListing(request, fsRoot, fsLocation, webRoot, accessControl)
                    }
                } else {
                    return .forbidden(body: noAccess(request))
                }
            }
            
            return { path, controller in
                
                var pth = path
                if pth.last!.identifier == nil {
                    pth.append(":path{**}")
                }
                guard let ident = pth.last?.identifier,
                      ident == "path" else {
                    fatalError("Route Path must not end in an identifier or must have the identifier of 'path'")
                }
                
                controller[pth] = shareHandler
                
            }
        }
        
        /// Share a file system resource at the given path
        /// - Parameters:
        ///   - resource: The resource (File or Directory) to share
        ///   - request: The current request
        ///   - defaultIndexFiles: The default index files used when sharing directories
        ///   - allowDirectoryBrowsing: Indicator if directory browsing is allowed
        ///   - treatForbiddenAsNotFound: Indicator if trating access forbidded should be treated as not found
        ///   - accessControl: Access control handler used to see if the requet has access to a resource
        ///   - speedLimiter: Speed limiter used to control how fast files are downloaded
        ///   - directoryListing: Handler used to generate output of the a given directory
        ///   - fileNotFoundMessage: Handler used to generate the not found response
        ///   - noDirBrowsingMessage: Handler used to generate the directory browsing not supported response
        ///   - noAccessMessage: Handler used to generate the no access response
        /// - Returns: Returns a handler method for added all the Request/Response handlers used for sharing a resource
        public static func share(resource: @escaping (_ request: HTTP.Request) -> URL?,
                                 defaultIndexFiles: [String] = [],
                                 allowDirectoryBrowsing: Bool = true,
                                 treatForbiddenAsNotFound: Bool = false,
                                 accessControl: @escaping SharedDirectoryAccessControl = { _, _ in return .readonly },
                                 speedLimiter: LittleWebServer.FileTransferSpeedLimiter,
                                 directoryListing: ShareDirectoryListingResponder? = nil,
                                 fileNotFoundMessage: ShareDirectoryResourceNotFoundMessageResponder? = nil,
                                 noDirBrowsingMessage: ShareDirectoryNoDirectoryListingMessageResponder? = nil,
                                 noAccessMessage: ShareDirectoryNoAccessMessageResponder? = nil) -> (LittleWebServerRoutePathConditions, LittleWebServer.Routing.Requests.RouteController) -> Void {
            return self.share(resource: resource,
                              defaultIndexFiles: defaultIndexFiles,
                              allowDirectoryBrowsing: allowDirectoryBrowsing,
                              treatForbiddenAsNotFound: treatForbiddenAsNotFound,
                              accessControl: accessControl,
                              speedLimiter: { _, _ in return speedLimiter },
                              directoryListing: directoryListing,
                              fileNotFoundMessage: fileNotFoundMessage,
                              noDirBrowsingMessage: noDirBrowsingMessage,
                              noAccessMessage: noAccessMessage)
        }
            
            
        /// Share a file system resource at the given path
        /// - Parameters:
        ///   - resource: The resource (File or Directory) to share
        ///   - defaultIndexFiles: The default index files used when sharing directories
        ///   - allowDirectoryBrowsing: Indicator if directory browsing is allowed
        ///   - treatForbiddenAsNotFound: Indicator if trating access forbidded should be treated as not found
        ///   - speedLimiter: Speed limiter used to control how fast files are downloaded
        ///   - directoryListing: Handler used to generate output of the a given directory
        ///   - fileNotFoundMessage: Handler used to generate the not found response
        ///   - noDirBrowsingMessage: Handler used to generate the directory browsing not supported response
        /// - Returns: Returns a handler method for added all the Request/Response handlers used for sharing a resource
        public static func share(resource: URL,
                                 defaultIndexFiles: [String] = [],
                                 allowDirectoryBrowsing: Bool = true,
                                 treatForbiddenAsNotFound: Bool = false,
                                 speedLimiter: @escaping FileTransferSpeedHandler = { _, _ in return .unlimited},
                                 directoryListing: ShareDirectoryListingResponder? = nil,
                                 fileNotFoundMessage: ShareDirectoryResourceNotFoundMessageResponder? = nil,
                                 noDirBrowsingMessage: ShareDirectoryNoDirectoryListingMessageResponder? = nil) -> (LittleWebServerRoutePathConditions, LittleWebServer.Routing.Requests.RouteController) -> Void {
            
            
            return self.share(resource: { _ in return resource },
                              defaultIndexFiles: defaultIndexFiles,
                              allowDirectoryBrowsing: allowDirectoryBrowsing,
                              treatForbiddenAsNotFound: treatForbiddenAsNotFound,
                              speedLimiter: speedLimiter,
                              directoryListing: directoryListing,
                              fileNotFoundMessage: fileNotFoundMessage,
                              noDirBrowsingMessage: noDirBrowsingMessage)
            
        }
        
        /// Share a file system resource at the given path
        /// - Parameters:
        ///   - resource: The resource (File or Directory) to share
        ///   - defaultIndexFiles: The default index files used when sharing directories
        ///   - allowDirectoryBrowsing: Indicator if directory browsing is allowed
        ///   - treatForbiddenAsNotFound: Indicator if trating access forbidded should be treated as not found
        ///   - speedLimiter: Speed limiter used to control how fast files are downloaded
        ///   - directoryListing: Handler used to generate output of the a given directory
        ///   - fileNotFoundMessage: Handler used to generate the not found response
        ///   - noDirBrowsingMessage: Handler used to generate the directory browsing not supported response
        /// - Returns: Returns a handler method for added all the Request/Response handlers used for sharing a resource
        public static func share(resource: URL,
                                 defaultIndexFiles: [String] = [],
                                 allowDirectoryBrowsing: Bool = true,
                                 treatForbiddenAsNotFound: Bool = false,
                                 speedLimiter: LittleWebServer.FileTransferSpeedLimiter,
                                 directoryListing: ShareDirectoryListingResponder? = nil,
                                 fileNotFoundMessage: ShareDirectoryResourceNotFoundMessageResponder? = nil,
                                 noDirBrowsingMessage: ShareDirectoryNoDirectoryListingMessageResponder? = nil) -> (LittleWebServerRoutePathConditions, LittleWebServer.Routing.Requests.RouteController) -> Void {
            return self.share(resource: resource,
                              defaultIndexFiles: defaultIndexFiles,
                              allowDirectoryBrowsing: allowDirectoryBrowsing,
                              treatForbiddenAsNotFound: treatForbiddenAsNotFound,
                              speedLimiter: { _, _ in return speedLimiter },
                              directoryListing: directoryListing,
                              fileNotFoundMessage: fileNotFoundMessage,
                              noDirBrowsingMessage: noDirBrowsingMessage)
        }
    }
}
