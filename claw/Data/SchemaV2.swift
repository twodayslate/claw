//
//  SchemaV2.swift
//  claw
//
//  Created by Zachary Gorak on 7/13/25.
//

import SwiftData

enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            ViewedItemV2.self,
            SettingsV2.self
        ]
    }
}
