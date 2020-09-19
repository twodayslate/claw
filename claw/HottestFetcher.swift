import Foundation
import SwiftUI

class HottestFetcher: ObservableObject {
    @Published var stories = [NewestStory]()
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
                                self.stories = decodedLists
                            }
                        }else {
                            print("No Data")
                        }
                    } catch {
                        print ("Error \(error)")
                        if let data = data {
                            print(String(data: data, encoding: .utf8))
                        }
                    }
                }
        self.session?.resume()
    }
}
