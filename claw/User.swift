import Foundation
import SwiftUI
import MDText

class UserFetcher: ObservableObject {
    @Published var user: NewestUser? = nil
    var username: String
    
    init(_ username: String) {
        self.username = username
        load()
    }
    
    func load() {
        let url = URL(string: "https://lobste.rs/u/" + self.username + ".json")!
            
                URLSession.shared.dataTask(with: url) {(data,response,error) in
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
                }.resume()
    }
}

struct UserView: View {
    var user: NewestUser
    
    var body: some View {
        List {
            HStack {
                Text("Karma").bold()
                Text("\(user.karma)")
            }
            if let username = user.github_username {
                HStack {
                    Text("GitHub").bold()
                    Link(destination: URL(string: "https://github.com/" + username)!, label: {
                        Text(username).foregroundColor(.accentColor)
                    })
                }
            }
            if let username = user.twitter_username {
                HStack {
                    Text("Twitter").bold()
                    Link(destination: URL(string: "https://twitter.com/" + username)!, label: {
                        Text("@" + username).foregroundColor(.accentColor)
                    })
                }
            }
            if !user.about.isEmpty {
                VStack(alignment: .leading) {
                    Text("About").bold()
                    MDText(markdown: user.about).padding()
                }
            }
        }.navigationBarTitle(user.username)
    }
}
