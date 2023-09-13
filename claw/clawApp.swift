//
//  clawApp.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import SwiftUI
import UIKit

@main
struct clawApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    // this should go in the app/scene delegate if we had one
                    UIColor.additionalNameMapping[UIColor.lobsterRed] = "Lobsters Red"
                    _ = StoreKitModel.pro
                }
        }
    }
}
