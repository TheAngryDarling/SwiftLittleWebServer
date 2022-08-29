//
//  SynchronizableStorage+LittleWebServer.swift
//  
//
//  Created by Tyler Anger on 2022-08-28.
//

import Foundation
import SynchronizeObjects

internal extension SynchronizableObject where Storage: Collection, Storage.Element: LittleWebServer.Routing.RouteBase {
    func first(withPathCondition condition: Storage.Element.RoutePathConditionComponent) -> Storage.Element? {
        return self.lockingForWithValue { ptr in
            return ptr.pointee.first(withPathCondition: condition)
        }
    }
}
