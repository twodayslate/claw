//
//  ContentView.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import SwiftUI
import CoreData
import WebKit
import SwiftDB


struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selection = 0
    
    @StateObject var container = PersistentContainer(SettingsSchema())
    
    var body: some View {
        TabView(selection: $selection) {
            HottestView().tabItem {
                selection == 0 ? Image(systemName: "flame.fill") : Image(systemName: "flame")
                Text("Hottest")
            }.tag(0)
            NewestView().tabItem {
                selection == 1 ? Image(systemName: "burst.fill") : Image(systemName: "burst")
                Text("Newest")
            }.tag(1)
            SettingsView().persistentContainer(container).tabItem { Image(systemName: "gear")
                Text("Settings")
            }.tag(2)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
