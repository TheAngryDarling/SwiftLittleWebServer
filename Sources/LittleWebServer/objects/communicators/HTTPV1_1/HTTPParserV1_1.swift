//
//  HTTPParserV1_1.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-07-31.
//

import Foundation

internal struct HTTPParserV1_1 {
    private init() { }
    
    /// Reads one HTTP line from the connection.
    /// This means that it will keep reading 1 byte at
    /// a time until it reaches the buffer has a suffix of \r\n
    static func readHTTPLine(from client: LittleWebServerClient) throws -> String {
        return try autoreleasepool {
            var httpLineData = Data()
            var readByte: UInt8 = 0
            repeat {
                
                guard (try client.readByte(into: &readByte)) else {
                    throw LittleWebServerClientHTTPReadError.invalidRead(expectedBufferSize: 1, actualBufferSize: 0)
                }
                //print(readByte)
                httpLineData.append(readByte)
                
            } while !httpLineData.hasSuffix(LittleWebServer.CRLF_DATA) && client.isConnected
            
            // Remove CR+LF from end of bytes
            httpLineData.removeLast(2)
            
            // Try creating string
            guard let rtn = String(data: httpLineData, encoding: .utf8) else {
                throw LittleWebServerClientHTTPReadError.unableToCreateString(from: httpLineData)
            }
            
            return rtn
        }
    }
    /// Reads the first line of the HTTP request.
    /// This includes the method, context path and the HTTP version used
    static func readRequestHead(from client: LittleWebServerClient) throws -> LittleWebServer.HTTP.Request.Head {
        let httpHeadLine = try self.readHTTPLine(from: client)
        //print("Request Head '\(httpHeadLine)'")
        guard let rtn = LittleWebServer.HTTP.Request.Head.parse(httpHeadLine) else {
            throw LittleWebServerClientHTTPReadError.invalidRequestHead(httpHeadLine)
        }
        return rtn
    }
    /// Reads the HTTP Headers that come after the HTTP head
    /// Each HTTP Line it reads should be {Header Name}: {Header Value}\r\n
    /// A trailing \r\n is expected to indicate that the headers are finished
    static func readRequestHeaders(from client: LittleWebServerClient) throws -> LittleWebServer.HTTP.Request.Headers {
        var rtn = LittleWebServer.HTTP.Request.Headers()
        
        // Read the first header or empty string meaning no headers
        var workingLine: String = try self.readHTTPLine(from: client)
        while !workingLine.isEmpty {
            
            if let r = workingLine.range(of: ": ") {
                let key = String(workingLine[..<r.lowerBound])
                let val = String(workingLine[r.upperBound...])
                rtn[.init(properString: key)] = val
            } else {
                rtn[.init(properString: workingLine)] = ""
            }
            
            workingLine = try self.readHTTPLine(from: client)
            
        }
        
        return rtn
    }
    
    
    /// Parse a request
    /// - Parameters:
    ///   - scheme: The HTTP Request Scheme
    ///   - head: The HTTP Request Head Line
    ///   - headers: The HTTP Request Headers
    ///   - bodyStream: The HTTP Request  Body Input Stream
    ///   - uploadedFiles: Refernece to any form post files that were parsed
    ///   - tempLocation: The location to save uplaoded files
    /// - Returns: Returns a new HTTP Request
    internal static func parseRequest(scheme: String,
                                      head: LittleWebServer.HTTP.Request.Head,
                                      headers: LittleWebServer.HTTP.Request.Headers,
                                      bodyStream: HTTPLittleWebServerInputStreamV1_1,
                                      uploadedFiles: inout  [LittleWebServer.HTTP.Request.UploadedFileReference],
                                      tempLocation: URL) throws -> LittleWebServer.HTTP.Request {
        var queryItems = head.queryItems
        //let headers = try client.readRequestHeaders()
        //let uploadedFiles: [UploadedFileReference] = []
        
        
        // Parse form post here
        if headers.contentType ~= .urlEncodedForm {
            let queryString: String
            if let ctl = headers.contentLength {
                let dta = try bodyStream.read(exactly: Int(ctl))
                let enc = headers.contentType?.characterEncoding ?? .utf8
                guard var s = String(data: dta, encoding: enc) else {
                    throw LittleWebServer.HTTP.Request.Error.unableToDecodeBodyParameters
                }
                while s.hasSuffix("\r\n") { s.removeLast(2) }
                queryString = s
            } else {
                var dta = Data()
                while !dta.hasSuffix(LittleWebServer.CRLF_DATA) {
                    let b = try bodyStream.readByte()
                    dta.append(b)
                }
                
                let enc = headers.contentType?.characterEncoding ?? .utf8
                guard let s = String(data: dta, encoding: enc) else {
                    throw LittleWebServer.HTTP.Request.Error.unableToDecodeBodyParameters
                }
                queryString = s
            }
            
            let qItems = queryString.split(separator: "&").map(String.init)
            for qItem in qItems {
                guard let r = qItem.range(of: "=") else {
                    queryItems.append(URLQueryItem(name: qItem, value: ""))
                    continue
                }
                
                let qName = String(qItem[qItem.startIndex..<r.lowerBound])
                let qValue: String = String(qItem[r.upperBound..<qItem.endIndex])
                
                queryItems.append(URLQueryItem(name: qName, value: qValue.replacingOccurrences(of: "+", with: " ")))
                
            }
        /*} else if let boundary = headers.contentType?.multiPartBoundary,
                  headers.contentType?.mediaType == .multiPartForm {*/
            } else if headers.contentType ~= .multiPartForm,
                      let boundary = headers.contentType?.multiPartBoundary {
            
            let expectedBoundaryIdentifier = "--" + boundary
            
            var boundaryLine = try bodyStream.readUTF8Line()
            guard boundaryLine == expectedBoundaryIdentifier else {
                throw LittleWebServer.HTTP.Request.Error.unableToFindBoundaryIdentifier(boundary)
            }
            let boundaryLineBytes = Array(expectedBoundaryIdentifier.utf8)
            
            func processRestOfPartBlock(_ onReadBytes: ([UInt8]) throws -> Void = { _ in return }) throws {
                
                func matchingSequence(lookingAt: [UInt8], lookingFor: [UInt8]) -> Int? {
                    precondition(lookingAt.count == lookingFor.count,
                                 "Arrays must be same size")
                    
                    
                    guard lookingAt != lookingFor else { return nil }
                    
                    guard let firstByteIndex = lookingAt.firstIndex(of: lookingFor[0]) else {
                        return lookingAt.count
                    }
                    
                    guard lookingAt.count > 1 else {
                        // if we are down to one byte and they didn't match, then
                        // we report we need to replace it
                        return 1
                    }
                    
                    let innerAt = Array(lookingAt.suffix(from: firstByteIndex + 1))
                    
                    let innerFor = Array(lookingFor[0..<innerAt.count])
                    
                    let subCount = matchingSequence(lookingAt: innerAt, lookingFor: innerFor)
                    
                    let rtn = firstByteIndex + (subCount ?? 0)
                    guard rtn != 0 else {
                        return nil
                    }
                    
                    return rtn
                    
                }
                //try autoreleasepool {
                    var buffer = Array<UInt8>(repeating: 0, count: boundaryLineBytes.count)
                    try bodyStream.read(&buffer, exactly: buffer.count)
                    
                
                    
                    // In the end this should old the \r\n from the end of the bock
                    var lastTwoBytes = Array<UInt8>(repeating: 0, count: 2)
                    var lastTwoBytesSet: Bool = false
                    while let needToRead = matchingSequence(lookingAt: buffer,
                                                            lookingFor: boundaryLineBytes) {
                        if lastTwoBytesSet {
                            try onReadBytes(lastTwoBytes)
                        }
                        if needToRead < buffer.count {
                            try onReadBytes(Array(buffer[0..<needToRead-2]))
                            lastTwoBytes = Array(buffer[(needToRead-2)..<needToRead])
                            for i in needToRead..<buffer.count {
                                buffer[i - needToRead] = buffer[i]
                            }
                            for i in (buffer.count - needToRead)..<buffer.count {
                                buffer[i] = 0
                            }
                            try bodyStream.read(&buffer[(buffer.count - needToRead)], exactly: needToRead)
                            
                        } else {
                            try onReadBytes(Array(buffer[0..<buffer.count-2]))
                            lastTwoBytes = Array(buffer.suffix(2))
                            
                            try bodyStream.read(&buffer, exactly: buffer.count)
                            
                            
                        }
                        lastTwoBytesSet = true
                        
                    }
                    /*
                    /*var outerBuffer = Array<UInt8>(repeating: 0, count: 2)
                    var outCount: Int = 0*/
                    while buffer != boundaryLineBytes {
                        /*outCount += 1
                        if outCount > 2 {
                            try onByteRead(outerBuffer[0])
                        }
                        outerBuffer[0] = outerBuffer[1]
                        outerBuffer[1] = buffer[0]*/
                        try onByteRead(buffer[0])
                        for i in 1..<buffer.count {
                            
                            buffer[i-1] = buffer[i] // shift everything to the left one byte
                        }
                        // Read next byte
                        let ret = try bodyStream.readBuffer(into: &buffer[buffer.count - 1], count: 1)
                        guard ret == 1 else {
                            throw Error.noMoreDataAvailableInStream
                        }
                    }
                    */
                    // signal last bytes of block
                    /*for i in 0..<outerBuffer.count {
                        try onByteRead(outerBuffer[i])
                    }*/
                    
                    var wasEndBoundary: Bool = false
                    var trail = try bodyStream.read(exactly: 2) // trying to read either -- or \r\n
                    if trail == Data(Array("--".utf8)) {
                        wasEndBoundary = true
                        trail = try bodyStream.read(exactly: 2) // trying to read \r\n
                    }
                    
                    guard trail == LittleWebServer.CRLF_DATA else {
                        throw LittleWebServer.HTTP.Request.Error.unexpectedDataAfterBoundary(trail, wasEndBoundary: wasEndBoundary)
                    }
                    
                //}
                
            }
            
            
            while boundaryLine == expectedBoundaryIdentifier &&
                  !(bodyStream.endOfStream ?? false) {
                try autoreleasepool {
                    let contentDispositionString = try bodyStream.readUTF8Line()
                    
                    guard let contentDisposition = LittleWebServer.HTTP.Headers.ContentDisposition(contentDispositionString) else {
                        throw LittleWebServer.HTTP.Request.Error.invalidContentDispositionLine(contentDispositionString)
                    }
                    var partContentType: LittleWebServer.HTTP.Headers.ContentType? = nil
                    var nextLine = try bodyStream.readUTF8Line()
                    while !nextLine.isEmpty {
                        if nextLine.hasPrefix("Content-Type: ") {
                            nextLine.removeFirst("Content-Type: ".count)
                            partContentType = LittleWebServer.HTTP.Headers.ContentType(nextLine)
                            nextLine = try bodyStream.readUTF8Line()
                        }
                    }
                    /*// Read new line
                    guard nextLine.isEmpty else {
                        throw Error.expectingNewLine(found: bytes)
                    }*/
                    
                    if contentDisposition.type == .formData {
                        if contentDisposition.filename == nil &&
                           contentDisposition.filenameB == nil {
                            var fieldValue: String = ""
                            var currentLine = try bodyStream.readUTF8Line()
                            while currentLine != expectedBoundaryIdentifier &&
                                  currentLine != "\(expectedBoundaryIdentifier)--" &&
                                  !(bodyStream.endOfStream ?? false) {
                                if !fieldValue.isEmpty { fieldValue += "\n" }
                                fieldValue += currentLine
                                currentLine = try bodyStream.readUTF8Line()
                            }
                            boundaryLine = currentLine
                        } else if let filePath = (contentDisposition.filenameB ?? contentDisposition.filename) {
                            let fileURL = tempLocation.appendingPathComponent(UUID().uuidString)
                            guard FileManager.default.createFile(atPath: fileURL.path, contents: nil) else {
                                throw LittleWebServer.HTTP.Request.Error.unableToCreateFile(fileURL)
                            }
                            let fileHandle = try FileHandle(forWritingTo: fileURL)
                            
                            uploadedFiles.append(.init(path: filePath,
                                                       location: fileURL,
                                                       contentType: partContentType))
                            var removeFile: Bool = false
                            defer {
                                try? fileHandle.closeHandle()
                                if removeFile {
                                    try? FileManager.default.removeItem(at: fileURL)
                                }
                            }
                            
                            do {
                                // Copy each byte processed into the file
                                try processRestOfPartBlock {
                                    try fileHandle.write($0, count: $0.count)
                                }
                            } catch {
                                removeFile = true
                                throw error
                            }
                            
                            
                            //print("Processed file '\(fileURL.path)'")
                            
                            
                        }
                        
                    
                    } else {
                        
                        // Skipping over this part since we don't know how to handle it
                        try processRestOfPartBlock()
                        
                    }
                    
                }
                
                
            }
            
            
        }
        
        let usableInputStream: LittleWebServerInputStream = bodyStream
        
        /*if ["GET", "DELETE", "TRACE", "OPTIONS", "HEAD"].contains(head.method.rawValue.uppercased()) {
            usableInputStream = LittleWebServerEmptyInputStream()
        }*/
        
        return .init(scheme: scheme,
                     method: head.method,
                     contextPath: head.contextPath,
                     urlQuery: head.query,
                     version: head.version,
                     headers: headers,
                     queryItems: queryItems,
                     uploadedFiles: uploadedFiles,
                     inputStream: usableInputStream)
        
    }
    
    /// Parse a request
    /// - Parameters:
    ///   - scheme: The HTTP Request Scheme
    ///   - uploadedFiles: Refernece to any form post files that were parsed
    ///   - tempLocation: The location to save uplaoded files
    ///   - client: The client connection for the incomming request
    /// - Returns: Returns a new HTTP Request
    internal static func parseRequest(scheme: String,
                                      uploadedFiles: inout  [LittleWebServer.HTTP.Request.UploadedFileReference],
                                      tempLocation: URL,
                                      from client: LittleWebServerClient) throws -> LittleWebServer.HTTP.Request {
        
        return try self.parseRequest(scheme: scheme,
                                     head: try self.readRequestHead(from: client),
                                     headers: try self.readRequestHeaders(from: client),
                                     bodyStream: HTTPLittleWebServerInputStreamV1_1(client: client),
                                     uploadedFiles: &uploadedFiles,
                                     tempLocation: tempLocation)
        
    }
}
