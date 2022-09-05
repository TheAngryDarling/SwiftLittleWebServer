//
//  SyncLock+LittleWebServer.swift
//  
//
//  Created by Tyler Anger on 2022-08-28.
//

import Foundation

internal extension _SyncLock where Object: Collection, Object.Element: LittleWebServer.Routing.RouteBase {
    func first(withPathCondition condition: Object.Element.RoutePathConditionComponent) -> Object.Element? {
        return self.lockingForWithValue { ptr in
            return ptr.pointee.first(withPathCondition: condition)
        }
    }
}
