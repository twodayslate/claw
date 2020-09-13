//
//  newest.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import Foundation
import SwiftUI

//{"short_id":"hompz5","short_id_url":"https://lobste.rs/s/hompz5","created_at":"2020-09-11T20:33:59.000-05:00","title":"Find Duplicates in an Array","url":"https://dev.to/hminaya/find-duplicates-in-an-array-2lbo","score":1,"flags":0,"comment_count":0,"description":"","comments_url":"https://lobste.rs/s/hompz5/find_duplicates_array","submitter_user":{"username":"pxlet","created_at":"2019-04-26T14:25:28.000-05:00","is_admin":false,"about":"Check out https://pxlet.com","is_moderator":false,"karma":456,"avatar_url":"/avatars/pxlet-100.png","invited_by_user":"lukas"},"tags":["javascript"]},
struct NewestStory: Codable, Identifiable {
    var id: String {
        return short_id
    }
    var short_id: String
    var short_id_url: String
    var created_at: String
    var title: String
    var url: String
    var score: Int
    var flags: Int
    var comment_count: Int
    var description: String
    var comments_url: String
    var submitter_user: NewestUser
    var tags: [String]
}

struct NewestUser: Codable, Identifiable {
    var id: String {
        return username
    }
    var username: String
    var created_at: String
    var is_admin: Bool
    var about: String
    var is_moderator: Bool
    var karma: Int
    var avatar_url: String
    var invited_by_user: String
    var github_username: String?
    var twitter_username: String?
}

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
                    NavigationLink(destination: StoryView(story)) {
                        StoryCell(story: story)
                    }
                }
            }.navigationBarTitle("Newest")
        }
    }
}
