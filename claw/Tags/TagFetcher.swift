import Foundation
import SwiftUI

class TagFetcher: ObservableObject {
    @Published var tags = TagFetcher.cachedTags
    
    static var cachedTags = [Tag]()
        
    static var shared = TagFetcher()
    
    init() {
        self.load()
    }
    
    deinit {
        self.session?.cancel()
    }
    
    private var session: URLSessionTask? = nil
    private var moreSession: URLSessionTask? = nil
    
    func loadIfEmpty() {
        if self.tags.count <= 0 {
            load()
        }
    }
    
    func load() {
        let url = URL(string: "https://lobste.rs/tags.json")!
        
        self.session = URLSession.shared.dataTask(with: url) {(data,response,error) in
                    do {
                        if let d = data {
                            let decodedLists = try JSONDecoder().decode([Tag].self, from: d)
                            DispatchQueue.main.async {
                                let sorted = decodedLists.sorted(by: {$0.tag < $1.tag})
                                TagFetcher.cachedTags = sorted
                                self.tags = sorted
                            }
                        }else {
                            print("No Data for tag")
                        }
                    } catch {
                        print ("Error fetching tag \(error)")
                    }
                }
        self.session?.resume()
    }
}
