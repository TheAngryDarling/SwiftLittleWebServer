//
//  Date+LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-19.
//

import Foundation

internal extension Date {
    
    static var now: Date { return Date() }
    
    static var yesterday: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: .now)!
    }

    static var tomorrow: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: .now)!
    }
    
}
