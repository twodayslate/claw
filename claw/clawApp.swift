//
//  clawApp.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import SwiftUI

@main
struct clawApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
