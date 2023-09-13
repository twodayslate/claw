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
    @NSManaged public var commentColor: Data?

    convenience init(context: NSManagedObjectContext) {
        guard let entity = NSEntityDescription.entity(forEntityName: "Settings", in: context) else {
            fatalError("No entity named Settings")
        }
        self.init(entity: entity, insertInto: context)
        self.layoutValue = Settings.Layout.Default.rawValue
        self.timestamp = Date()
        self.alternateIconName = nil
        self.accentColorData = UIColor.lobsterRed.data
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

    enum CommentColorScheme: Codable, Equatable{
        case `default`
        case red
        case blue
        case purple
        case custom(UIColor, UIColor, UIColor, UIColor, UIColor, UIColor, UIColor)
        case label
        case green
        case gray
        case yellow
        case teal
        case orange
        case indigo
        case mint
        //UIColor.label, UIColor.systemRed, UIColor.systemBlue, UIColor.systemGreen, UIColor.systemGray, UIColor.systemYellow, UIColor.systemTeal, UIColor.systemOrange, UIColor.systemPurple, UIColor.systemIndigo, UIColor.systemMint

        var colors: [Color] {
            switch self {
            case .default:
                return [Color.blue, Color.green, Color.orange, Color.pink, Color.red, Color.yellow, Color.purple].map { $0.opacity(0.5) }
            case .red:
                return [Color.red.opacity(1.0), Color.red.opacity(0.9), Color.red.opacity(0.8), Color.red.opacity(0.7), Color.red.opacity(0.6), Color.red.opacity(0.5), Color.red.opacity(0.4)]
            case .blue:
                return [Color.blue.opacity(1.0), Color.blue.opacity(0.9), Color.blue.opacity(0.8), Color.blue.opacity(0.7), Color.blue.opacity(0.6), Color.blue.opacity(0.5), Color.blue.opacity(0.4)]
            case .green:
                return [Color.green.opacity(1.0), Color.green.opacity(0.9), Color.green.opacity(0.8), Color.green.opacity(0.7), Color.green.opacity(0.6), Color.green.opacity(0.5), Color.green.opacity(0.4)]
            case .purple:
                return [Color.purple.opacity(1.0), Color.purple.opacity(0.9), Color.purple.opacity(0.8), Color.purple.opacity(0.7), Color.purple.opacity(0.6), Color.purple.opacity(0.5), Color.purple.opacity(0.4)]
            case let .custom(one, two, three, four, five, six, seven):
                return [one, two, three, four, five, six, seven].map { Color($0) }
            case .label:
                return [Color(UIColor.label).opacity(1.0), Color(UIColor.label).opacity(0.9), Color(UIColor.label).opacity(0.8), Color(UIColor.label).opacity(0.7), Color(UIColor.label).opacity(0.6), Color(UIColor.label).opacity(0.4), Color(UIColor.label).opacity(0.4)]
            case .gray:
                return [Color.gray.opacity(1.0), Color.gray.opacity(0.9), Color.gray.opacity(0.8), Color.gray.opacity(0.7), Color.gray.opacity(0.6), Color.gray.opacity(0.5), Color.gray.opacity(0.4)]
            case .yellow:
                return [Color.yellow.opacity(1.0), Color.yellow.opacity(0.9), Color.yellow.opacity(0.8), Color.yellow.opacity(0.7), Color.yellow.opacity(0.6), Color.yellow.opacity(0.5), Color.yellow.opacity(0.4)]
            case .teal:
                return [Color.teal.opacity(1.0), Color.teal.opacity(0.9), Color.teal.opacity(0.8), Color.teal.opacity(0.7), Color.teal.opacity(0.6), Color.teal.opacity(0.5), Color.teal.opacity(0.4)]
            case .orange:
                return [Color.orange.opacity(1.0), Color.orange.opacity(0.9), Color.orange.opacity(0.8), Color.orange.opacity(0.7), Color.orange.opacity(0.6), Color.orange.opacity(0.5), Color.orange.opacity(0.4)]
            case .indigo:
                return [Color.indigo.opacity(1.0), Color.indigo.opacity(0.9), Color.indigo.opacity(0.8), Color.indigo.opacity(0.7), Color.indigo.opacity(0.6), Color.indigo.opacity(0.5), Color.indigo.opacity(0.4)]
            case .mint:
                return [Color.mint.opacity(1.0), Color.mint.opacity(0.9), Color.mint.opacity(0.8), Color.mint.opacity(0.7), Color.mint.opacity(0.6), Color.mint.opacity(0.5), Color.mint.opacity(0.4)]
            }

        }

        var name: String {
            switch self {
            case .default: return "Default"
            case .purple: return "Purple"
            case .blue: return "Blue"
            case .red: return "Red"
            case .label: return "Primary"
            case .green: return "Green"
            case .gray: return "Gray"
            case .yellow: return "Yellow"
            case .custom(_, _, _, _, _, _, _): return "Custom"
            case .teal:
                return "Teal"
            case .orange:
                return "Orange"
            case .indigo:
                return "Indigo"
            case .mint:
                return "Mint"
            }
        }

        var numbered: Int {
            switch self {
            case .default: return 0
            case .red: return 1
            case .custom(_, _, _, _, _, _, _): return 2
            case .blue: return 3
            case .purple: return 4
            case .label: return 5
            case .green: return 6
            case .gray: return 7
            case .yellow:
                return 8
            case .teal:
                return 9
            case .orange:
                return 10
            case .indigo:
                return 11
            case .mint:
                return 12
            }
        }

        enum CodingKeys: String, CodingKey {
            case type

            case data
          }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(numbered, forKey: .type)
            switch self {
            case let .custom(one, two, three, four, five, six, seven):
                let values = [one, two, three, four, five, six, seven]
                let dataMap = values.compactMap { $0.data }
                let data = try JSONEncoder().encode(dataMap)
                try container.encode(data, forKey: .data)
            default:
                break
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let type = try container.decode(Int.self, forKey: .type)

            switch type {
            case CommentColorScheme.default.numbered:
                self = .default
            case CommentColorScheme.red.numbered:
                self = .red
            case CommentColorScheme.blue.numbered:
                self = .blue
            case CommentColorScheme.purple.numbered:
                self = .purple
            case CommentColorScheme.label.numbered:
                self = .label
            case CommentColorScheme.green.numbered:
                self = .green
            case CommentColorScheme.gray.numbered:
                self = .gray
            case CommentColorScheme.yellow.numbered:
                self = .yellow
            case CommentColorScheme.teal.numbered:
                self = .teal
            case CommentColorScheme.orange.numbered:
                self = .orange
            case CommentColorScheme.indigo.numbered:
                self = .indigo
            case CommentColorScheme.mint.numbered:
                self = .mint
            default:
                let data = try container.decode(Data.self, forKey: .data)
                let unwrapped = try JSONDecoder().decode([Data].self, from: data)
                let values: [UIColor] = unwrapped.compactMap { colorData in
                    guard let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) else {
                        return nil
                    }
                    return color
                }
                if values.count < 7 {
                    throw URLError(.cannotDecodeRawData)
                }
                self = .custom(values[0], values[1], values[2], values[3], values[4], values[5], values[6])
            }
        }
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
