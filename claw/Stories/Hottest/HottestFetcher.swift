import Foundation
import SwiftUI

class HottestFetcher: ObservableObject {
    @Published var stories = HottestFetcher.cachedStories
    
    static var cachedStories = [NewestStory]()
    
    @Published var isLoadingMore = false
    @Published var isReloading = false
    
    // we need a shared object as a not singleton will be deinitialized after about 2
    // navigation views deep
    static var shared = HottestFetcher()
    
    init() {
        load()
    }
    
    deinit {
        self.session?.cancel()
        self.moreSession?.cancel()
    }
    
    private var session: URLSessionTask? = nil
    private var moreSession: URLSessionTask? = nil
    
    func reload() {
        self.session?.cancel()
        self.page = 1
        self.isReloading = true
        self.load(completion: { _ in
            DispatchQueue.main.async {
                self.isReloading = false
            }
        })
    }
    
    func load(completion: ((Error?)->Void)? = nil) {
        let url = URL(string: "https://lobste.rs/hottest.json?page=\(self.page)")!
        
        self.session = URLSession.shared.dataTask(with: url) {(data,response,error) in
                    do {
                        if let d = data {
                            let decodedLists = try JSONDecoder().decode([NewestStory].self, from: d)
                            DispatchQueue.main.async {
                                HottestFetcher.cachedStories = decodedLists
                                self.stories = decodedLists
                                self.page += 1
                                completion?(nil)
                            }
                        }else {
                            print("No Data")
                            completion?(nil) // todo: actually throw an error
                        }
                    } catch {
                        print ("Error fetching hottest \(error)")
                        completion?(error)
                    }
                }
        self.session?.resume()
    }

    var page: Int = 1

    func more(_ story: NewestStory? = nil, completion: ((Error?)->Void)? = nil) {
        if self.stories.last == story && !isLoadingMore {
            self.isLoadingMore = true
            let url = URL(string: "https://lobste.rs/hottest.json?page=\(self.page)")!

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
                            HottestFetcher.cachedStories = self.stories
                            self.page += 1
                            completion?(nil)
                        }
                    }else {
                        print("No Data")
                        completion?(nil) // todo: throw actual error
                    }
                } catch {
                    print ("Error fetching hottest more \(error)")
                    completion?(error)
                }
                DispatchQueue.main.async {
                    self.isLoadingMore = false
                }
            }
            self.moreSession?.resume()
        }
    }
}
