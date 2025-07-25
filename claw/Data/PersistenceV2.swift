import Foundation
import CoreData
import SwiftData
import SwiftUI

// MARK: - SwiftData Models

@Model
public class ViewedItemV2 {
    @Attribute(.unique) var short_id: String
    var isStory: Bool
    var isComment: Bool
    var timestamp: Date
    
    init(short_id: String, isStory: Bool = false, isComment: Bool = false) {
        self.short_id = short_id
        self.isStory = isStory
        self.isComment = isComment
        self.timestamp = Date()
    }
}

@Model
public class SettingsV2 {
    var timestamp: Date

    var layoutValue: Double {
        didSet {
            timestamp = .now
        }
    }
    var alternateIconName: String? {
        didSet {
            timestamp = .now
        }
    }
    var accentColorData: Data? {
        didSet {
            timestamp = .now
        }
    }
    var textSizeModifier: Double {
        didSet {
            timestamp = .now
        }
    }
    var browserRawValue: Int {
        didSet {
            timestamp = .now
        }
    }
    var readerMode: Bool {
        didSet {
            timestamp = .now
        }
    }
    var commentColor: Data? {
        didSet {
            timestamp = .now
        }
    }

    init() {
        self.layoutValue = LayoutSetting.Default.rawValue
        self.timestamp = Date()
        self.alternateIconName = nil
        self.accentColorData = UIColor.lobsterRed.data
        self.textSizeModifier = 0.0
        self.browserRawValue = Int(BrowserSetting.inAppSafari.rawValue)
        self.readerMode = false
        self.commentColor = nil
    }
    
    var layout: LayoutSetting {
        return LayoutSetting(rawValue: self.layoutValue) ?? LayoutSetting.Default
    }
    
    var defaultAccentColor: UIColor {
        return UIColor.lobsterRed
    }
    
    var readerModeEnabled: Bool {
        get {
            return self.readerMode
        }
        set {
            self.readerMode = newValue
        }
    }
    
    var browser: BrowserSetting {
        get {
            return BrowserSetting(rawValue: Int16(self.browserRawValue)) ?? .inAppSafari
        }
        set {
            self.browserRawValue = Int(newValue.rawValue)
        }
    }
    
    var accentUIColor: UIColor {
        get {
            guard let data = self.accentColorData  else {
                return defaultAccentColor
            }
            guard let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) else {
                return defaultAccentColor
            }
            return color
        } set {
            self.accentColorData = newValue.data
        }
    }
    
    var accentColor: Color {
        return Color(accentUIColor)
    }

    var commentColorScheme: CommentColorScheme {
        get {
            guard let data = self.commentColor  else {
                return .default
            }
            guard let colors = try? JSONDecoder().decode(CommentColorScheme.self, from: data) else {
                return .default
            }
            return colors
        }
        set {
            self.commentColor = try? JSONEncoder().encode(newValue)
        }
    }
}

// MARK: - SwiftData Persistence Controller

struct PersistenceControllerV2 {
    static let shared = PersistenceControllerV2()
    
    static var preview: PersistenceControllerV2 = {
        let result = PersistenceControllerV2(inMemory: true)
        let context = result.container.mainContext
        
        // Create sample data for previews
        for _ in 0..<10 {
            let newSettings = SettingsV2()
            context.insert(newSettings)
        }
        
        let viewedItem = ViewedItemV2(short_id: "sample123")
        context.insert(viewedItem)
        
        do {
            try context.save()
        } catch {
            print("Preview data creation failed: \(error)")
        }
        
        return result
    }()
    
    let container: ModelContainer
    
    init(inMemory: Bool = false) {
        let schema = Schema(versionedSchema: SchemaV2.self)

        let modelConfiguration: ModelConfiguration
        if inMemory {
            modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            // Enable CloudKit sync with automatic configuration
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
        }
        
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}

// MARK: - SwiftData Extensions for Querying

extension ViewedItemV2 {
    static var fetchAllDescriptor: FetchDescriptor<ViewedItemV2> {
        var descriptor = FetchDescriptor<ViewedItemV2>()
        descriptor.sortBy = [SortDescriptor(\.timestamp)]
        return descriptor
    }
    
    static func fetchDescriptor(for shortId: String) -> FetchDescriptor<ViewedItemV2> {
        var descriptor = FetchDescriptor<ViewedItemV2>(
            predicate: #Predicate { $0.short_id == shortId }
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp)]
        return descriptor
    }
}

extension SettingsV2 {
    static var fetchAllDescriptor: FetchDescriptor<SettingsV2> {
        var descriptor = FetchDescriptor<SettingsV2>()
        descriptor.sortBy = [SortDescriptor(\.timestamp)]
        return descriptor
    }
    
    static var fetchLatestDescriptor: FetchDescriptor<SettingsV2> {
        var descriptor = FetchDescriptor<SettingsV2>()
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
        descriptor.fetchLimit = 1
        return descriptor
    }
}

// MARK: - Migration Helper (Optional)

extension PersistenceControllerV2 {
    /// Helper function to migrate data from Core Data to SwiftData
    @MainActor
    func migrateFromCoreData(_ coreDataController: PersistenceController) async throws {
        let context = container.mainContext
        let coreDataContext = coreDataController.container.viewContext
        
        // Migrate ViewedItems
        let viewedItemsRequest = CoreDataViewedItem.fetchAllRequest()
        let coreDataViewedItems = try coreDataContext.fetch(viewedItemsRequest)
        if !coreDataViewedItems.isEmpty {
            print("Migrating \(coreDataViewedItems.count) viewed items to SwiftData")
            for item in coreDataViewedItems {
                let newItem = ViewedItemV2(
                    short_id: item.short_id,
                    isStory: item.isStory,
                    isComment: item.isComment
                )
                newItem.timestamp = item.timestamp
                context.insert(newItem)
            }
        }

        // Migrate Settings
        let settingsRequest = CoreDataSettings.fetchAllRequest()
        let coreDataSettings = try coreDataContext.fetch(settingsRequest)
        // Migrate the most recent settings
        if let setting = coreDataSettings.first {
            print("Migrating settings to SwiftData")
            let newSetting = SettingsV2()
            newSetting.layoutValue = setting.layoutValue
            newSetting.timestamp = .now
            newSetting.alternateIconName = setting.alternateIconName
            newSetting.accentColorData = setting.accentColorData
            newSetting.textSizeModifier = setting.textSizeModifier
            newSetting.browserRawValue = Int(setting.browserRawValue)
            newSetting.readerMode = setting.readerMode
            newSetting.commentColor = setting.commentColor
            context.insert(newSetting)
        }

        // Save SwiftData changes first
        try context.save()
        
        // After successful migration, clean up Core Data (CloudKit-safe)
        try await cleanupCoreDataWithCloudKitSync(coreDataController)
        
        print("✅ Migration completed and Core Data cleaned up successfully")
    }
    
    /// Clean up Core Data objects with proper CloudKit sync handling
    @MainActor
    private func cleanupCoreDataWithCloudKitSync(_ coreDataController: PersistenceController) async throws {
        let coreDataContext = coreDataController.container.viewContext
        
        // Delete all ViewedItems (CloudKit will sync these deletions)
        let viewedItemsRequest = CoreDataViewedItem.fetchAllRequest()
        let viewedItems = try coreDataContext.fetch(viewedItemsRequest)
        for item in viewedItems {
            coreDataContext.delete(item)
        }
        
        // Delete all Settings (CloudKit will sync these deletions)
        let settingsRequest = CoreDataSettings.fetchAllRequest()
        let settings = try coreDataContext.fetch(settingsRequest)
        for setting in settings {
            coreDataContext.delete(setting)
        }
        
        // Save Core Data context - this triggers CloudKit sync for deletions
        try coreDataContext.save()
        
        print("🧹 Core Data cleanup completed with CloudKit sync")
    }
}
