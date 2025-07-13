//
//  clawApp.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import SwiftUI
import UIKit
import ConfettiSwiftUI
import SwiftData

@main
struct clawApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject var storeModel = StoreKitModel.pro
    @State var confetti = 0
    @AppStorage("owned-confetti") var owned = false
    
    // SwiftData controller - only initialize if migration is completed
    @State private var migrationInProgress = false
    @State private var migrationError: Error?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(PersistenceControllerV2.shared.container)
            .onAppear {
                // this should go in the app/scene delegate if we had one
                UIColor.additionalNameMapping[UIColor.lobsterRed] = "Lobsters Red"
                
                // Check if migration is needed
                Task {
                    await checkAndPerformMigration()
                }
            }
            .onChange(of: storeModel.owned) {
                if storeModel.owned, storeModel.hasInitialized, owned != storeModel.owned {
                    confetti = confetti + 1
                }
                owned = storeModel.owned
            }
            .confettiCannon(counter: $confetti, num: 100)
        }
    }
    
    // MARK: - Migration Logic
    
    @MainActor
    private func checkAndPerformMigration() async {
        // Check if Core Data has any data
        let hasExistingData = await checkForExistingCoreData()
        
        if hasExistingData {
            // Perform migration
            await performMigration()
        }
    }
    
    private func checkForExistingCoreData() async -> Bool {
        return await withCheckedContinuation { continuation in
            persistenceController.container.viewContext.perform {
                do {
                    // Check for existing ViewedItems
                    let viewedItemsRequest = CoreDataViewedItem.fetchAllRequest()
                    viewedItemsRequest.fetchLimit = 1
                    let viewedItems = try persistenceController.container.viewContext.fetch(viewedItemsRequest)
                    
                    // Check for existing Settings
                    let settingsRequest = CoreDataSettings.fetchAllRequest()
                    settingsRequest.fetchLimit = 1
                    let settings = try persistenceController.container.viewContext.fetch(settingsRequest)
                    
                    let hasData = !viewedItems.isEmpty || !settings.isEmpty
                    continuation.resume(returning: hasData)
                } catch {
                    print("Error checking for existing Core Data: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    @MainActor
    private func performMigration() async {
        migrationInProgress = true
        migrationError = nil
        
        do {
            let swiftDataController = PersistenceControllerV2.shared
            // Perform the actual migration
            try await swiftDataController.migrateFromCoreData(persistenceController)

            migrationInProgress = false
            
            print("✅ Migration to SwiftData completed successfully")
            
        } catch {
            print("❌ Migration failed: \(error)")
            migrationError = error
            migrationInProgress = false
        }
    }
    
    // MARK: - Migration Error Types

    enum MigrationError: LocalizedError {
        case swiftDataInitializationFailed
        case migrationFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .swiftDataInitializationFailed:
                return "Failed to initialize SwiftData"
            case .migrationFailed(let error):
                return "Migration failed: \(error.localizedDescription)"
            }
        }
    }
}
