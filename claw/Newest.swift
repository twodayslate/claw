//
//  newest.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import Foundation
import SwiftUI

class NewestFetcher: ObservableObject {
    @Published var stories = [NewestStory]()
    init() {
        load()
    }
    
    func load() {
        let url = URL(string: "https://lobste.rs/newest.json")!
            
                URLSession.shared.dataTask(with: url) {(data,response,error) in
                    do {
                        if let d = data {
                            let decodedLists = try JSONDecoder().decode([NewestStory].self, from: d)
                            DispatchQueue.main.async {
                                self.stories = decodedLists
                            }
                        }else {
                            print("No Data")
                        }
                    } catch {
                        print ("Error \(error)")
                    }
                }.resume()
    }
}

struct NewestView: View {
    @ObservedObject var newest = NewestFetcher()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(newest.stories) { story in
                    SGNavigationLink(destination: StoryView(story)) {
                        StoryCell(story: story)
                    }
                }
            }.navigationBarTitle("Newest")
        }
    }
}
