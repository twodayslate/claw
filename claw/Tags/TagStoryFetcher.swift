import Foundation
import SwiftUI

class TagStoryFetcher: ObservableObject {
    @Published var stories = TagStoryFetcher.cachedStories
    
    static var cachedStories = [NewestStory]()
    
    @Published var isLoadingMore = false
    
    
    var tags: [String]
    
    init(tags: [String]) {
        self.tags = tags
    }
    
    deinit {
        self.session?.cancel()
        self.moreSession?.cancel()
    }
    
    private var session: URLSessionTask? = nil
    private var moreSession: URLSessionTask? = nil
    
    func load() {
        let url = URL(string: "https://lobste.rs/t/\(self.tags.joined(separator: ",")).json?page=\(self.page)")!
        self.session?.cancel()
        self.session = URLSession.shared.dataTask(with: url) {(data,response,error) in
                    do {
                        if let d = data {
                            let decodedLists = try JSONDecoder().decode([NewestStory].self, from: d)
                            DispatchQueue.main.async {
                                TagStoryFetcher.cachedStories = decodedLists
                                self.stories = decodedLists
                            }
                        }else {
                            print("No Data")
                        }
                    } catch {
                        print ("Error fetching tag story \(error) \(url)")
                    }
                }
        self.session?.resume()
    }

    var page: Int = 1

    func more(_ story: NewestStory? = nil) {
        if self.stories.last == story && !isLoadingMore {
            self.isLoadingMore = true
            let url = URL(string: "https://lobste.rs/t/\(self.tags.joined(separator: ",")).json?page=\(self.page)")!

            self.moreSession = URLSession.shared.dataTask(with: url) { (data,response,error) in
                do {
                    if let d = data {
                        let decodedLists = try JSONDecoder().decode([NewestStory].self, from: d)
                        DispatchQueue.main.async {
                            let stories = decodedLists
                            for story in stories {
                                if !self.stories.contains(story) {
                                    self.stories.append(story)
                                }
                            }
                            TagStoryFetcher.cachedStories = self.stories
                            self.page += 1
                        }
                    }else {
                        print("No Data")
                    }
                } catch {
                    print ("Error fetching tag story more \(error)")
                }
                DispatchQueue.main.async {
                    self.isLoadingMore = false
                }
            }
            self.moreSession?.resume()
        }
    }
}
