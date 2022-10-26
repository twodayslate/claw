//
//  clawApp.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import SwiftUI
import UIKit

import SimpleCommon

extension String: Identifiable {
    public var id: String {
        return self
    }
}

@main
struct clawApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    // this should go in the app/scene delegate if we had one
                    let lobstersRed = UIColor.init(red: 158.0/255.0, green: 38.0/255.0, blue: 27.0/255.0, alpha: 1.0)
                    UIColor.additionalNameMapping[lobstersRed] = "Lobsters Red"
                }
        }
    }
}
