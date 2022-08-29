//
//  Collection+LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-07-11.
//

import Foundation

internal extension Collection {
    #if !swift(>=4.2)
    func firstIndex(where condition: (Element) -> Bool) -> Index? {
        for (index, value) in self.enumerated() {
            if condition(value) { return (index as! Self.Index) }
        }
        return nil
    }
    #endif
}

internal extension Collection where Element: LittleWebServer.Routing.RouteBase {
    func first(withPathCondition condition: Element.RoutePathConditionComponent) -> Element? {
        return self.first(where: { return $0.condition == condition} )
    }
}
