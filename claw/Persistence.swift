import Foundation
import CoreData
import SwiftUI

public class ViewedItem: NSManagedObject, Identifiable {
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


extension ViewedItem {
    // ❇️ The @FetchRequest property wrapper in the ContentView will call this function
    static func fetchAllRequest() -> NSFetchRequest<ViewedItem> {
        let request: NSFetchRequest<ViewedItem> = ViewedItem.fetchRequest() as! NSFetchRequest<ViewedItem>
        
        // ❇️ The @FetchRequest property wrapper in the ContentView requires a sort descriptor
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

        return request
    }
}

public enum Browser: Int16 {
    case inAppSafari = 0
    case defaultBrowser = 1
}

public class Settings: NSManagedObject, Identifiable {
    @NSManaged public var layoutValue: Double
    @NSManaged public var timestamp: Date
    @NSManaged public var alternateIconName: String?
    @NSManaged public var accentColorData: Data?
    @NSManaged public var textSizeModifier: Double
    @NSManaged public var browserRawValue: Int16
    @NSManaged public var readerMode: Bool

    convenience init(context: NSManagedObjectContext) {
        guard let entity = NSEntityDescription.entity(forEntityName: "Settings", in: context) else {
            fatalError("No entity named Settings")
        }
        self.init(entity: entity, insertInto: context)
        self.layoutValue = Settings.Layout.Default.rawValue
        self.timestamp = Date()
        self.alternateIconName = nil
        self.accentColorData = UIColor.init(red: 158.0/255.0, green: 38.0/255.0, blue: 27.0/255.0, alpha: 1.0).data
        self.textSizeModifier = 0.0
    }
    
    enum Layout: Double, Equatable, Comparable {
        static func < (lhs: Settings.Layout, rhs: Settings.Layout) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
        case compact = 0.0
        case comfortable = 1.0
        case Default = 2.0
    }
    
    var layout: Layout {
        return Layout(rawValue: self.layoutValue) ?? Layout.Default
    }
    
    var defaultAccentColor: UIColor {
        return UIColor.init(red: 158.0/255.0, green: 38.0/255.0, blue: 27.0/255.0, alpha: 1.0)
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
    
    var browser: Browser {
        get {
            return Browser(rawValue: self.browserRawValue) ?? .inAppSafari
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
}

extension Settings {
    // ❇️ The @FetchRequest property wrapper in the ContentView will call this function
    static func fetchAllRequest() -> NSFetchRequest<Settings> {
        let request: NSFetchRequest<Settings> = Settings.fetchRequest() as! NSFetchRequest<Settings>
        
        // ❇️ The @FetchRequest property wrapper in the ContentView requires a sort descriptor
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        return request
    }
}

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Settings(context: viewContext)
            newItem.timestamp = Date()
        }
        
        let item = ViewedItem(context: viewContext)
        item.timestamp = Date()
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "claw")
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
