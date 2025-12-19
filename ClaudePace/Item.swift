//
//  Item.swift
//  ClaudePace
//
//  Created by fold-out-couch.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
