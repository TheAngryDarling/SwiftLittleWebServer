//
//  ObjectSharing.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-21.
//

import Foundation
import Nillable

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
            } else if value is Encodable {
                return
            } else if let nilType = value as? Nillable.Type,
                      value != NSNull.self &&
                        nilType.wrappedType is Encodable {
                return
            } else {
                preconditionFailure("\(identifier) Result Type must be Void or a type that implements Encodable")
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
            } else if let nilValue = value as? Nillable,
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
            
            return { (_ request: HTTP.Request) -> LittleWebServer.HTTP.Response? in
                
                var errorResponseEvent: ErrorResponseEvent = .objectGetter
                do {
                    let obj = try handler(request)
                    errorResponseEvent = .encoding
                    let dta = try encoder.encode(obj)
                    return LittleWebServer.HTTP.Response.ok(body: .data(dta,
                                                                        contentType: encoder.littleWebServerContentType))
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
            
            return self.shareObject(encoder: encoder,
                                  handler: { _ in return try object() },
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
            
            return { (_ request: HTTP.Request) -> LittleWebServer.HTTP.Response? in
                guard let id = request.identities["id"] else {
                    preconditionFailure("Missing path identifier 'id'")
                }
                guard let sid = id as? String else {
                    
                    preconditionFailure("Id must be in string format.  No transformation")
                }
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
            
            return { (_ request: HTTP.Request) -> LittleWebServer.HTTP.Response? in
                
                var errorResponseEvent: ErrorResponseEvent = .listGetter
                do {
                    let objs = try handler(request)
                    errorResponseEvent = .encoding
                    
                    let dta = try encoder.encode(objs)
                    return LittleWebServer.HTTP.Response.ok(body: .data(dta,
                                                                        contentType: encoder.littleWebServerContentType))
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
        
        
        
        /// Add a new object
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the new object
        ///   - handler: The handler used to add the new object
        ///   - request: The request the reponse is for
        ///   - object: The new object to add
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func addObject<Object,
                                     AddResponse,
                                     ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                    decoder: LittleWebServerObjectDecoder,
                                                    handler: @escaping (_ request: HTTP.Request,
                                                                        _ object: Object) throws -> AddResponse,
                                                    errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Decodable,
                  ErrorResponse: Encodable {
            
            validateHandlerResponse(AddResponse.self, identifier: "Add Handler")
            
            
            return { (_ request: HTTP.Request) -> LittleWebServer.HTTP.Response? in
                guard let contentLength = request.contentLength else {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: .precondition,
                                                      error: ObjectSharingError.missingContentLength,
                                                      encoder: encoder)
                    
                }
                var errorResponseEvent: ErrorResponseEvent = .decoding
                do {
                    let dta = try request.inputStream.read(exactly: Int(contentLength))
                    let obj = try decoder.decode(Object.self, from: dta)
                    
                    var responseBody: LittleWebServer.HTTP.Response.Body = .empty
                    errorResponseEvent = .objectAdder
                    let resp = try handler(request, obj)
                    if let enc = getEncodableResponse(resp) {
                        errorResponseEvent = .encoding
                        let respDta = try encoder.encode(WrappedEncodable(enc))
                        responseBody = .data(respDta, contentType: encoder.littleWebServerContentType)
                    }
                    
                    return LittleWebServer.HTTP.Response.created(body: responseBody)
    
                } catch {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: errorResponseEvent,
                                                      error: error,
                                                      encoder: encoder)
                }
            }
        }
        
        
        /// Update an existing object
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the updated object
        ///   - handler: The handler used to update an existing object
        ///   - request: The request the reponse is for
        ///   - object: The object that was updated
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func updateObject<Object,
                                        UpdateResponse,
                                        ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                       decoder: LittleWebServerObjectDecoder,
                                                       handler: @escaping (_ request: HTTP.Request,
                                                                           _ object: Object) throws -> UpdateResponse,
                                                       errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (HTTP.Request) -> LittleWebServer.HTTP.Response?
            where Object: Decodable,
                  ErrorResponse: Encodable {
            
            validateHandlerResponse(UpdateResponse.self, identifier: "Update Handler")
            
            
            return { (_ request: HTTP.Request) -> LittleWebServer.HTTP.Response? in
                guard let contentLength = request.contentLength else {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: .precondition,
                                                      error: ObjectSharingError.missingContentLength,
                                                      encoder: encoder)
                }
                var errorResponseEvent: ErrorResponseEvent = .decoding
                do {
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
    
                } catch {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: errorResponseEvent,
                                                      error: error,
                                                      encoder: encoder)
                }
            }
        }
        
        
        /// Update an existing object at the given path
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the updated object
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
                
                guard let contentLength = request.contentLength else {
                    return self.generateErrorResponse(request: request,
                                                      handler: errorResponse,
                                                      event: .precondition,
                                                      error: ObjectSharingError.missingContentLength,
                                                      encoder: encoder)
                }
                var errorResponseEvent: ErrorResponseEvent = .decoding
                do {
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
        ///   - encoder: The encoder to use to encode the response
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
            
            validateHandlerResponse(DeleteResponse.self, identifier: "Delete Handler")
            
            return { (_ request: HTTP.Request) -> LittleWebServer.HTTP.Response? in
                guard let id = request.identities["id"] else {
                    preconditionFailure("Missing path identifier 'id'")
                }
                guard let sid = id as? String else {
                    preconditionFailure("Id must be in string format.  No transformation")
                }
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
                
                var errorResponseEvent: ErrorResponseEvent = .objectDeleter
                
                do {
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
        
        
        
        
        /// Share an updatable object
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the updated object
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
                                                      getHandler: @escaping (_ request: HTTP.Request) throws -> Object,
                                                      updateHandler: @escaping (_ request: HTTP.Request,
                                                                                _ object: Object) throws -> UpdateResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ErrorResponse: Encodable {
            
            return { (_ path: LittleWebServerRoutePathConditions,
                      _ controller: LittleWebServer.Routing.Requests.RouteController) in
            
                
                controller.get[path] = self.shareObject(encoder: encoder,
                                                        handler: getHandler,
                                                        errorResponse: errorResponse)
                
                
                
                controller.post[path] = self.updateObject(encoder: encoder,
                                                          decoder: decoder,
                                                          handler: updateHandler,
                                                          errorResponse: errorResponse)
                
            }
            
        }
        
        /// Share an updatable object
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the updated object
        ///   - object: The object to share
        ///   - updateHandler: The handler used to update the object
        ///   - object: The new value of the upated object
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                       UpdateResponse,
                                       ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                      decoder: LittleWebServerObjectDecoder,
                                                      object: @escaping @autoclosure () throws -> Object,
                                                      updateHandler: @escaping (_ object: Object) throws -> UpdateResponse,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ErrorResponse: Encodable {
            
            return self.shareObject(encoder: encoder,
                                    decoder: decoder,
                                    getHandler: { _ in return try object() },
                                    updateHandler: { _, obj in return try updateHandler(obj) },
                                    errorResponse: errorResponse)
        }
        
        /// Share an updatable object
        ///
        /// Access to the object will be thread safe to ensure the data
        ///
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the updated object
        ///   - object: Pointer to the object to share
        ///   - errorResponse: The error reponse hander used to generate an error response
        /// - Returns: Returns a Request/Response handler
        public static func shareObject<Object,
                                       ErrorResponse>(encoder: LittleWebServerObjectEncoder,
                                                      decoder: LittleWebServerObjectDecoder,
                                                      object: UnsafeMutablePointer<Object>,
                                                      errorResponse: @escaping ErrorResponseHandler<ErrorResponse>) -> (LittleWebServerRoutePathConditions,
                                                                                                                            LittleWebServer.Routing.Requests.RouteController) -> Void
            where Object: Codable,
                  ErrorResponse: Encodable {
            
            return { (_ path: LittleWebServerRoutePathConditions,
                      _ controller: LittleWebServer.Routing.Requests.RouteController) in
            
                // Lock for access to the object
                let objectLock = NSLock()
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
                
                controller.get[path] = self.shareObject(encoder: encoder,
                                                        handler: getObject,
                                                        errorResponse: errorResponse)
                
                
                
                controller.post[path] = self.updateObject(encoder: encoder,
                                                          decoder: decoder,
                                                          handler: updateObject,
                                                          errorResponse: errorResponse)
                
            }
            
        }
        
        
        /// Share objects beginning at the given path
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the objects
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
            
            
                controller.get[path] = self.listObjects(encoder: encoder,
                                                        handler: listHandler,
                                                        errorResponse: errorResponse)
                     
                
                controller.put[path] = self.addObject(encoder: encoder,
                                                       decoder: decoder,
                                                       handler: addHandler,
                                                       errorResponse: errorResponse)
                
                controller.get[path + ":id"] = self.getPathObject(encoder: encoder,
                                                                  handler: getHandler,
                                                                  notFoundResponse: notFoundResponse,
                                                                  errorResponse: errorResponse)
                
                
                
                controller.post[path + ":id"] = self.updatePathObject(encoder: encoder,
                                                                     decoder: decoder,
                                                                     handler: updateHandler,
                                                                     notFoundResponse: notFoundResponse,
                                                                     errorResponse: errorResponse)
                
                
                controller.delete[path + ":id"] = self.deletePathObject(encoder: encoder,
                                                                        handler: deleteHandler,
                                                                        notFoundResponse: notFoundResponse,
                                                                        errorResponse: errorResponse)
            }
            
        }
        
        /// Share objects beginning at the given path
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the objects
        ///   - listHandler: The handler used to get a list of all objects
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
            
            return self.sharePathObjects(encoder: encoder,
                                         decoder: decoder,
                                         listHandler: { _ in return try listHandler() },
                                         getHandler: { _, id in return try getHandler(id) },
                                         addHandler: { _, obj in return try addHandler(obj) },
                                         updateHandler: { _, id, obj in return try updateHandler(id, obj) },
                                         deleteHandler: {_, id in return try deleteHandler(id) },
                                         notFoundResponse: { _, sId, oId in return notFoundResponse(sId, oId) },
                                         errorResponse: errorResponse)
        }
        
        /// Share objects beginning at the given path
        ///
        /// Access to the objects will be thread safe to ensure the data
        ///
        
        /// - Parameters:
        ///   - encoder: The encoder to use to encode the response
        ///   - decoder: The decoder to use to decode the objects
        ///   - objects: The pointer to the array of objects to share
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
                                                      objects: UnsafeMutablePointer<[Object]>,
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
            
            let objectLock = NSLock()
            func listObject(_ request: HTTP.Request) -> [Object] {
                objectLock.lock()
                defer { objectLock.unlock() }
                return objects.pointee
            }
            func getObject(_ request: HTTP.Request, _ id: ObjectId) -> Object? {
                objectLock.lock()
                defer { objectLock.unlock() }
                return objects.pointee.first(where: { $0.id == id })
            }
            func addObject(_ request: HTTP.Request, _ object: Object) throws -> Void {
                objectLock.lock()
                defer { objectLock.unlock() }
                guard !objects.pointee.contains(where: { return $0.id == object.id }) else {
                    throw objectExistError(object.id)
                }
                objects.pointee.append(object)
                if let s = objectSorter {
                    objects.pointee.sort(by: s)
                }
            }
            func updateObject(_ request: HTTP.Request, _ id: ObjectId, _ obj: Object) -> Void {
                objectLock.lock()
                defer { objectLock.unlock() }
                objects.pointee.removeAll(where: { $0.id == id })
                objects.pointee.append(obj)
            }
            
            func deleteObject(_ request: HTTP.Request, _ id: ObjectId) -> Void {
                objectLock.lock()
                defer { objectLock.unlock() }
                objects.pointee.removeAll(where: { $0.id == id })
            }
            
            return self.sharePathObjects(encoder: encoder,
                                         decoder: decoder,
                                         listHandler: listObject,
                                         getHandler: getObject,
                                         addHandler: addObject,
                                         updateHandler: updateObject,
                                         deleteHandler: deleteObject,
                                         notFoundResponse: notFoundResponse,
                                         errorResponse: errorResponse)
        }
    }
}
