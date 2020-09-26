import SwiftUI
import Combine

class UserFetcher: ObservableObject {
    @Published var user: NewestUser? = nil
    var username: String
    
    init(_ username: String) {
        self.username = username
        load()
    }
    
    deinit {
        self.session?.cancel()
    }
    
    private var session: URLSessionTask? = nil
    
    func load() {
        let url = URL(string: "https://lobste.rs/u/" + self.username + ".json")!
            
        self.session = URLSession.shared.dataTask(with: url) {(data,response,error) in
                    do {
                        if let d = data {
                            let decodedLists = try JSONDecoder().decode(NewestUser.self, from: d)
                            DispatchQueue.main.async {
                                self.user = decodedLists
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
