//
//  WebSockets.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-08.
//

import Foundation

public extension LittleWebServer {
    /// Methods / Logic used for WebSockets
    struct WebSocket { private init() { }
    
        /// A code that indicates why a WebSocket connection closed.
        public enum CloseCode: Int {
            /// A code that indicates the connection is still open.
            case invalid = 0
            /// A reserved code that indicates the connection closed without a close control frame.
            case abnormalClosure = 1006
            /// A code that indicates an endpoint is going away.
            case goingAway = 1001
            /// A code that indicates the server terminated the connection because it encountered an unexpected condition.
            case internalServerError = 1011
            /// A code that indicates the server terminated the connection because it received data inconsistent with the message’s type.
            case invalidFramePayloadData = 1007
            /// A code that indicates the client terminated the connection because the server didn’t negotiate a required extension.
            case mandatoryExtensionMissing = 1010
            /// A code that indicates an endpoint is terminating the connection because it received a message too big for it to process.
            case messageTooBig = 1009
            /// A reserved code that indicates an endpoint expected a status code and didn’t receive one.
            case noStatusReceived = 1005
            /// A code that indicates normal connection closure.
            case normalClosure = 1000
            /// A code that indicates an endpoint terminated the connection because it received a message that violates its policy.
            case policyViolation = 1008
            /// A code that indicates an endpoint terminated the connection due to a protocol error.
            case protocolError = 1002
            /// A reserved code that indicates the connection closed due to the failure to perform a TLS handshake.
            case tlsHandshakeFailure = 1015
            /// A code that indicates an endpoint terminated the connection after receiving a type of data it can’t accept.
            case unsupportedData = 1003
            
        }
        /// WebSocket Events
        public enum Event {
            case connected, disconnected
            case close(CloseCode, reason: [UInt8])
            case text(String)
            case binary([UInt8])
            case pong([UInt8])
            
            public var isCloseEvent: Bool {
                guard case .close = self else { return false }
                return true
            }
            
            /*internal init(event: LittleWebServer.WebSocketClient.Frame.Event,
                          payload: [UInt8]) throws {
                switch event {
                case .close: self = .close
                case .
                
                }
            }*/
        }
        
        public class Client {
            
            enum Error: Swift.Error {
                case invalidFrameCode(UInt8)
                case controlFramesMustNotBeFragmented
                case aClientMustMaskAllFramesThatItSendsToTheServer
                case noValidEventsRead
                case expectedFrameEvent(Frame.Event, found: Frame)
                case unexpectedFrame(Frame)
                case invalidTextFrame(Frame)
            }
            /// WebSocket Frame
            internal struct Frame: CustomStringConvertible {
                /// Frame Event
                public enum Event: UInt8 {
                    case `continue` = 0x00
                    case text = 0x01
                    case binary = 0x02
                    case close = 0x08
                    case ping = 0x09
                    case pong = 0x0A
                    
                    internal var isControlEvent: Bool {
                        switch self {
                            case .ping, .pong, .close: return true
                            default: return false
                        }
                    }
                }
                
                /// The frame event type
                public let event: Event
                /// Indicator if the frame is finished
                public internal(set) var fin: Bool
                /// Reserved for future use
                public internal(set) var rsv1: Bool
                /// Reserved for future use
                public internal(set) var rsv2: Bool
                /// Reserved for future use
                public internal(set) var rsv3: Bool
                /// Reserved for future use.  This is an array of rsv1, rsv2, rsv3
                public var rsv: [Bool] { return [self.rsv1, self.rsv2, self.rsv3] }
                /// The frame payload
                public internal(set) var payload: [UInt8]
                
                public var description: String {
                    var rtn: String = "\(type(of: self)) ("
                    
                    rtn += "event: .\(self.event)"
                    rtn += ", fin: \(self.fin)"
                    rtn += ", rsv1: \(self.rsv1)"
                    rtn += ", rsv2: \(self.rsv2)"
                    rtn += ", rsv3: \(self.rsv3)"
                    
                    if self.payload.count > 0 {
                        rtn += ", payload: \(self.payload)"
                        
                        if case .text = self.event,
                           let text = String(bytes: self.payload, encoding: .utf8) {
                            rtn += ", text: \"\(text)\""
                        }
                    } else {
                        rtn += ", payload: EMPTY"
                    }
                    
                    rtn += ")"
                    return rtn
                }
                
                /// Create new frame
                /// - Parameters:
                ///   - event: Frame event type
                ///   - fin: Indicator if frame is finished
                ///   - rsv1: Reserved 1 (Default: false)
                ///   - rsv2: Reserved 2 (Default: false)
                ///   - rsv3: Reserved 3 (Default: false)
                ///   - payload: Frame payload
                public init(event: Event,
                            fin: Bool,
                            rsv1: Bool = false,
                            rsv2: Bool = false,
                            rsv3: Bool = false,
                            payload: [UInt8]) {
                    self.event = event
                    self.fin = fin
                    self.rsv1 = rsv1
                    self.rsv2 = rsv2
                    self.rsv3 = rsv3
                    self.payload = payload
                }
                
                public init() {
                    self.init(event: .close,
                              fin: false,
                              payload: [])
                }
                
                
            }
            
            /// Indicator if the close frame has already been sent
            public private(set) var hasSentClosed: Bool = false
            /// The request used to initiate the web socket connection
            public let request: HTTP.Request
            /// The web socket input stream
            private let inputStream: LittleWebServerInputStream
            /// The web socket output stream
            private let outputStream: LittleWebServerOutputStream
            
            /// Create new web socket client
            /// - Parameters:
            ///   - request: The request used to initiate the web socket connection
            ///   - inputStream: The web socket input stream
            ///   - outputStream: The web socket output stream
            internal init(request: HTTP.Request,
                          inputStream: LittleWebServerInputStream,
                          outputStream: LittleWebServerOutputStream) {
                self.request = request
                self.inputStream = inputStream
                self.outputStream = outputStream
            }
            
            private func encodeMaskAndLength(masked: Bool, payloadLength: UInt) -> [UInt8] {
                let mask = UInt8(masked ? 0x80 : 0x00)
                var rtn: [UInt8] = []
                
                let rawPayloadLengthBytesToCopy: Int
                switch payloadLength {
                case 0...125:
                    rtn.append(mask | UInt8(payloadLength))
                    rawPayloadLengthBytesToCopy = 0
                case 126...UInt(UInt16.max):
                    rtn.append(mask | 0x7E)
                    rawPayloadLengthBytesToCopy = 2
                default:
                    rtn.append(mask | 0x7E)
                    rawPayloadLengthBytesToCopy = 8
                }
                
                if rawPayloadLengthBytesToCopy > 0 {
                    var littlePayloadLength = payloadLength
                    
                    withUnsafeBytes(of: &littlePayloadLength) {
                        let startCopyIndex = $0.count - rawPayloadLengthBytesToCopy
                        for i in startCopyIndex..<$0.count {
                            rtn.append($0[i])
                        }
                        
                    }
                }
                return rtn
            }
            
            /// Write a web socket frame
            internal func writeFrame<C>(event: Frame.Event,
                                        payload: C,
                                        fin: Bool = true) throws where C: Collection, C.Element == UInt8 {
                let eventAndOptCode = UInt8(fin ? 0x80 : 0x00) | event.rawValue
                let maskAndPayloadSizeBlock = encodeMaskAndLength(masked: false, payloadLength: UInt(payload.count))
                
                try self.outputStream.write([eventAndOptCode])
                try self.outputStream.write(maskAndPayloadSizeBlock)
                try self.outputStream.write(Array(payload))
                
            }
            /// Write a pong response
            internal func writePong<C>(_ payload: C) throws where C: Collection, C.Element == UInt8 {
                try self.writeFrame(event: .pong, payload: payload)
            }
            
            /// Write a close evnt with no close code
            internal func writeClose(payload: [UInt8] = []) throws {
                self.hasSentClosed = true
                try self.writeFrame(event: .close, payload: payload)
            }
            /// Write a close event to the client
            /// - Parameters:
            ///   - closeCode: The close code
            ///   - reason: Additional reason data for closing
            public func writeClose(_ closeCode: CloseCode, reason: [UInt8] = []) throws {
                var payload = reason
                var cc16 = UInt16(closeCode.rawValue).bigEndian
                let intSize = MemoryLayout.size(ofValue: cc16)
                let ccBytes: [UInt8] = withUnsafePointer(to: &cc16) {
                    return $0.withMemoryRebound(to: UInt8.self, capacity: intSize) {
                        let buffer = UnsafeBufferPointer(start: $0, count: intSize)
                        return Array<UInt8>(buffer)

                    }
                }
                payload.insert(contentsOf: ccBytes, at: 0)
                try self.writeClose(payload: payload)
            }
            
            /// Write a close event to the client if it hasn't already been sent
            internal func writeCloseIfNotSent(_ closeCode: CloseCode, reason: [UInt8] = []) throws {
                guard !self.hasSentClosed else { return }
                try self.writeClose(closeCode, reason: reason)
            }
            
            /// Write the bytes to the client
            public func writeBinary<C>(_ payload: C) throws where C: Collection, C.Element == UInt8 {
                try self.writeFrame(event: .binary, payload: payload)
            }
            /// Write the text to the client
            public func writeText(_ text: String) throws {
                try self.writeFrame(event: .text, payload: text.utf8)
            }
            
            /// Read the next frame
            internal func readFrame() throws -> Frame {
                return try autoreleasepool {
                    let frameFirstByte = try self.inputStream.readByte()
                    // read flags
                    let fin = frameFirstByte.contains(bit: 0)
                    let rsv1 = frameFirstByte.contains(bit: 1)
                    let rsv2 = frameFirstByte.contains(bit: 2)
                    let rsv3 = frameFirstByte.contains(bit: 3)
                    
                    let frameCode = frameFirstByte.bits(from: 4) //(frameFirstByte & 0xF) // Keeps only left 4 bits
                    
                    guard let frameEvent = Frame.Event(rawValue: frameCode) else {
                        try? self.writeClose(.unsupportedData)
                        throw Error.invalidFrameCode(frameCode)
                    }
                    
                    if !fin && frameEvent.isControlEvent {
                        try? self.writeClose(.invalidFramePayloadData)
                        throw Error.controlFramesMustNotBeFragmented
                    }
                    
                    let maskAndPayloadSize = try self.inputStream.readByte()
                    
                    guard maskAndPayloadSize.contains(bit: 0) else {
                        try? self.writeClose(.invalidFramePayloadData)
                        throw Error.aClientMustMaskAllFramesThatItSendsToTheServer
                    }
                    
                    var payloadSize = UInt(maskAndPayloadSize.bits(from: 1))
                    if payloadSize >= 0x7E {
                        var payloadByteSize = 2 // assume payload size was 126 meaning extended byte size is 16 bit
                        if payloadSize == 0x7F { payloadByteSize = 8 } // payload size was 127 meaning extended byet size is 64 bit
                        
                        // get the actual size of a UInt
                        let uIntSize = MemoryLayout<UInt>.size
                        // allocate enough bytes for the UInt
                        var payloadBytes = Array<UInt8>(repeating: 0, count: uIntSize)
                        
                        // read it the extended byte size to the allocated bytes at the proper location
                        // insert in from the left hand side shifting right
                        // eg (UInt size in bytes {8} - extended size {2 or 8}) = 6 or 0
                        try self.inputStream.read(&payloadBytes[uIntSize - payloadByteSize], exactly: payloadByteSize)
                        
                        payloadSize = payloadBytes.withUnsafeBufferPointer {
                            return $0.baseAddress!.withMemoryRebound(to: UInt.self, capacity: 1) {
                                return UInt(littleEndian: $0.pointee)
                            }
                        }
                    }
                    
                    var maskingKey = Array<UInt8>(repeating: 0, count: 4)
                    try self.inputStream.read(&maskingKey, exactly: maskingKey.count)
                    var payload = try self.inputStream.read(exactly: Int(payloadSize))
                    for i in 0..<payload.count {
                        payload[i] ^= maskingKey[i % 4]
                    }
                    
                    return Frame(event: frameEvent,
                                 fin: fin,
                                 rsv1: rsv1,
                                 rsv2: rsv2,
                                 rsv3: rsv3,
                                 payload: Array(payload))
                }
            }
            /// Read the next event that needs processing
            /// This will never return a client ping as they automatically
            /// are responded with a pong
            public func readEvent() throws -> Event {
                repeat {
                    var frm = try self.readFrame()
                    if !frm.fin { // If frame is not finished we will do a loop to get it all
                        var tmpFrm = frm
                        while !tmpFrm.fin {
                            tmpFrm = try self.readFrame()
                            guard tmpFrm.event == .continue else {
                                try? self.writeClose(.policyViolation)
                                throw Error.expectedFrameEvent(.continue, found: tmpFrm)
                            }
                            frm.payload.append(contentsOf: tmpFrm.payload)
                        }
                    }
                    //print("Received WebSocket Frame:\n\(frm)")
                    switch frm.event {
                        case .close:
                            // We received a close frame.  We must send an empty one back as a response
                            try? self.writeClose()
                            var closeCode: CloseCode = .unsupportedData
                            var payload = frm.payload
                            if payload.count >= 2 {
                                let closeCodeRawValue: Int = Int(payload[0]) << 9 | Int(payload[1])
                                if let cc = CloseCode(rawValue: closeCodeRawValue) {
                                    closeCode = cc
                                    payload.removeFirst(2)
                                }
                            }
                            return .close(closeCode, reason: payload)
                        case .ping:
                            try self.writePong(frm.payload)
                        case .pong:
                            return .pong(frm.payload)
                        case .binary:
                            return .binary(frm.payload)
                        case .text:
                            guard let txt = String(bytes: frm.payload, encoding: .utf8) else {
                                try? self.writeClose(.invalidFramePayloadData)
                                throw Error.invalidTextFrame(frm)
                            }
                            return .text(txt)
                        default:
                            try? self.writeClose(.unsupportedData)
                            throw Error.unexpectedFrame(frm)
                    }
                    
                  // We keep looping until we get an event that can be processed
                  // This is done so that if we received a ping, we can send the pong
                  // and read the next event to return
                } while true
            }
        }
        
        /// Create a new Web Socket endpoint
        /// - Parameter webSocketEvent: Event handler used to capture Web Socket Events
        /// - Returns: Returns a Request/Response handler
        public static func endpoint(_ webSocketEvent: @escaping (Client, Event) -> Void) -> ((HTTP.Request, LittleWebServer) -> HTTP.Response) {
            // I would like to switch this to access the server to monitor shutting down
            return { request, server in
                guard let upgrade = request.headers[.upgrade],
                      upgrade.lowercased() == "websocket" else {
                    return .badRequest(body: .plainText("Invalid value of 'Upgrade' header: \(request.headers[.upgrade] ?? "unknown")"))
                }
                guard let connection = request.headers.connection,
                      connection == .upgrade else {
                    return .badRequest(body: .plainText("Invalid value of 'Connection' header: \(request.headers[.connection] ?? "unknown")"))
                }
                guard let secWebSocketKey = request.headers[.websocketSecurityKey] else {
                    return .badRequest(body: .plainText("Invalid value of 'Sec-WebSocket-Key' header: \(request.headers[.websocketSecurityKey] ?? "unknown")"))
                }
                
                
                func webSocketHandler(_ inputStream: LittleWebServerInputStream,
                                      _ outputStream: LittleWebServerOutputStream) throws {
                    
                    let webSocketClient = Client(request: request,
                                                 inputStream: inputStream,
                                                 outputStream: outputStream)
                    
                    
                    defer {
                        if Thread.current.isCancelled || server.isStoppingOrStopped {
                            // We stopped because we're shutting down
                            try? webSocketClient.writeCloseIfNotSent(.goingAway)
                        } else {
                            // If we wern't already closed then something wen't wrong
                            try? webSocketClient.writeCloseIfNotSent(.internalServerError)
                        }
                        webSocketEvent(webSocketClient, .disconnected)
                    }
                    
                    webSocketEvent(webSocketClient, .connected)
                    // Keep looping until either we sent the close event
                    // or our thread is being cancelled
                    while !webSocketClient.hasSentClosed &&
                          !Thread.current.isCancelled &&
                          !server.isStoppingOrStopped {
                        try autoreleasepool {
                            let event = try webSocketClient.readEvent()
                            webSocketEvent(webSocketClient, event)
                        }
                    }
                    
                }
                
                let secWebSocketAccept = (secWebSocketKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").sha1.base64EncodedString()
                var headers = HTTP.Response.Headers()
                headers.connection = .upgrade
                headers[.upgrade] = "websocket"
                headers[.websocketSecurityAccept] = secWebSocketAccept
                return .switchProtocol(writeQueue: .websocket,
                                       headers: headers,
                                       body: .custom(webSocketHandler))
            }
        }
    }
}
