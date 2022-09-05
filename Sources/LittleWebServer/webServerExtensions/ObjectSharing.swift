//
//  ObjectSharing.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-21.
//

import Foundation

public extension LittleWebServer {
    /// Methods / Logic for Object Sharing
    struct ObjectSharing { private init() { }
        
        public enum ErrorResponseEvent {
            case precondition
            case objectGetter
            case objectUpdater
            case objectAdder
            case objectDeleter
            case listGetter
            
            case encoding
            case decoding
        }
        
        public enum ObjectSharingError: Swift.Error {
            case missingContentLength
            case unknownOrUnacceptableContentType
            //case invalidObjectId(String)
            case objectNotFound
        }
        
        private struct WrappedEncodable: Encodable {
            private let object: Encodable
            public init(_ object: Encodable) {
                self.object = object
            }
            
            func encode(to encoder: Encoder) throws {
                try self.object.encode(to: encoder)
            }
        }
        /// The error reponse hander used to generate an error response
        /// - Parameters:
        ///   - event: The event where the error occured
        ///   - error: The swift error that occured
        /// - Returns: Returns the error response object
        public typealias ErrorResponseHandler<ErrorResponse> = (_ event: ErrorResponseEvent,
                                                                _ error: Swift.Error) -> ErrorResponse where ErrorResponse: Encodable
        
        
        /// Pick the proper encoder based on the list and the Accept header or the first encoder in the list as a fallback
        /// - Parameters:
        ///   - encoders: List of encodes to pick from the match the content types
        ///   - request: The request to check for acceptable content types
        internal static func pickEncoder(from encoders: [LittleWebServerObjectEncoder],
                                         using request:  HTTP.Request) -> LittleWebServerObjectEncoder {
            guard var rtn = encoders.first else {
                preconditionFailure("There must be atleast one encoder")
            }
            
            if let acceptContentTypes = request.headers.accept {
                for ctType in acceptContentTypes {
                    if let found = encoders.first(where: { return $0.littleWebServerContentMediaType == ctType.resourceType }) {
                        rtn = found
                        break
                    }
                }
            }
            return rtn
        }
        
        /// Pick the proper decoder based on the list
        /// - Parameters:
        ///   - decoders: List of decoders to pick from the match the content type
        ///   - request: The request to check for acceptable content types
        ///   - useFirstAsDefault: Indicator if the first decoder should be returned IF not matching decoder is found
        internal static func pickDecoder(from decoders: [LittleWebServerObjectDecoder],
                                         using request:  HTTP.Request,
                                         useFirstAsDefault: Bool) -> LittleWebServerObjectDecoder? {
            guard let contentType = request.contentType else { return nil }
            var rtn = decoders.first(where: { $0.littleWebServerContentMediaType == contentType.resourceType })
            if rtn == nil && useFirstAsDefault {
                rtn = decoders.first
            }
            return rtn
        }
        
        /// Generate an internal error response
        /// - Parameters:
        ///   - request: The request the reponse is for
        ///   - handler: The hander to genreate an ErrorRespone
        ///   - event: The event where the error occured
        ///   - error: The swift error that occured
        ///   - encoder: The encoder used to encode the ErrorRespone
        /// - Returns: Returns an HTTP Resposne
        private static func generateErrorResponse<ErrorResponse>(request: HTTP.Request,
                                                                 handler: ErrorResponseHandler<ErrorResponse>,
                                                  event: ErrorResponseEvent,
                                                  error: Swift.Error,
                                                 encoder: LittleWebServerObjectEncoder) -> LittleWebServer.HTTP.Response where ErrorResponse: Encodable {
            do {
                let errResp = handler(event, error)
                let dta = try encoder.encode(errResp)
                return LittleWebServer.HTTP.Response.internalError(body: .data(dta,
                                                                               contentType: encoder.littleWebServerContentType))
            } catch {
                if let controller = Thread.current.littleWebServerDetails.routeController {
                    return controller.internalError(for: request,
                                             error: error,
                                             signalServerErrorHandler: true)
                } else {
                    return LittleWebServer.HTTP.Response.internalError()
                }
            }
            
        }
        
        /// Generate an internal error response
        /// - Parameters:
        ///   - request: The request the reponse is for
        ///   - handler: The hander to genreate an ErrorRespone
        ///   - event: The event where the error occured
        ///   - error: The swift error that occured
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        /// - Returns: Returns an HTTP Resposne
        private static func generateErrorResponse<ErrorResponse>(request: HTTP.Request,
                                                                 handler: ErrorResponseHandler<ErrorResponse>,
                                                  event: ErrorResponseEvent,
                                                  error: Swift.Error,
                                                 encoders: [LittleWebServerObjectEncoder]) -> LittleWebServer.HTTP.Response where ErrorResponse: Encodable {
            return self.generateErrorResponse(request: request,
                                              handler: handler,
                                              event: event,
                                              error: error,
                                              encoder: self.pickEncoder(from: encoders, using: request))
            
        }
        
        /// Generates a not found response
        /// - Parameters:
        ///   - request: The request the reponse is for
        ///   - handler: The hander to genreate an NotFoundResponse
        ///   - stringId: The string id of the object being looked for
        ///   - objectId: The object id of the object being looked for if available
        ///   - encoder: The encoder used to encoder the NotFoundResponse
        /// - Returns: Returns an HTTP Resposne
        private static func generateNotFoundResponse<ObjectId, NotFoundResponse>(request: HTTP.Request,
                                                                                 handler: (_ request: HTTP.Request,
                                                                                           _ stringId: String,
                                                                                           _ objectId: ObjectId?) -> NotFoundResponse,
                                                  stringId: String,
                                                  objectId: ObjectId?,
                                                  encoder: LittleWebServerObjectEncoder) -> LittleWebServer.HTTP.Response
            where ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable {
            
            do {
                let resp = handler(request, stringId, objectId)
                let dta = try encoder.encode(resp)
                return LittleWebServer.HTTP.Response.notFound(body: .data(dta,
                                                                          contentType: encoder.littleWebServerContentType))
            } catch {
                if let controller = Thread.current.littleWebServerDetails.routeController {
                    return controller.internalError(for: request,
                                             error: error,
                                             signalServerErrorHandler: true)
                } else {
                    return LittleWebServer.HTTP.Response.internalError()
                }
            }
        }
        
        /// Generates a not found response
        /// - Parameters:
        ///   - request: The request the reponse is for
        ///   - handler: The hander to genreate an NotFoundResponse
        ///   - stringId: The string id of the object being looked for
        ///   - objectId: The object id of the object being looked for if available
        ///   - encoder: The encoder used to encoder the NotFoundResponse
        /// - Returns: Returns an HTTP Resposne
        private static func generateNotFoundResponse<ObjectId, NotFoundResponse>(request: HTTP.Request,
                                                                                 handler: (_ request: HTTP.Request,
                                                                                           _ stringId: String,
                                                                                           _ objectId: ObjectId?) -> NotFoundResponse,
                                                  stringId: String,
                                                  objectId: ObjectId?,
                                                  encoders: [LittleWebServerObjectEncoder]) -> LittleWebServer.HTTP.Response
            where ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable {
            
            return self.generateNotFoundResponse(request: request,
                                                 handler: handler,
                                                 stringId: stringId,
                                                 objectId: objectId,
                                                 encoder: self.pickEncoder(from: encoders, using: request))
        }
        
        /// Method for validating if the response Response object is supported
        /// Valid Response objects are Void, and Encodable object or an Optional<Encodable> object
        ///
        /// This will do a precondition failure if the Response type is not valid
        /// - Parameters:
        ///   - value: The response type to validate
        ///   - identifier: The identifier name for this value
        private static func validateHandlerResponse<Response>(_ value: Response.Type, identifier: String) {
            if value == Void.self {
                return
            } else if value is Encodable.Type {
                return
            } else if let nilType = value as? _Nillable.Type,
                      value != NSNull.self &&
                        nilType.wrappedType is Encodable.Type {
                return
            } else {
                preconditionFailure("\(identifier): Invalid Result Type '\(value)'. Result Type must be Void or a type that implements Encodable")
            }
        }
        
        /// Gets the encodable response if there was one
        /// - Parameter value: The value to cast as an Encodable obejct
        /// - Returns: Returns the encodable object or nil
        private static func getEncodableResponse<Response>(_ value: Response) -> Encodable? {
            let valueType = type(of: value)
            if valueType == Void.self {
                return nil
            } else if let rtn = value as? Encodable {
                return rtn
            } else if let nilValue = value as? _Nillable,
                      valueType != NSNull.self &&
                        nilValue.wrappedType is Encodable {
                if let v = nilValue.safeRootUnwrap {
                    return v as? Encodable
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        
        /// Share an encodable object
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - handler: The handler used to get the object to encode
        ///   - object: The object to encoder and return as the reponse
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                     ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                    handler: @escaping (_ object: HTTP.Request) throws -> Object,
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> ( HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
                  ErrorResponse: Encodable {
            
            precondition(encoders.count > 0, "Must have atleast one supported encoder")
            
            return { (_ request: HTTP.Request) -> LittleWebServer.HTTP.Response? in
                
                var errorResponseEvent: ErrorResponseEvent = .objectGetter
                let encoder = self.pickEncoder(from: encoders, using: request)
                do {
                    return try autoreleasepool {
                        let obj = try handler(request)
                        errorResponseEvent = .encoding
                        
                        let dta = try encoder.encode(obj)
                        return LittleWebServer.HTTP.Response.ok(body: .data(dta,
                                                                            contentType: encoder.littleWebServerContentType))
                    }
                } catch {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: errorResponseEvent,
                                                      error: error,
                                                      encoder: encoder)
                }
            }
        }
        
        /// Share an encodable object
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - handler: The handler used to get the object to encode
        ///   - object: The object to encoder and return as the reponse
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                       ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                    handler: @escaping (_ object: HTTP.Request) throws -> Object,
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> ( HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
                  ErrorResponse: Encodable {
            
            return self.shareObject(encoders: encoders,
                                    handler: handler,
                                    errorResponse: errorResponse)
        }
        
        /// Share an encodable object
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the object
        ///   - handler: The handler used to get the object to encode
        ///   - object: The object to encoder and return as the reponse
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                     ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                    handler: @escaping (_ object: HTTP.Request) throws -> Object,
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> ( HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
                  ErrorResponse: Encodable {
            
            return self.shareObject(encoders: [encoder],
                                    handler: handler,
                                    errorResponse: errorResponse)
        }
        
        /// Share an encodable object
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - object: The object to share
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                     ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                    object: @escaping @autoclosure () throws -> Object,
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
              ErrorResponse: Encodable {
            
            return self.shareObject(encoders: encoders,
                                  handler: { _ in return try object() },
                                  errorResponse: errorResponse)
            
        }
        
        /// Share an encodable object
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - object: The object to share
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                       ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                    object: @escaping @autoclosure () throws -> Object,
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
              ErrorResponse: Encodable {
            
            return self.shareObject(encoders: encoders,
                                  handler: { _ in return try object() },
                                  errorResponse: errorResponse)
            
        }
        
        /// Share an encodable object
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the object
        ///   - object: The object to share
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                     ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                    object: @escaping @autoclosure () throws -> Object,
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
              ErrorResponse: Encodable {
            
            return self.shareObject(encoders: [encoder],
                                  handler: { _ in return try object() },
                                  errorResponse: errorResponse)
            
        }
        
        /// Share individal objects by path Id's
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - handler: The handler used to get the object to encode
        ///   - notFoundResponse: The object not found handler
        ///   - request: The request the reponse is for
        ///   - stringId: The string id of the object being looked for
        ///   - objectId: The object id of the object being looked for if available
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func getPathObject<Object,
                                         ObjectId,
                                         NotFoundResponse,
                                     ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                    handler: @escaping (_ request: HTTP.Request,
                                                                        _ objectId: ObjectId) throws -> Object?,
                                                    notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                 _ stringId: String,
                                                                                 _ objectId: ObjectId?) -> NotFoundResponse,
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
                  ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            return { (_ request: HTTP.Request) -> LittleWebServer.HTTP.Response? in
                guard let id = request.identities["id"] else {
                    preconditionFailure("Missing path identifier 'id'")
                }
                guard let sid = id as? String else {
                    
                    preconditionFailure("Id must be in string format.  No transformation")
                }
                
                let encoder = self.pickEncoder(from: encoders, using: request)
                
                guard let objectId = ObjectId(sid) else {
                    return self.generateNotFoundResponse(request: request,
                                                         handler: notFoundResponse,
                                                         stringId: sid,
                                                         objectId: nil,
                                                         encoder: encoder)
                    /*return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: .precondition,
                                                      error: ObjectSharingError.invalidObjectId(sid),
                                                      encoder: encoder)*/
                }
                
                var errorResponseEvent: ErrorResponseEvent = .objectGetter
                do {
                    return try autoreleasepool {
                        guard let obj = try handler(request, objectId) else {
                            return self.generateNotFoundResponse(request: request,
                                                                 handler: notFoundResponse,
                                                                 stringId: sid,
                                                                 objectId: objectId,
                                                                 encoder: encoder)
                        }
                        errorResponseEvent = .encoding
                        let dta = try encoder.encode(obj)
                        return LittleWebServer.HTTP.Response.ok(body: .data(dta,
                                                                            contentType: encoder.littleWebServerContentType))
                    }
                } catch ObjectSharingError.objectNotFound {
                    return self.generateNotFoundResponse(request: request,
                                                         handler: notFoundResponse,
                                                         stringId: sid,
                                                         objectId: objectId,
                                                         encoder: encoder)
                } catch {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: errorResponseEvent,
                                                      error: error,
                                                      encoder: encoder)
                }
            }
        }
        
        /// Share individal objects by path Id's
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - handler: The handler used to get the object to encode
        ///   - notFoundResponse: The object not found handler
        ///   - request: The request the reponse is for
        ///   - stringId: The string id of the object being looked for
        ///   - objectId: The object id of the object being looked for if available
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func getPathObject<Object,
                                         ObjectId,
                                         NotFoundResponse,
                                         ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                    handler: @escaping (_ request: HTTP.Request,
                                                                        _ objectId: ObjectId) throws -> Object?,
                                                    notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                 _ stringId: String,
                                                                                 _ objectId: ObjectId?) -> NotFoundResponse,
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
                  ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            return self.getPathObject(encoders: encoders,
                                      handler: handler,
                                      notFoundResponse: notFoundResponse,
                                      errorResponse: errorResponse)
            
        }
        
        /// Share individal objects by path Id's
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - handler: The handler used to get the object to encode
        ///   - notFoundResponse: The object not found handler
        ///   - request: The request the reponse is for
        ///   - stringId: The string id of the object being looked for
        ///   - objectId: The object id of the object being looked for if available
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func getPathObject<Object,
                                         ObjectId,
                                         NotFoundResponse,
                                     ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                    handler: @escaping (_ request: HTTP.Request,
                                                                        _ objectId: ObjectId) throws -> Object?,
                                                    notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                 _ stringId: String,
                                                                                 _ objectId: ObjectId?) -> NotFoundResponse,
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
                  ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            return self.getPathObject(encoders: [encoder],
                                      handler: handler,
                                      notFoundResponse: notFoundResponse,
                                      errorResponse: errorResponse)
        }
        
        /// Share a list of object at a given path
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - handler: The handler used to get the objects to encode
        ///   - request: The request the reponse is for
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func listObjects<Object,
                                       ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                      handler: @escaping (_ request: HTTP.Request) throws -> [Object],
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
                  ErrorResponse: Encodable {
            
            return { (_ request: HTTP.Request) -> LittleWebServer.HTTP.Response? in
                
                let encoder = self.pickEncoder(from: encoders, using: request)
                
                var errorResponseEvent: ErrorResponseEvent = .listGetter
                do {
                    return try autoreleasepool {
                        let objs = try handler(request)
                        errorResponseEvent = .encoding
                        
                        let dta = try encoder.encode(objs)
                        return LittleWebServer.HTTP.Response.ok(body: .data(dta,
                                                                            contentType: encoder.littleWebServerContentType))
                    }
                } catch {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: errorResponseEvent,
                                                      error: error,
                                                      encoder: encoder)
                }
            }
        }
        
        /// Share a list of object at a given path
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - list: The list of objects to share
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func listObjects<Object,
                                       ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                      list: @escaping @autoclosure () throws -> [Object],
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
                  ErrorResponse: Encodable {
            
            return self.listObjects(encoders: encoders,
                                    handler: { _ in return try list() },
                                    errorResponse: errorResponse)
        }
        
        
        
        /// Share a list of object at a given path
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - handler: The handler used to get the objects to encode
        ///   - request: The request the reponse is for
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func listObjects<Object,
                                       ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                      handler: @escaping (_ request: HTTP.Request) throws -> [Object],
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
                  ErrorResponse: Encodable {
            
            return self.listObjects(encoders: encoders,
                                    handler: handler,
                                    errorResponse: errorResponse)
        }
        
        
        /// Share a list of object at a given path
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - list: The list of objects to share
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func listObjects<Object,
                                       ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                      list: @escaping @autoclosure () throws -> [Object],
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
                  ErrorResponse: Encodable {
            
            return self.listObjects(encoders: encoders,
                                    handler: { _ in return try list() },
                                    errorResponse: errorResponse)
        }
        
        
        /// Share a list of object at a given path
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the objects
        ///   - handler: The handler used to get the objects to encode
        ///   - request: The request the reponse is for
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func listObjects<Object,
                                       ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                      handler: @escaping (_ request: HTTP.Request) throws -> [Object],
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
                  ErrorResponse: Encodable {
            
            return self.listObjects(encoders: [encoder],
                                    handler: handler,
                                    errorResponse: errorResponse)
        }
        
        /// Share a list of object at a given path
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the objects
        ///   - list: The list of objects to share
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func listObjects<Object,
                                       ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                      list: @escaping @autoclosure () throws -> [Object],
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Encodable,
                  ErrorResponse: Encodable {
            
            return self.listObjects(encoder: encoder,
                                    handler: { _ in return try list() },
                                    errorResponse: errorResponse)
        }
        /// Enum Used when decoding an add object
        /// Allows for returning the actual object OR some other
        /// HTTP Response for errors
        public enum AddObjectDecoderResponse<Object> {
            case object(Object)
            case error(Swift.Error)
            case otherResponse(HTTP.Response)
        }
        
        /// Add a new object
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoder: The method to call to decode the object from the rquest
        ///   - handler: The handler used to add the new object
        ///   - request: The request the reponse is for
        ///   - object: The new object to add
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func addObject<Object,
                                     AddResponse,
                                     ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                    decoder: @escaping (HTTP.Request) throws -> AddObjectDecoderResponse<Object>,
                                                    handler: @escaping (_ request: HTTP.Request,
                                                                        _ object: Object) throws -> AddResponse,
                                                    
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where ErrorResponse: Encodable {
            
            validateHandlerResponse(AddResponse.self, identifier: "Add Handler")
            
            
            return { (_ request: HTTP.Request) -> LittleWebServer.HTTP.Response? in
                
                let encoder = self.pickEncoder(from: encoders, using: request)
                
                var errorResponseEvent: ErrorResponseEvent = .decoding
                do {
                    return try autoreleasepool {
                        let objResponse = try decoder(request)
                        
                        switch objResponse {
                            case .otherResponse(let rtn):
                                return rtn
                            case .error(let e):
                                return self.generateErrorResponse(request: request,
                                                                  handler: errorResponse,
                                                                  event: errorResponseEvent,
                                                                  error: e,
                                                                  encoder: encoder)
                            case .object(let obj):
                                var responseBody: LittleWebServer.HTTP.Response.Body = .empty
                                errorResponseEvent = .objectAdder
                                let resp = try handler(request, obj)
                                if let enc = getEncodableResponse(resp) {
                                    errorResponseEvent = .encoding
                                    let respDta = try encoder.encode(WrappedEncodable(enc))
                                    responseBody = .data(respDta, contentType: encoder.littleWebServerContentType)
                                }
                                
                                return LittleWebServer.HTTP.Response.created(body: responseBody)
                        }
                    }
                } catch {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: errorResponseEvent,
                                                      error: error,
                                                      encoder: encoder)
                }
            }
        }
        
        /// Add a new object
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoder: The method to call to decode the object from the rquest
        ///   - handler: The handler used to add the new object
        ///   - request: The request the reponse is for
        ///   - object: The new object to add
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func addObject<Object,
                                     AddResponse,
                                     ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                    decoder: @escaping (HTTP.Request) throws -> AddObjectDecoderResponse<Object>,
                                                    handler: @escaping (_ request: HTTP.Request,
                                                                        _ object: Object) throws -> AddResponse,
                                                    
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where ErrorResponse: Encodable {
            
            return self.addObject(encoders: encoders,
                                  decoder: decoder,
                                  handler: handler,
                                  errorResponse: errorResponse)
            
        }
        
        /// Add a new object
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The method to call to decode the object from the rquest
        ///   - handler: The handler used to add the new object
        ///   - request: The request the reponse is for
        ///   - object: The new object to add
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func addObject<Object,
                                     AddResponse,
                                     ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                    decoder: @escaping (HTTP.Request) throws -> AddObjectDecoderResponse<Object>,
                                                    handler: @escaping (_ request: HTTP.Request,
                                                                        _ object: Object) throws -> AddResponse,
                                                    
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where ErrorResponse: Encodable {
            
            return self.addObject(encoders: [encoder],
                                  decoder: decoder,
                                  handler: handler,
                                  errorResponse: errorResponse)
            
        }
        
        /// Add a new object
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - handler: The handler used to add the new object
        ///   - request: The request the reponse is for
        ///   - object: The new object to add
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func addObject<Object,
                                     AddResponse,
                                     ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                    decoders: [LittleWebServerObjectDecoder],
                                                    firstDecoderDefault: Bool = false,
                                                    handler: @escaping (_ request: HTTP.Request,
                                                                        _ object: Object) throws -> AddResponse,
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Decodable,
                  ErrorResponse: Encodable {
            
            func decodingFunc(_ request: HTTP.Request) throws -> AddObjectDecoderResponse<Object> {
                let encoder = self.pickEncoder(from: encoders, using: request)
                let dec = self.pickDecoder(from: decoders,
                                           using: request,
                                           useFirstAsDefault: firstDecoderDefault)
                guard let decoder = dec else {
                    return .otherResponse(self.generateErrorResponse(request: request,
                                                                     handler: errorResponse,
                                                                     event: .precondition,
                                                                     error: ObjectSharingError.unknownOrUnacceptableContentType,
                                                                     encoder: encoder))
                }
                
                guard let contentLength = request.contentLength else {
                    return .otherResponse(self.generateErrorResponse(request: request,
                                                                     handler: errorResponse,
                                                                     event: .precondition,
                                                                     error: ObjectSharingError.missingContentLength,
                                                                     encoder: encoder))
                    
                }
                return try autoreleasepool {
                    let dta = try request.inputStream.read(exactly: Int(contentLength))
                    let obj = try decoder.decode(Object.self, from: dta)
                    return .object(obj)
                }
            }
            
            return self.addObject(encoders: encoders,
                                  decoder: decodingFunc,
                                  handler: handler,
                                  errorResponse: errorResponse)
        }
        /*
        /// Add a new object
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - handler: The handler used to add the new object
        ///   - request: The request the reponse is for
        ///   - object: The new object to add
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func addObject<Object,
                                     AddResponse,
                                     ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                    decoders: LittleWebServerObjectDecoder...,
                                                    firstDecoderDefault: Bool = false,
                                                    handler: @escaping (_ request: HTTP.Request,
                                                                        _ object: Object) throws -> AddResponse,
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Decodable,
                  ErrorResponse: Encodable {
            
            return self.addObject(encoders: encoders,
                                  decoders: decoders,
                                  firstDecoderDefault: firstDecoderDefault,
                                  handler: handler,
                                  errorResponse: errorResponse)
            
        }
        */
        /// Add a new object
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the object
        ///   - decodeWithContentMissMatch: Indicator if should use the first decoder if none match
        ///   - handler: The handler used to add the new object
        ///   - request: The request the reponse is for
        ///   - object: The new object to add
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func addObject<Object,
                                     AddResponse,
                                     ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                    decoder: LittleWebServerObjectDecoder,
                                                    decodeWithContentMissMatch: Bool = true,
                                                    handler: @escaping (_ request: HTTP.Request,
                                                                        _ object: Object) throws -> AddResponse,
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Decodable,
                  ErrorResponse: Encodable {
            
            return self.addObject(encoders: [encoder],
                                  decoders: [decoder],
                                  firstDecoderDefault: decodeWithContentMissMatch,
                                  handler: handler,
                                  errorResponse: errorResponse)
            
        }
        
        /// Update an existing object
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - handler: The handler used to update an existing object
        ///   - request: The request the reponse is for
        ///   - object: The object that was updated
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func updateObject<Object,
                                        UpdateResponse,
                                        ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                       decoders: [LittleWebServerObjectDecoder],
                                                       firstDecoderDefault: Bool = false,
                                                       handler: @escaping (_ request: HTTP.Request,
                                                                           _ object: Object) throws -> UpdateResponse,
                                                       errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Decodable,
                  ErrorResponse: Encodable {
            
            validateHandlerResponse(UpdateResponse.self, identifier: "Update Handler")
            
            
            return { (_ request: HTTP.Request) -> LittleWebServer.HTTP.Response? in
                
                let encoder = self.pickEncoder(from: encoders, using: request)
                let dec = self.pickDecoder(from: decoders,
                                           using: request,
                                           useFirstAsDefault: firstDecoderDefault)
                guard let decoder = dec else {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: .precondition,
                                                      error: ObjectSharingError.unknownOrUnacceptableContentType,
                                                      encoder: encoder)
                }
                
                
                guard let contentLength = request.contentLength else {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: .precondition,
                                                      error: ObjectSharingError.missingContentLength,
                                                      encoder: encoder)
                }
                var errorResponseEvent: ErrorResponseEvent = .decoding
                do {
                    return try autoreleasepool {
                        let dta = try request.inputStream.read(exactly: Int(contentLength))
                        let obj = try decoder.decode(Object.self, from: dta)
                        var responseBody: LittleWebServer.HTTP.Response.Body = .empty
                        errorResponseEvent = .objectUpdater
                        
                        let resp = try handler(request, obj)
                        if let enc = getEncodableResponse(resp) {
                            errorResponseEvent = .encoding
                            let respDta = try encoder.encode(WrappedEncodable(enc))
                            responseBody = .data(respDta, contentType: encoder.littleWebServerContentType)
                        }
                        if responseBody.isEmpty {
                            return LittleWebServer.HTTP.Response.noContent()
                        } else {
                            return LittleWebServer.HTTP.Response.ok(body: responseBody)
                        }
                    }
    
                } catch {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: errorResponseEvent,
                                                      error: error,
                                                      encoder: encoder)
                }
            }
        }
        /*
        /// Update an existing object
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - handler: The handler used to update an existing object
        ///   - request: The request the reponse is for
        ///   - object: The object that was updated
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func updateObject<Object,
                                        UpdateResponse,
                                        ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                       decoders: LittleWebServerObjectDecoder...,
                                                       firstDecoderDefault: Bool = false,
                                                       handler: @escaping (_ request: HTTP.Request,
                                                                           _ object: Object) throws -> UpdateResponse,
                                                       errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Decodable,
                  ErrorResponse: Encodable {
            
            return self.updateObject(encoders: encoders,
                                     decoders: decoders,
                                     firstDecoderDefault: firstDecoderDefault,
                                     handler: handler,
                                     errorResponse: errorResponse)
        }
        */
        
        
        /// Update an existing object
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the updated object
        ///   - decodeWithContentMissMatch: Indicator if should use the first decoder if none match
        ///   - handler: The handler used to update an existing object
        ///   - request: The request the reponse is for
        ///   - object: The object that was updated
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func updateObject<Object,
                                        UpdateResponse,
                                        ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                       decoder: LittleWebServerObjectDecoder,
                                                       decodeWithContentMissMatch: Bool = true,
                                                       handler: @escaping (_ request: HTTP.Request,
                                                                           _ object: Object) throws -> UpdateResponse,
                                                       errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Decodable,
                  ErrorResponse: Encodable {
            
            return self.updateObject(encoders: [encoder],
                                     decoders: [decoder],
                                     firstDecoderDefault: decodeWithContentMissMatch,
                                     handler: handler,
                                     errorResponse: errorResponse)
        }
        
        
        /// Update an existing object at the given path
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - handler: The handler used to update the object
        ///   - notFoundResponse: The object not found handler
        ///   - request: The request the reponse is for
        ///   - stringId: The string id of the object being looked for
        ///   - objectId: The object id of the object being looked for if available
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func updatePathObject<Object,
                                            ObjectId,
                                            UpdateResponse,
                                            NotFoundResponse,
                                            ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                       decoders: [LittleWebServerObjectDecoder],
                                                       firstDecoderDefault: Bool = false,
                                                       handler: @escaping (_ request: HTTP.Request,
                                                                           _ objectId: ObjectId,
                                                                           _ object: Object) throws -> UpdateResponse,
                                                       notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                    _ stringId: String,
                                                                                    _ objectId: ObjectId?) -> NotFoundResponse,
                                                       errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Decodable,
                  ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            validateHandlerResponse(UpdateResponse.self, identifier: "Update Handler")
            
            
            return { (_ request: HTTP.Request) -> LittleWebServer.HTTP.Response? in
                
                guard let id = request.identities["id"] else {
                    preconditionFailure("Missing path identifier 'id'")
                }
                guard let sid = id as? String else {
                    preconditionFailure("Id must be in string format.  No transformation")
                }
                
                let encoder = self.pickEncoder(from: encoders, using: request)
                let dec = self.pickDecoder(from: decoders,
                                           using: request,
                                           useFirstAsDefault: firstDecoderDefault)
                guard let decoder = dec else {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: .precondition,
                                                      error: ObjectSharingError.unknownOrUnacceptableContentType,
                                                      encoder: encoder)
                }
                
                
                guard let objectId = ObjectId(sid) else {
                    return self.generateNotFoundResponse(request: request,
                                                         handler: notFoundResponse,
                                                         stringId: sid,
                                                         objectId: nil,
                                                         encoder: encoder)
                }
                
                guard let contentLength = request.contentLength else {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: .precondition,
                                                      error: ObjectSharingError.missingContentLength,
                                                      encoder: encoder)
                }
                var errorResponseEvent: ErrorResponseEvent = .decoding
                do {
                    return try autoreleasepool {
                        let dta = try request.inputStream.read(exactly: Int(contentLength))
                        let obj = try decoder.decode(Object.self, from: dta)
                        var responseBody: LittleWebServer.HTTP.Response.Body = .empty
                        errorResponseEvent = .objectUpdater
                        let resp = try handler(request, objectId, obj)
                        if let enc = getEncodableResponse(resp) {
                            errorResponseEvent = .encoding
                            let respDta = try encoder.encode(WrappedEncodable(enc))
                            responseBody = .data(respDta, contentType: encoder.littleWebServerContentType)
                        }
                        if responseBody.isEmpty {
                            return LittleWebServer.HTTP.Response.noContent()
                        } else {
                            return LittleWebServer.HTTP.Response.ok(body: responseBody)
                        }
                    }
                } catch ObjectSharingError.objectNotFound {
                    return self.generateNotFoundResponse(request: request,
                                                         handler: notFoundResponse,
                                                         stringId: sid,
                                                         objectId: objectId,
                                                         encoder: encoder)
                } catch {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: errorResponseEvent,
                                                      error: error,
                                                      encoder: encoder)
                }
            }
        }
        /*
        /// Update an existing object at the given path
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - handler: The handler used to update the object
        ///   - notFoundResponse: The object not found handler
        ///   - request: The request the reponse is for
        ///   - stringId: The string id of the object being looked for
        ///   - objectId: The object id of the object being looked for if available
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func updatePathObject<Object,
                                            ObjectId,
                                            UpdateResponse,
                                            NotFoundResponse,
                                            ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                           decoders: LittleWebServerObjectDecoder...,
                                                       firstDecoderDefault: Bool = false,
                                                       handler: @escaping (_ request: HTTP.Request,
                                                                           _ objectId: ObjectId,
                                                                           _ object: Object) throws -> UpdateResponse,
                                                       notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                    _ stringId: String,
                                                                                    _ objectId: ObjectId?) -> NotFoundResponse,
                                                       errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Decodable,
                  ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            return self.updatePathObject(encoders: encoders,
                                         decoders: decoders,
                                         firstDecoderDefault: firstDecoderDefault,
                                         handler: handler,
                                         notFoundResponse: notFoundResponse,
                                         errorResponse: errorResponse)
        }
        */
        /// Update an existing object at the given path
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the updated object
        ///   - decodeWithContentMissMatch: Indicator if should use the first decoder if none match
        ///   - handler: The handler used to update the object
        ///   - notFoundResponse: The object not found handler
        ///   - request: The request the reponse is for
        ///   - stringId: The string id of the object being looked for
        ///   - objectId: The object id of the object being looked for if available
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func updatePathObject<Object,
                                            ObjectId,
                                            UpdateResponse,
                                            NotFoundResponse,
                                            ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                           decoder: LittleWebServerObjectDecoder,
                                                           decodeWithContentMissMatch: Bool = true,
                                                       handler: @escaping (_ request: HTTP.Request,
                                                                           _ objectId: ObjectId,
                                                                           _ object: Object) throws -> UpdateResponse,
                                                       notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                    _ stringId: String,
                                                                                    _ objectId: ObjectId?) -> NotFoundResponse,
                                                       errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Decodable,
                  ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            return self.updatePathObject(encoders: [encoder],
                                         decoders: [decoder],
                                         firstDecoderDefault: decodeWithContentMissMatch,
                                         handler: handler,
                                         notFoundResponse: notFoundResponse,
                                         errorResponse: errorResponse)
        }
        
        
        /// Delete an existing object at the given path
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - handler: The handler used to delete an object
        ///   - notFoundResponse: The object not found handler
        ///   - request: The request the reponse is for
        ///   - stringId: The string id of the object being looked for
        ///   - objectId: The object id of the object being looked for if available
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func deletePathObject<ObjectId,
                                            DeleteResponse,
                                            NotFoundResponse,
                                            ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                       handler: @escaping (_ request: HTTP.Request,
                                                                           _ objectId: ObjectId) throws -> DeleteResponse,
                                                       notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                    _ stringId: String,
                                                                                    _ objectId: ObjectId?) -> NotFoundResponse,
                                                       errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            validateHandlerResponse(DeleteResponse.self, identifier: "Delete Handler")
            
            return { (_ request: HTTP.Request) -> LittleWebServer.HTTP.Response? in
                guard let id = request.identities["id"] else {
                    preconditionFailure("Missing path identifier 'id'")
                }
                guard let sid = id as? String else {
                    preconditionFailure("Id must be in string format.  No transformation")
                }
                
                let encoder = self.pickEncoder(from: encoders, using: request)
                
                guard let objectId = ObjectId(sid) else {
                    return self.generateNotFoundResponse(request: request,
                                                         handler: notFoundResponse,
                                                         stringId: sid,
                                                         objectId: nil,
                                                         encoder: encoder)
                }
                
                var errorResponseEvent: ErrorResponseEvent = .objectDeleter
                
                do {
                    return try autoreleasepool {
                        var responseBody: LittleWebServer.HTTP.Response.Body = .empty
                        let resp = try handler(request, objectId)
                        if let enc = getEncodableResponse(resp) {
                            errorResponseEvent = .encoding
                            let respDta = try encoder.encode(WrappedEncodable(enc))
                            responseBody = .data(respDta, contentType: encoder.littleWebServerContentType)
                        }
                        
                        if responseBody.isEmpty {
                            return LittleWebServer.HTTP.Response.noContent()
                        } else {
                            return LittleWebServer.HTTP.Response.ok(body: responseBody)
                        }
                    }
                } catch ObjectSharingError.objectNotFound {
                    return self.generateNotFoundResponse(request: request,
                                                         handler: notFoundResponse,
                                                         stringId: sid,
                                                         objectId: objectId,
                                                         encoder: encoder)
                } catch {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: errorResponseEvent,
                                                      error: error,
                                                      encoder: encoder)
                }
            }
        }
        
        /// Delete an existing object at the given path
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - handler: The handler used to delete an object
        ///   - notFoundResponse: The object not found handler
        ///   - request: The request the reponse is for
        ///   - stringId: The string id of the object being looked for
        ///   - objectId: The object id of the object being looked for if available
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func deletePathObject<ObjectId,
                                            DeleteResponse,
                                            NotFoundResponse,
                                            ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                       handler: @escaping (_ request: HTTP.Request,
                                                                           _ objectId: ObjectId) throws -> DeleteResponse,
                                                       notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                    _ stringId: String,
                                                                                    _ objectId: ObjectId?) -> NotFoundResponse,
                                                       errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            return self.deletePathObject(encoders: encoders,
                                         handler: handler,
                                         notFoundResponse: notFoundResponse,
                                         errorResponse: errorResponse)
        }
        
        
        
        /// Delete an existing object at the given path
        /// - Parameters:
        ///   - encoders: The encoder to use to encode the response
        ///   - handler: The handler used to delete an object
        ///   - notFoundResponse: The object not found handler
        ///   - request: The request the reponse is for
        ///   - stringId: The string id of the object being looked for
        ///   - objectId: The object id of the object being looked for if available
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func deletePathObject<ObjectId,
                                            DeleteResponse,
                                            NotFoundResponse,
                                            ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                       handler: @escaping (_ request: HTTP.Request,
                                                                           _ objectId: ObjectId) throws -> DeleteResponse,
                                                       notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                    _ stringId: String,
                                                                                    _ objectId: ObjectId?) -> NotFoundResponse,
                                                       errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            return self.deletePathObject(encoders: [encoder],
                                         handler: handler,
                                         notFoundResponse: notFoundResponse,
                                         errorResponse: errorResponse)
        }
        
        /// Share an updatable object
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - getHandler: The handler used to get the object
        ///   - request: The request the reponse is for
        ///   - updateHandler: The handler used to update the object
        ///   - object: The new value of the upated object
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                       UpdateResponse,
                                       ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                      decoders: [LittleWebServerObjectDecoder],
                                                      firstDecoderDefault: Bool = false,
                                                      getHandler: @escaping (_ request: HTTP.Request) throws -> Object,
                                                      updateHandler: @escaping (_ request: HTTP.Request,
                                                                                _ object: Object) throws -> UpdateResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ErrorResponse: Encodable {
            
            return { (_ path: LittleWebServerRoutePathConditions,
                      _ controller: LittleWebServer.Routing.Requests.RouteController) in
            
                
                controller.get[path] = self.shareObject(encoders: encoders,
                                                        handler: getHandler,
                                                        errorResponse: errorResponse)
                
                
                
                controller.post[path] = self.updateObject(encoders: encoders,
                                                          decoders: decoders,
                                                          firstDecoderDefault: firstDecoderDefault,
                                                          handler: updateHandler,
                                                          errorResponse: errorResponse)
                
            }
            
        }
        /*
        /// Share an updatable object
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - getHandler: The handler used to get the object
        ///   - request: The request the reponse is for
        ///   - updateHandler: The handler used to update the object
        ///   - object: The new value of the upated object
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                       UpdateResponse,
                                       ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                      decoders: LittleWebServerObjectDecoder...,
                                                      firstDecoderDefault: Bool = false,
                                                      getHandler: @escaping (_ request: HTTP.Request) throws -> Object,
                                                      updateHandler: @escaping (_ request: HTTP.Request,
                                                                                _ object: Object) throws -> UpdateResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ErrorResponse: Encodable {
            
            return self.shareObject(encoders: encoders,
                                    decoders: decoders,
                                    firstDecoderDefault: firstDecoderDefault,
                                    getHandler: getHandler,
                                    updateHandler: updateHandler,
                                    errorResponse: errorResponse)
        }
        */
        
        
        /// Share an updatable object
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the updated object
        ///   - decodeWithContentMissMatch: Indicator if should use the first decoder if none match
        ///   - getHandler: The handler used to get the object
        ///   - request: The request the reponse is for
        ///   - updateHandler: The handler used to update the object
        ///   - object: The new value of the upated object
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                       UpdateResponse,
                                       ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                      decoder: LittleWebServerObjectDecoder,
                                                      decodeWithContentMissMatch: Bool = true,
                                                      getHandler: @escaping (_ request: HTTP.Request) throws -> Object,
                                                      updateHandler: @escaping (_ request: HTTP.Request,
                                                                                _ object: Object) throws -> UpdateResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ErrorResponse: Encodable {
            
            return self.shareObject(encoders: [encoder],
                                    decoders: [decoder],
                                    firstDecoderDefault: decodeWithContentMissMatch,
                                    getHandler: getHandler,
                                    updateHandler: updateHandler,
                                    errorResponse: errorResponse)
            
        }
        
        /// Share an updatable object
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - getHandler: The handler used to get the object
        ///   - request: The request the reponse is for
        ///   - updateHandler: The handler used to update the object
        ///   - object: The new value of the upated object
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                       UpdateResponse,
                                       ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                      decoders: [LittleWebServerObjectDecoder],
                                                      firstDecoderDefault: Bool = false,
                                                      object: @escaping @autoclosure () throws -> Object,
                                                      updateHandler: @escaping (_ object: Object) throws -> UpdateResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ErrorResponse: Encodable {
            
            
            
            return self.shareObject(encoders: encoders,
                                    decoders: decoders,
                                    getHandler: { _ in return try object() },
                                    updateHandler: { _, obj in return try updateHandler(obj) },
                                    errorResponse: errorResponse)
            
        }
        /*
        /// Share an updatable object
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - getHandler: The handler used to get the object
        ///   - request: The request the reponse is for
        ///   - updateHandler: The handler used to update the object
        ///   - object: The new value of the upated object
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                       UpdateResponse,
                                       ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                      decoders: LittleWebServerObjectDecoder...,
                                                      firstDecoderDefault: Bool = false,
                                                      object: @escaping @autoclosure () throws -> Object,
                                                      updateHandler: @escaping (_ object: Object) throws -> UpdateResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ErrorResponse: Encodable {
            
            return self.shareObject(encoders: encoders,
                                    decoders: decoders,
                                    firstDecoderDefault: firstDecoderDefault,
                                    object: try object(),
                                    updateHandler: updateHandler,
                                    errorResponse: errorResponse)
        }
        */
        
        
        /// Share an updatable object
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the updated object
        ///   - decodeWithContentMissMatch: Indicator if should use the first decoder if none match
        ///   - getHandler: The handler used to get the object
        ///   - request: The request the reponse is for
        ///   - updateHandler: The handler used to update the object
        ///   - object: The new value of the upated object
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                       UpdateResponse,
                                       ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                      decoder: LittleWebServerObjectDecoder,
                                                      decodeWithContentMissMatch: Bool = true,
                                                      object: @escaping @autoclosure () throws -> Object,
                                                      updateHandler: @escaping (_ object: Object) throws -> UpdateResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ErrorResponse: Encodable {
            
            return self.shareObject(encoders: [encoder],
                                    decoders: [decoder],
                                    firstDecoderDefault: decodeWithContentMissMatch,
                                    object: try object(),
                                    updateHandler: updateHandler,
                                    errorResponse: errorResponse)
            
        }
        
        
        
        
        /// Share an updatable object
        ///
        /// Access to the object will be thread safe to ensure the data
        ///
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - objectLock: The lock to use to synchronize access to the objects list
        ///   - object: Pointer to the object to share
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                       ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                      decoders: [LittleWebServerObjectDecoder],
                                                      firstDecoderDefault: Bool = false,
                                                      objectLock: NSLock = NSLock(),
                                                      object: UnsafeMutablePointer<Object>,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ErrorResponse: Encodable {
            
            return { (_ path: LittleWebServerRoutePathConditions,
                      _ controller: LittleWebServer.Routing.Requests.RouteController) in
            
                // Lock for access to the object
                func getObject(_ request: HTTP.Request) -> Object {
                    objectLock.lock()
                    defer { objectLock.unlock() }
                    return object.pointee
                }
                func updateObject(_ request: HTTP.Request, _ obj: Object) -> Void {
                    objectLock.lock()
                    defer { objectLock.unlock() }
                    object.pointee = obj
                }
                
                controller.get[path] = self.shareObject(encoders: encoders,
                                                        handler: getObject,
                                                        errorResponse: errorResponse)
                
                
                
                controller.post[path] = self.updateObject(encoders: encoders,
                                                          decoders: decoders,
                                                          firstDecoderDefault: firstDecoderDefault,
                                                          handler: updateObject,
                                                          errorResponse: errorResponse)
                
            }
            
        }
        
        /*
        /// Share an updatable object
        ///
        /// Access to the object will be thread safe to ensure the data
        ///
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - objectLock: The lock to use to synchronize access to the objects list
        ///   - object: Pointer to the object to share
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                       ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                      decoders: LittleWebServerObjectDecoder...,
                                                      firstDecoderDefault: Bool = false,
                                                      objectLock: NSLock = NSLock(),
                                                      object: UnsafeMutablePointer<Object>,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ErrorResponse: Encodable {
            return self.shareObject(encoders: encoders,
                                    decoders: decoders,
                                    firstDecoderDefault: firstDecoderDefault,
                                    objectLock: objectLock,
                                    object: object,
                                    errorResponse: errorResponse)
        }
        */
        /// Share an updatable object
        ///
        /// Access to the object will be thread safe to ensure the data
        ///
        /// - Parameters:
        ///   - encoder: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoder: A list of supported content type decoders
        ///   - decodeWithContentMissMatch: Indicator if should use the first decoder if none match
        ///   - objectLock: The lock to use to synchronize access to the objects list
        ///   - object: Pointer to the object to share
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                       ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                      decoder: LittleWebServerObjectDecoder,
                                                      decodeWithContentMissMatch: Bool = true,
                                                      objectLock: NSLock = NSLock(),
                                                      object: UnsafeMutablePointer<Object>,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ErrorResponse: Encodable {
            return self.shareObject(encoders: [encoder],
                                    decoders: [decoder],
                                    firstDecoderDefault: decodeWithContentMissMatch,
                                    objectLock: objectLock,
                                    object: object,
                                    errorResponse: errorResponse)
        }
        

        
        /// Share objects beginning at the given path
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - addObjectDecoder: An optional methd used to decode new objects to be added to the list, if not provided the default decoding process will occur
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - listHandler: The handler used to get a list of all objects
        ///   - request: The request the reponse is for
        ///   - getHandler: The handler used to get a specific object
        ///   - objectId: The object id of the object being looked for
        ///   - addHandler: The handler used to add a new object to the list
        ///   - addObject: The new object to add to the list
        ///   - updateHandler: The handler used to update an existing object
        ///   - updateObject: The object to update
        ///   - deleteHandler: The handler used to delete an object
        ///   - notFoundResponse: The object not found handler
        ///   - stringId: The string id of the object being looked for
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func sharePathObjects<Object,
                                            ObjectId,
                                            AddResponse,
                                            UpdateResponse,
                                            DeleteResponse,
                                            NotFoundResponse,
                                            ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                      decoders: [LittleWebServerObjectDecoder],
                                                      firstDecoderDefault: Bool = false,
                                                      addObjectDecoder: ((_ decoders: [LittleWebServerObjectDecoder],
                                                                         _ request: HTTP.Request) throws -> AddObjectDecoderResponse<Object>)? = nil,
                                                      listHandler: @escaping (_ request: HTTP.Request) throws -> [Object],
                                                      getHandler: @escaping (_ request: HTTP.Request,
                                                                             _ objectId: ObjectId) throws -> Object?,
                                                      addHandler: @escaping (_ request: HTTP.Request,
                                                                             _ addObject: Object) throws -> AddResponse,
                                                      updateHandler: @escaping (_ request: HTTP.Request,
                                                                                _ objectId: ObjectId,
                                                                                _ updateObject: Object) throws -> UpdateResponse,
                                                      deleteHandler: @escaping (_ request: HTTP.Request,
                                                                                _ objectId: ObjectId) throws -> DeleteResponse,
                                                      notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                   _ stringId: String,
                                                                                   _ objectId: ObjectId?) -> NotFoundResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            return { (_ path: LittleWebServerRoutePathConditions,
                      _ controller: LittleWebServer.Routing.Requests.RouteController) in
            
            
               
                controller.get[path] = self.listObjects(encoders: encoders,
                                                        handler: listHandler,
                                                        errorResponse: errorResponse)
                         
                if let decodeFnc = addObjectDecoder {
                    
                    let dFunc = { (_ request: HTTP.Request) throws -> AddObjectDecoderResponse<Object> in
                        return try decodeFnc(decoders, request)
                    }
                    
                    controller.put[path] = self.addObject(encoders: encoders,
                                                           decoder: dFunc,
                                                           handler: addHandler,
                                                           errorResponse: errorResponse)
                
                
                    controller.post[path] = self.addObject(encoders: encoders,
                                                           decoder: dFunc,
                                                           handler: addHandler,
                                                           errorResponse: errorResponse)
                    
                } else {
                    controller.put[path] = self.addObject(encoders: encoders,
                                                           decoders: decoders,
                                                           firstDecoderDefault: firstDecoderDefault,
                                                           handler: addHandler,
                                                           errorResponse: errorResponse)
                
                
                    controller.post[path] = self.addObject(encoders: encoders,
                                                           decoders: decoders,
                                                           firstDecoderDefault: firstDecoderDefault,
                                                           handler: addHandler,
                                                           errorResponse: errorResponse)
                }
                
                controller.get[path + ":id"] = self.getPathObject(encoders: encoders,
                                                                  handler: getHandler,
                                                                  notFoundResponse: notFoundResponse,
                                                                  errorResponse: errorResponse)
                
                
                
                controller.post[path + ":id"] = self.updatePathObject(encoders: encoders,
                                                                     decoders: decoders,
                                                                     firstDecoderDefault: firstDecoderDefault,
                                                                     handler: updateHandler,
                                                                     notFoundResponse: notFoundResponse,
                                                                     errorResponse: errorResponse)
                
                
                controller.delete[path + ":id"] = self.deletePathObject(encoders: encoders,
                                                                        handler: deleteHandler,
                                                                        notFoundResponse: notFoundResponse,
                                                                        errorResponse: errorResponse)
            }
            
        }
        
        /*
        /// Share objects beginning at the given path
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - addObjectDecoder: An optional methd used to decode new objects to be added to the list, if not provided the default decoding process will occur
        ///   - listHandler: The handler used to get a list of all objects
        ///   - request: The request the reponse is for
        ///   - getHandler: The handler used to get a specific object
        ///   - objectId: The object id of the object being looked for
        ///   - addHandler: The handler used to add a new object to the list
        ///   - addObject: The new object to add to the list
        ///   - updateHandler: The handler used to update an existing object
        ///   - updateObject: The object to update
        ///   - deleteHandler: The handler used to delete an object
        ///   - notFoundResponse: The object not found handler
        ///   - stringId: The string id of the object being looked for
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func sharePathObjects<Object,
                                            ObjectId,
                                            AddResponse,
                                            UpdateResponse,
                                            DeleteResponse,
                                            NotFoundResponse,
                                            ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                           decoders: LittleWebServerObjectDecoder...,
                                                           firstDecoderDefault: Bool = false,
                                                           addObjectDecoder: ((_ decoders: [LittleWebServerObjectDecoder],
                                                                              _ request: HTTP.Request) throws -> AddObjectDecoderResponse<Object>)? = nil,
                                                      listHandler: @escaping (_ request: HTTP.Request) throws -> [Object],
                                                      getHandler: @escaping (_ request: HTTP.Request,
                                                                             _ objectId: ObjectId) throws -> Object?,
                                                      addHandler: @escaping (_ request: HTTP.Request,
                                                                             _ addObject: Object) throws -> AddResponse,
                                                      updateHandler: @escaping (_ request: HTTP.Request,
                                                                                _ objectId: ObjectId,
                                                                                _ updateObject: Object) throws -> UpdateResponse,
                                                      deleteHandler: @escaping (_ request: HTTP.Request,
                                                                                _ objectId: ObjectId) throws -> DeleteResponse,
                                                      notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                   _ stringId: String,
                                                                                   _ objectId: ObjectId?) -> NotFoundResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            return self.sharePathObjects(encoders: encoders,
                                         decoders: decoders,
                                         firstDecoderDefault: firstDecoderDefault,
                                         addObjectDecoder: addObjectDecoder,
                                         listHandler: listHandler,
                                         getHandler: getHandler,
                                         addHandler: addHandler,
                                         updateHandler: updateHandler,
                                         deleteHandler: deleteHandler,
                                         notFoundResponse: notFoundResponse,
                                         errorResponse: errorResponse)
            
        }
        */
        /// Share objects beginning at the given path
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the objects
        ///   - decodeWithContentMissMatch: Indicator if should use the first decoder if none match
        ///   - addObjectDecoder: An optional methd used to decode new objects to be added to the list, if not provided the default decoding process will occur
        ///   - listHandler: The handler used to get a list of all objects
        ///   - request: The request the reponse is for
        ///   - getHandler: The handler used to get a specific object
        ///   - objectId: The object id of the object being looked for
        ///   - addHandler: The handler used to add a new object to the list
        ///   - addObject: The new object to add to the list
        ///   - updateHandler: The handler used to update an existing object
        ///   - updateObject: The object to update
        ///   - deleteHandler: The handler used to delete an object
        ///   - notFoundResponse: The object not found handler
        ///   - stringId: The string id of the object being looked for
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func sharePathObjects<Object,
                                            ObjectId,
                                            AddResponse,
                                            UpdateResponse,
                                            DeleteResponse,
                                            NotFoundResponse,
                                            ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                      decoder: LittleWebServerObjectDecoder,
                                                      decodeWithContentMissMatch: Bool = true,
                                                      addObjectDecoder: ((_ decoder: LittleWebServerObjectDecoder,
                                                                         _ request: HTTP.Request) throws -> AddObjectDecoderResponse<Object>)? = nil,
                                                      listHandler: @escaping (_ request: HTTP.Request) throws -> [Object],
                                                      getHandler: @escaping (_ request: HTTP.Request,
                                                                             _ objectId: ObjectId) throws -> Object?,
                                                      addHandler: @escaping (_ request: HTTP.Request,
                                                                             _ addObject: Object) throws -> AddResponse,
                                                      updateHandler: @escaping (_ request: HTTP.Request,
                                                                                _ objectId: ObjectId,
                                                                                _ updateObject: Object) throws -> UpdateResponse,
                                                      deleteHandler: @escaping (_ request: HTTP.Request,
                                                                                _ objectId: ObjectId) throws -> DeleteResponse,
                                                      notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                   _ stringId: String,
                                                                                   _ objectId: ObjectId?) -> NotFoundResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            var fnc: ((_ decoders: [LittleWebServerObjectDecoder], _ request: HTTP.Request) throws -> AddObjectDecoderResponse<Object>)? = nil
            if let d = addObjectDecoder {
                fnc = { decoders, request in
                    return try d(decoders.first!, request)
                }
            }
            return self.sharePathObjects(encoders: [encoder],
                                         decoders: [decoder],
                                         firstDecoderDefault: decodeWithContentMissMatch,
                                         addObjectDecoder: fnc,
                                         listHandler: listHandler,
                                         getHandler: getHandler,
                                         addHandler: addHandler,
                                         updateHandler: updateHandler,
                                         deleteHandler: deleteHandler,
                                         notFoundResponse: notFoundResponse,
                                         errorResponse: errorResponse)
        }
        
        
   
        
        /// Share objects beginning at the given path
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - addObjectDecoder: An optional methd used to decode new objects to be added to the list, if not provided the default decoding process will occur
        ///   - listHandler: The handler used to get a list of all objects
        ///   - request: The request the reponse is for
        ///   - getHandler: The handler used to get a specific object
        ///   - objectId: The object id of the object being looked for
        ///   - addHandler: The handler used to add a new object to the list
        ///   - addObject: The new object to add to the list
        ///   - updateHandler: The handler used to update an existing object
        ///   - updateObject: The object to update
        ///   - deleteHandler: The handler used to delete an object
        ///   - notFoundResponse: The object not found handler
        ///   - stringId: The string id of the object being looked for
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func sharePathObjects<Object,
                                            ObjectId,
                                            AddResponse,
                                            UpdateResponse,
                                            DeleteResponse,
                                            NotFoundResponse,
                                            ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                      decoders: [LittleWebServerObjectDecoder],
                                                      firstDecoderDefault: Bool = false,
                                                      addObjectDecoder: ((_ decoders: [LittleWebServerObjectDecoder], _ request: HTTP.Request) throws -> AddObjectDecoderResponse<Object>)? = nil,
                                                      listHandler: @escaping @autoclosure () throws -> [Object],
                                                      getHandler: @escaping (_ objectId: ObjectId) throws -> Object?,
                                                      addHandler: @escaping (_ addObject: Object) throws -> AddResponse,
                                                      updateHandler: @escaping (_ objectId: ObjectId,
                                                                                _ updateObject: Object) throws -> UpdateResponse,
                                                      deleteHandler: @escaping (_ objectId: ObjectId) throws -> DeleteResponse,
                                                      notFoundResponse: @escaping (_ stringId: String,
                                                                                   _ objectId: ObjectId?) -> NotFoundResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            return self.sharePathObjects(encoders: encoders,
                                         decoders: decoders,
                                         firstDecoderDefault: firstDecoderDefault,
                                         addObjectDecoder: addObjectDecoder,
                                         listHandler: { _ in return try listHandler() },
                                         getHandler: { _, id in return try getHandler(id) },
                                         addHandler: { _, obj in return try addHandler(obj) },
                                         updateHandler: { _, id, obj in return try updateHandler(id, obj) },
                                         deleteHandler: {_, id in return try deleteHandler(id) },
                                         notFoundResponse: { _, sId, oId in return notFoundResponse(sId, oId) },
                                         errorResponse: errorResponse)
            
        }
        
        /*
        /// Share objects beginning at the given path
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - addObjectDecoder: An optional methd used to decode new objects to be added to the list, if not provided the default decoding process will occur
        ///   - listHandler: The handler used to get a list of all objects
        ///   - request: The request the reponse is for
        ///   - getHandler: The handler used to get a specific object
        ///   - objectId: The object id of the object being looked for
        ///   - addHandler: The handler used to add a new object to the list
        ///   - addObject: The new object to add to the list
        ///   - updateHandler: The handler used to update an existing object
        ///   - updateObject: The object to update
        ///   - deleteHandler: The handler used to delete an object
        ///   - notFoundResponse: The object not found handler
        ///   - stringId: The string id of the object being looked for
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func sharePathObjects<Object,
                                            ObjectId,
                                            AddResponse,
                                            UpdateResponse,
                                            DeleteResponse,
                                            NotFoundResponse,
                                            ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                           decoders: LittleWebServerObjectDecoder...,
                                                           firstDecoderDefault: Bool = false,
                                                           addObjectDecoder: ((_ decoders: [LittleWebServerObjectDecoder],
                                                                              _ request: HTTP.Request) throws -> AddObjectDecoderResponse<Object>)? = nil,
                                                      listHandler: @escaping @autoclosure () throws -> [Object],
                                                      getHandler: @escaping (_ objectId: ObjectId) throws -> Object?,
                                                      addHandler: @escaping (_ addObject: Object) throws -> AddResponse,
                                                      updateHandler: @escaping (_ objectId: ObjectId,
                                                                                _ updateObject: Object) throws -> UpdateResponse,
                                                      deleteHandler: @escaping (_ objectId: ObjectId) throws -> DeleteResponse,
                                                      notFoundResponse: @escaping (_ stringId: String,
                                                                                   _ objectId: ObjectId?) -> NotFoundResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            return self.sharePathObjects(encoders: encoders,
                                         decoders: decoders,
                                         firstDecoderDefault: firstDecoderDefault,
                                         addObjectDecoder: addObjectDecoder,
                                         listHandler: try listHandler(),
                                         getHandler: getHandler,
                                         addHandler: addHandler,
                                         updateHandler: updateHandler,
                                         deleteHandler: deleteHandler,
                                         notFoundResponse: notFoundResponse,
                                         errorResponse: errorResponse)
            
        }
        */
        
        /// Share objects beginning at the given path
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the objects
        ///   - decodeWithContentMissMatch: Indicator if should use the first decoder if none match
        ///   - addObjectDecoder: An optional methd used to decode new objects to be added to the list, if not provided the default decoding process will occur
        ///   - listHandler: The handler used to get a list of all objects
        ///   - request: The request the reponse is for
        ///   - getHandler: The handler used to get a specific object
        ///   - objectId: The object id of the object being looked for
        ///   - addHandler: The handler used to add a new object to the list
        ///   - addObject: The new object to add to the list
        ///   - updateHandler: The handler used to update an existing object
        ///   - updateObject: The object to update
        ///   - deleteHandler: The handler used to delete an object
        ///   - notFoundResponse: The object not found handler
        ///   - stringId: The string id of the object being looked for
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func sharePathObjects<Object,
                                            ObjectId,
                                            AddResponse,
                                            UpdateResponse,
                                            DeleteResponse,
                                            NotFoundResponse,
                                            ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                      decoder: LittleWebServerObjectDecoder,
                                                      decodeWithContentMissMatch: Bool = true,
                                                      addObjectDecoder: ((_ decoder: LittleWebServerObjectDecoder,
                                                                         _ request: HTTP.Request) throws -> AddObjectDecoderResponse<Object>)? = nil,
                                                      listHandler: @escaping @autoclosure () throws -> [Object],
                                                      getHandler: @escaping (_ objectId: ObjectId) throws -> Object?,
                                                      addHandler: @escaping (_ addObject: Object) throws -> AddResponse,
                                                      updateHandler: @escaping (_ objectId: ObjectId,
                                                                                _ updateObject: Object) throws -> UpdateResponse,
                                                      deleteHandler: @escaping (_ objectId: ObjectId) throws -> DeleteResponse,
                                                      notFoundResponse: @escaping (_ stringId: String,
                                                                                   _ objectId: ObjectId?) -> NotFoundResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ObjectId: LosslessStringConvertible,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            var decodeNObject: ((_ decoders: [LittleWebServerObjectDecoder], _ request: HTTP.Request) throws -> AddObjectDecoderResponse<Object>)? = nil
            if let d = addObjectDecoder {
                decodeNObject = { decoders, request in
                    return try d(decoders.first!, request)
                }
            }
            
            return self.sharePathObjects(encoders: [encoder],
                                         decoders: [decoder],
                                         firstDecoderDefault: decodeWithContentMissMatch,
                                         addObjectDecoder: decodeNObject,
                                         listHandler: try listHandler(),
                                         getHandler: getHandler,
                                         addHandler: addHandler,
                                         updateHandler: updateHandler,
                                         deleteHandler: deleteHandler,
                                         notFoundResponse: notFoundResponse,
                                         errorResponse: errorResponse)
        }
        
        
        
        /// The addition methods to add to the share objects
        public enum SharePathObjectsAccessors {
            case add
            case update
            case delete
        }
        
        /// Share objects beginning at the given path
        ///
        /// Access to the objects will be thread safe to ensure the data
        ///
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - objectLock: The lock to use to synchronize access to the objects list
        ///   - addObjectDecoder: An optional methd used to decode new objects to be added to the list, if not provided the default decoding process will occur
        ///   - objects: The pointer to the array of objects to share
        ///   - accessors: A set of all accessors allowed (add, udpate, delete)
        ///   - objectExistError: Handler that reutrns a Swift error that indicates an object with the given Id already exists
        ///   - notFoundResponse: The object not found handler
        ///   - request: The request accessing the given resource(s)
        ///   - stringId: The string id of the object being looked for
        ///   - objectId: The object id of the object being looked for
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func sharePathObjects<Object,
                                            ObjectId,
                                            ObjectExistsError,
                                            NotFoundResponse,
                                            ErrorResponse>(encoders: [LittleWebServerObjectEncoder],
                                                      decoders: [LittleWebServerObjectDecoder],
                                                      firstDecoderDefault: Bool = false,
                                                      objectLock: NSLock = NSLock(),
                                                      addObjectDecoder: ((_ decoders: [LittleWebServerObjectDecoder],
                                                                         _ request: HTTP.Request,
                                                                         _ objectLock: NSLock) throws -> AddObjectDecoderResponse<Object>)? = nil,
                                                      objects: UnsafeMutablePointer<[Object]>,
                                                      accessors: Set<SharePathObjectsAccessors> = [.add, .update, .delete],
                                                      objectExistError: @escaping (ObjectId) -> ObjectExistsError,
                                                      objectSorter: ((_ lhs: Object, _ rhs: Object) -> Bool)? = nil,
                                                      notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                   _ stringId: String,
                                                                                   _ objectId: ObjectId?) -> NotFoundResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  Object: LittleWebServerIdentifiableObject,
                  Object.ID == ObjectId,
                  ObjectId: LosslessStringConvertible,
                  ObjectExistsError: Swift.Error,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            func listObjects(_ request: HTTP.Request) -> [Object] {
                objectLock.lock()
                defer { objectLock.unlock() }
                return objects.pointee
            }
            func getObject(_ request: HTTP.Request, _ id: ObjectId) -> Object? {
                objectLock.lock()
                defer { objectLock.unlock() }
                return objects.pointee.first(where: { $0.id == id })
            }
            
            func addObject(_ request: HTTP.Request, _ object: Object) throws -> Object {
                objectLock.lock()
                defer { objectLock.unlock() }
                guard !objects.pointee.contains(where: { return $0.id == object.id }) else {
                    throw objectExistError(object.id)
                }
                objects.pointee.append(object)
                if let s = objectSorter {
                    objects.pointee.sort(by: s)
                }
                return object
            }
            
            
            
            func updateObject(_ request: HTTP.Request, _ id: ObjectId, _ obj: Object) -> Object {
                objectLock.lock()
                defer { objectLock.unlock() }
                objects.pointee.removeAll(where: { $0.id == id })
                objects.pointee.append(obj)
                return obj
            }
            
            func deleteObject(_ request: HTTP.Request, _ id: ObjectId) -> Void {
                objectLock.lock()
                defer { objectLock.unlock() }
                objects.pointee.removeAll(where: { $0.id == id })
            }
            
            return { (_ path: LittleWebServerRoutePathConditions,
                      _ controller: LittleWebServer.Routing.Requests.RouteController) in
            
            
                controller.get[path] = self.listObjects(encoders: encoders,
                                                        handler: listObjects,
                                                        errorResponse: errorResponse)
                     
                
                if accessors.contains(.add) {
                    if let decodeFnc = addObjectDecoder {
                        
                        let dFunc = { (_ request: HTTP.Request) throws -> AddObjectDecoderResponse<Object> in
                            return try decodeFnc(decoders, request, objectLock)
                        }
                        
                        controller.put[path] = self.addObject(encoders: encoders,
                                                               decoder: dFunc,
                                                               handler: addObject,
                                                               errorResponse: errorResponse)
                        
                        controller.post[path] = self.addObject(encoders: encoders,
                                                               decoder: dFunc,
                                                               handler: addObject,
                                                               errorResponse: errorResponse)
                        
                    } else {
                        controller.put[path] = self.addObject(encoders: encoders,
                                                               decoders: decoders,
                                                               firstDecoderDefault: firstDecoderDefault,
                                                               handler: addObject,
                                                               errorResponse: errorResponse)
                        
                        controller.post[path] = self.addObject(encoders: encoders,
                                                               decoders: decoders,
                                                               firstDecoderDefault: firstDecoderDefault,
                                                               handler: addObject,
                                                               errorResponse: errorResponse)
                    }
                }
                
                controller.get[path + ":id"] = self.getPathObject(encoders: encoders,
                                                                  handler: getObject,
                                                                  notFoundResponse: notFoundResponse,
                                                                  errorResponse: errorResponse)
                
                
                if accessors.contains(.update) {
                    controller.put[path + ":id"] = self.updatePathObject(encoders: encoders,
                                                                         decoders: decoders,
                                                                         firstDecoderDefault: firstDecoderDefault,
                                                                         handler: updateObject,
                                                                         notFoundResponse: notFoundResponse,
                                                                         errorResponse: errorResponse)
                    
                    controller.post[path + ":id"] = self.updatePathObject(encoders: encoders,
                                                                         decoders: decoders,
                                                                         firstDecoderDefault: firstDecoderDefault,
                                                                         handler: updateObject,
                                                                         notFoundResponse: notFoundResponse,
                                                                         errorResponse: errorResponse)
                }
                
                
                if accessors.contains(.delete) {
                    controller.delete[path + ":id"] = self.deletePathObject(encoders: encoders,
                                                                            handler: deleteObject,
                                                                            notFoundResponse: notFoundResponse,
                                                                            errorResponse: errorResponse)
                }
            }
            
        }
        /*
        /// Share objects beginning at the given path
        ///
        /// Access to the objects will be thread safe to ensure the data
        ///
        /// - Parameters:
        ///   - encoders: A list of supported content type encoders (Default will be the first encoder)
        ///   - decoders: A list of supported content type decoders
        ///   - firstDecoderDefault: Indicator if should use the first decoder if none match
        ///   - objectLock: The lock to use to synchronize access to the objects list
        ///   - addObjectDecoder: An optional methd used to decode new objects to be added to the list, if not provided the default decoding process will occur
        ///   - objects: The pointer to the array of objects to share
        ///   - accessors: A set of all accessors allowed (add, udpate, delete)
        ///   - objectExistError: Handler that reutrns a Swift error that indicates an object with the given Id already exists
        ///   - notFoundResponse: The object not found handler
        ///   - request: The request accessing the given resource(s)
        ///   - stringId: The string id of the object being looked for
        ///   - objectId: The object id of the object being looked for
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func sharePathObjects<Object,
                                            ObjectId,
                                            ObjectExistsError,
                                            NotFoundResponse,
                                            ErrorResponse>(encoders: LittleWebServerObjectEncoder...,
                                                           decoders: LittleWebServerObjectDecoder...,
                                                      firstDecoderDefault: Bool = false,
                                                      objectLock: NSLock = NSLock(),
                                                      addObjectDecoder: ((_ decoders: [LittleWebServerObjectDecoder],
                                                                         _ request: HTTP.Request,
                                                                         _ objectLock: NSLock) throws -> AddObjectDecoderResponse<Object>)? = nil,
                                                      objects: UnsafeMutablePointer<[Object]>,
                                                      accessors: Set<SharePathObjectsAccessors> = [.add, .update, .delete],
                                                      objectExistError: @escaping (ObjectId) -> ObjectExistsError,
                                                      objectSorter: ((_ lhs: Object, _ rhs: Object) -> Bool)? = nil,
                                                      notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                   _ stringId: String,
                                                                                   _ objectId: ObjectId?) -> NotFoundResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  Object: LittleWebServerIdentifiableObject,
                  Object.ID == ObjectId,
                  ObjectId: LosslessStringConvertible,
                  ObjectExistsError: Swift.Error,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            return self.sharePathObjects(encoders: encoders,
                                         decoders: decoders,
                                         firstDecoderDefault: firstDecoderDefault,
                                         objectLock: objectLock,
                                         addObjectDecoder: addObjectDecoder,
                                         objects: objects,
                                         accessors: accessors,
                                         objectExistError: objectExistError,
                                         objectSorter: objectSorter,
                                         notFoundResponse: notFoundResponse,
                                         errorResponse: errorResponse)
        }
        */
        
        /// Share objects beginning at the given path
        ///
        /// Access to the objects will be thread safe to ensure the data
        ///
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the objects
        ///   - decodeWithContentMissMatch: Indicator if should use the first decoder if none match
        ///   - objectLock: The lock to use to synchronize access to the objects list
        ///   - addObjectDecoder: An optional methd used to decode new objects to be added to the list, if not provided the default decoding process will occur
        ///   - objects: The pointer to the array of objects to share
        ///   - accessors: A set of all accessors allowed (add, udpate, delete)
        ///   - objectExistError: Handler that reutrns a Swift error that indicates an object with the given Id already exists
        ///   - notFoundResponse: The object not found handler
        ///   - request: The request accessing the given resource(s)
        ///   - stringId: The string id of the object being looked for
        ///   - objectId: The object id of the object being looked for
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func sharePathObjects<Object,
                                            ObjectId,
                                            ObjectExistsError,
                                            NotFoundResponse,
                                            ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                           decoder: LittleWebServerObjectDecoder,
                                                           decodeWithContentMissMatch: Bool = true,
                                                           objectLock: NSLock = NSLock(),
                                                           addObjectDecoder: ((_ decoder: LittleWebServerObjectDecoder,
                                                                              _ request: HTTP.Request,
                                                                              _ objectLock: NSLock) throws -> AddObjectDecoderResponse<Object>)? = nil,
                                                      objects: UnsafeMutablePointer<[Object]>,
                                                      accessors: Set<SharePathObjectsAccessors> = [.add, .update, .delete],
                                                      objectExistError: @escaping (ObjectId) -> ObjectExistsError,
                                                      objectSorter: ((_ lhs: Object, _ rhs: Object) -> Bool)? = nil,
                                                      notFoundResponse: @escaping (_ request: HTTP.Request,
                                                                                   _ stringId: String,
                                                                                   _ objectId: ObjectId?) -> NotFoundResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  Object: LittleWebServerIdentifiableObject,
                  Object.ID == ObjectId,
                  ObjectId: LosslessStringConvertible,
                  ObjectExistsError: Swift.Error,
                  NotFoundResponse: Encodable,
                  ErrorResponse: Encodable {
            
            var fnc: ((_ decoders: [LittleWebServerObjectDecoder],
                       _ request: HTTP.Request,
                       _ objectLock: NSLock) throws -> AddObjectDecoderResponse<Object>)? = nil
            if let d = addObjectDecoder {
                fnc = { decoders, request, objectLock in
                    return try d(decoders.first!, request, objectLock)
                }
            }
            
            return self.sharePathObjects(encoders: [encoder],
                                         decoders: [decoder],
                                         firstDecoderDefault: decodeWithContentMissMatch,
                                         objectLock: objectLock,
                                         addObjectDecoder: fnc,
                                         objects: objects,
                                         accessors: accessors,
                                         objectExistError: objectExistError,
                                         objectSorter: objectSorter,
                                         notFoundResponse: notFoundResponse,
                                         errorResponse: errorResponse)
        }
    }
}
