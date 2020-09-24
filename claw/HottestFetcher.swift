import Foundation
import SwiftUI

class HottestFetcher: ObservableObject {
    @Published var stories = HottestFetcher.cachedStories
    
    static var cachedStories = [NewestStory]()
    
    init() {
        load()
    }
    
    deinit {
        self.session?.cancel()
    }
    
    private var session: URLSessionTask? = nil
    
    func load() {
        let url = URL(string: "https://lobste.rs/hottest.json")!
            
        self.session = URLSession.shared.dataTask(with: url) {(data,response,error) in
                    do {
                        if let d = data {
                            let decodedLists = try JSONDecoder().decode([NewestStory].self, from: d)
                            DispatchQueue.main.async {
                                HottestFetcher.cachedStories = decodedLists
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
