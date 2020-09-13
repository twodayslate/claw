import Foundation
import SwiftUI

//{"short_id":"hompz5","short_id_url":"https://lobste.rs/s/hompz5","created_at":"2020-09-11T20:33:59.000-05:00","title":"Find Duplicates in an Array","url":"https://dev.to/hminaya/find-duplicates-in-an-array-2lbo","score":1,"flags":0,"comment_count":0,"description":"","comments_url":"https://lobste.rs/s/hompz5/find_duplicates_array","submitter_user":{"username":"pxlet","created_at":"2019-04-26T14:25:28.000-05:00","is_admin":false,"about":"Check out https://pxlet.com","is_moderator":false,"karma":456,"avatar_url":"/avatars/pxlet-100.png","invited_by_user":"lukas"},"tags":["javascript"]},


class HottestFetcher: ObservableObject {
    @Published var stories = [NewestStory]()
    init() {
        load()
    }
    
    func load() {
        let url = URL(string: "https://lobste.rs/hottest.json")!
            
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

struct HottestView: View {
    @ObservedObject var hottest = HottestFetcher()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(hottest.stories) { story in
                    SGNavigationLink(destination: StoryView(story)) {
                        StoryCell(story: story)
                    }
                }
            }.navigationBarTitle("Hottest")
        }
    }
}
