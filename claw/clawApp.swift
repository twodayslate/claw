//
//  clawApp.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import SwiftUI
import UIKit
import ConfettiSwiftUI

@main
struct clawApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject var storeModel = StoreKitModel.pro
    @State var confetti = 0
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    // this should go in the app/scene delegate if we had one
                    UIColor.additionalNameMapping[UIColor.lobsterRed] = "Lobsters Red"
                }
                .onChange(of: storeModel.products) { products in
                    Task {
                        try await Task.sleep(for: .seconds(5))
                    }
                }
                .onChange(of: storeModel.owned) { isOwned in
                    if isOwned, storeModel.hasInitialized {
                        confetti = confetti + 1
                    }
                }
                .confettiCannon(counter: $confetti, num: 100)

        }
    }
}
