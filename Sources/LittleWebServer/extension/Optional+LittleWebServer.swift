//
//  Optional+LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-19.
//

import Foundation

internal extension Optional where Wrapped == Date {
    static var now: Date { return .now }
    static var yesterday: Date { return Date.yesterday }
    static var tomorrow: Date { return Date.tomorrow }
}
