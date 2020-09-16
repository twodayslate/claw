import Foundation
import SwiftUI

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
