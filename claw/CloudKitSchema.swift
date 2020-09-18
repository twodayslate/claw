//
//  CloudKitSchema.swift
//  claw
//
//  Created by Zachary Gorak on 9/18/20.
//

import Foundation
import CloudKit
import SwiftDB
import CoreData

struct SettingsEntity: Entity, Identifiable {
    @Attribute var name: String = "Settings"
    @Attribute var layoutChoice: Double = 2.0
    var id: some Hashable {
        name
    }
    
    var layoutIndex: Int {
        return max(min(Int(layoutChoice),0),2)
    }
}

struct SettingsSchema: Schema {
    var entities: Entities {
        SettingsEntity.self
    }
}
