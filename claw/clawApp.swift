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
    @AppStorage("owned-confetti") var owned = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    // this should go in the app/scene delegate if we had one
                    UIColor.additionalNameMapping[UIColor.lobsterRed] = "Lobsters Red"
                }
                .onChange(of: storeModel.owned) { isOwned in
                    if isOwned, storeModel.hasInitialized, owned != isOwned {
                        confetti = confetti + 1
                    }
                    owned = isOwned
                }
                .confettiCannon(counter: $confetti, num: 100)

        }
    }
}
