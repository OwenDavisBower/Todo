//
//  Item.swift
//  todo
//
//  Created by Owen Davis-Bower on 6/6/26.
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
