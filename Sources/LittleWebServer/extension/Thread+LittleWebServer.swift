//
//  Thread+LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-31.
//

import Foundation

public class LittleWebServerCurrentDetails: NSObject {
    /// Access to the LittleWebServer used in the given thread
    public internal(set) var webServer: LittleWebServer? = nil
    /// Access to the current RouteController used in the given thread
    public internal(set) var routeController: LittleWebServer.Routing.Requests.RouteController? = nil
    /// Access to the current request used in the given thread
    public internal(set) var request: LittleWebServer.HTTP.Request? = nil
}

extension Thread {
    /// Access to the current LittleWebServer Current Details for the given thread
    public var littleWebServerDetails: LittleWebServerCurrentDetails {
        get {
            if let c = self.threadDictionary["LittleWebServer.current.details"] as? LittleWebServerCurrentDetails {
                return c
            } else {
                let rtn = LittleWebServerCurrentDetails()
                self.threadDictionary["LittleWebServer.current.details"] = rtn
                return rtn
            }
        }
    }
}
