import Foundation
import SwiftUI
import Combine

class TagStoryFetcher: GenericArrayFetcher<NewestStory> {
    
    static var cachedStories = [[String]: [NewestStory]]()
    
    var tags: [String] {
        didSet {
            self.page = 1
            if let cachedStories = TagStoryFetcher.cachedStories[self.tags] {
                self.items = cachedStories
            } else {
                self.items = []
            }
        }
    }

    init(tags: [String] = []) {
        self.tags = tags
    }

    override func load() {
        super.load()
        
        if let cachedStories = TagStoryFetcher.cachedStories[self.tags] {
            self.items = cachedStories
        }

        let url = URL(string: "https://lobste.rs/t/\(self.tags.joined(separator: ",")).json?page=\(self.page)")!
                
        self.session = URLSession.shared.dataTask(with: url) {(data,response,error) in
                    do {
                        if let d = data {
                            let decodedLists = try JSONDecoder().decode([NewestStory].self, from: d)
                            DispatchQueue.main.async {
                                if TagStoryFetcher.cachedStories.count > 10 {
                                    // xxx: I'd like to remove the last used cache but this will do for now
                                    TagStoryFetcher.cachedStories.removeAll()
                                }
                                TagStoryFetcher.cachedStories[self.tags] = decodedLists
                                self.items = decodedLists
                                self.page += 1
                            }
                        }else {
                            print("No Data for tags \(self.tags)")
                        }
                    } catch {
                        print ("Error fetching tag story \(error) \(url)")
                    }
                }
        self.session?.resume()
    }

    override func more(_ story: NewestStory? = nil) {
        if self.items.last == story && !isLoadingMore {
            self.isLoadingMore = true
            let url = URL(string: "https://lobste.rs/t/\(self.tags.joined(separator: ",")).json?page=\(self.page)")!

            self.moreSession = URLSession.shared.dataTask(with: url) { (data,response,error) in
                do {
                    if let d = data {
                        let decodedLists = try JSONDecoder().decode([NewestStory].self, from: d)
                        DispatchQueue.main.async {
                            let stories = decodedLists
                            for story in stories {
                                if !self.items.contains(story) {
                                    self.items.append(story)
                                }
                            }
                            TagStoryFetcher.cachedStories[self.tags] = self.items
                            self.page += 1
                        }
                    }else {
                        print("No Data for more tags \(self.tags)")
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
