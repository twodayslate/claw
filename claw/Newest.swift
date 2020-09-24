//
//  newest.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import Foundation
import SwiftUI

class NewestFetcher: ObservableObject {
    @Published var stories = NewestFetcher.cachedStories
    static var cachedStories = [NewestStory]()
    
    init() {
        load()
    }
    
    deinit {
        self.session?.cancel()
    }
    
    private var session: URLSessionTask? = nil
    
    func load() {
        let url = URL(string: "https://lobste.rs/newest.json")!
    self.session = URLSession.shared.dataTask(with: url) {(data,response,error) in
                do {
                    if let d = data {
                        let decodedLists = try JSONDecoder().decode([NewestStory].self, from: d)
                        DispatchQueue.main.async {
                            NewestFetcher.cachedStories = decodedLists
                            self.stories = decodedLists
                        }
                    }else {
                        print("No Data")
                    }
                } catch {
                    print ("Error \(error)")
                }
            }
        self.session?.resume()
    }
}

struct NewestView: View {
    @ObservedObject var newest = NewestFetcher()
    @EnvironmentObject var settings: Settings
    var body: some View {
        NavigationView {
            List {
                ForEach(newest.stories) { story in
                    StoryListCellView(story: story).environmentObject(settings)
                }
            }.navigationBarTitle("Newest")
        }
    }
}
