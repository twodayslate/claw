import Foundation
import CoreData
import SwiftUI

public class CoreDataViewedItem: NSManagedObject, Identifiable {
    @NSManaged public var short_id: String
    @NSManaged public var isStory: Bool
    @NSManaged public var isComment: Bool
    @NSManaged public var timestamp: Date
    
    convenience init(context: NSManagedObjectContext, short_id: String, isStory: Bool = false, isComment: Bool = false) {
        guard let entity = NSEntityDescription.entity(forEntityName: "ViewedItem", in: context) else {
            fatalError("No entity named Settings")
        }
        self.init(entity: entity, insertInto: context)
        self.short_id = short_id
        self.isStory = isStory
        self.isComment = isComment
        self.timestamp = Date()
    }
}


extension CoreDataViewedItem {
    // ❇️ The @FetchRequest property wrapper in the ContentView will call this function
    static func fetchAllRequest() -> NSFetchRequest<CoreDataViewedItem> {
        let request: NSFetchRequest<CoreDataViewedItem> = CoreDataViewedItem.fetchRequest() as! NSFetchRequest<CoreDataViewedItem>

        // ❇️ The @FetchRequest property wrapper in the ContentView requires a sort descriptor
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

        return request
    }
}

public class CoreDataSettings: NSManagedObject, Identifiable {
    @NSManaged public var layoutValue: Double
    @NSManaged public var timestamp: Date
    @NSManaged public var alternateIconName: String?
    @NSManaged public var accentColorData: Data?
    @NSManaged public var textSizeModifier: Double
    @NSManaged public var browserRawValue: Int16
    @NSManaged public var readerMode: Bool
    @NSManaged public var commentColor: Data?

    convenience init(context: NSManagedObjectContext) {
        guard let entity = NSEntityDescription.entity(forEntityName: "Settings", in: context) else {
            fatalError("No entity named Settings")
        }
        self.init(entity: entity, insertInto: context)
        self.layoutValue = LayoutSetting.Default.rawValue
        self.timestamp = Date()
        self.alternateIconName = nil
        self.accentColorData = UIColor.lobsterRed.data
        self.textSizeModifier = 0.0
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
            try? self.managedObjectContext?.save()
        }
    }
    
    var browser: BrowserSetting {
        get {
            return BrowserSetting(rawValue: self.browserRawValue) ?? .inAppSafari
        }
        set {
            self.browserRawValue = newValue.rawValue
            try? self.managedObjectContext?.save()
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
            try? self.managedObjectContext?.save()
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
            try? self.managedObjectContext?.save()
        }
    }
}

extension CoreDataSettings {
    // ❇️ The @FetchRequest property wrapper in the ContentView will call this function
    static func fetchAllRequest() -> NSFetchRequest<CoreDataSettings> {
        let request: NSFetchRequest<CoreDataSettings> = CoreDataSettings.fetchRequest() as! NSFetchRequest<CoreDataSettings>

        // ❇️ The @FetchRequest property wrapper in the ContentView requires a sort descriptor
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        return request
    }
}

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: Bundle.main.name)
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                Typical reasons for an error here include:
                * The parent directory does not exist, cannot be created, or disallows writing.
                * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                * The device is out of space.
                * The store could not be migrated to the current model version.
                Check the error message to determine what the actual problem was.
                */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
    }
}
