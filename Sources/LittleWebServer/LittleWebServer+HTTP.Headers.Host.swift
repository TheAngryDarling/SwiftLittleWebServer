//
//  LittleWebServer+HTTP.Headers.Host.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-07-19.
//

import Foundation

public func + (lhs: String, rhs: LittleWebServer.HTTP.Headers.Host.Name) -> String {
    return lhs + rhs.description
}
public func += (lhs: inout String, rhs: LittleWebServer.HTTP.Headers.Host.Name) {
    return lhs = lhs + rhs.description
}

public func + (lhs: String, rhs: LittleWebServer.HTTP.Headers.Host) -> String {
    return lhs + rhs.description
}
public func += (lhs: inout String, rhs: LittleWebServer.HTTP.Headers.Host) {
    return lhs = lhs + rhs.description
}

