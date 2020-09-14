import Foundation
import SwiftUI
import MDText

struct KeybaseSignatures: Codable, Identifiable {
    var id: String {
        return kb_username
    }
    var kb_username: String
    var sig_hash: String
}

struct NewestUser: Codable, Identifiable {
    var id: String {
        return username
    }
    var username: String
    var created_at: String
    var is_admin: Bool
    var about: String
    var is_moderator: Bool
    var karma: Int
    var avatar_url: String
    var invited_by_user: String
    var github_username: String?
    var twitter_username: String?
    var keybase_signatures: [KeybaseSignatures]?
}

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
            if let keybase = user.keybase_signatures {
                HStack {
                    Text("Keybase").bold()
                    VStack {
                        ForEach(keybase) { auth in
                            HStack {
                                Text("@" + auth.kb_username).foregroundColor(.accentColor).onTapGesture(count: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/, perform: {
                                    UIApplication.shared.open(URL(string: "https://keybase.io/" + auth.kb_username)!)
                                })
                                Text("\(Image(systemName: "checkmark.shield.fill"))").foregroundColor(.accentColor).onTapGesture(count: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/, perform: {
                                    UIApplication.shared.open(URL(string: "https://keybase.io/" + auth.kb_username  + "/sigchain#" + auth.sig_hash)!)
                                })
                                
                            }
                        }
                    }
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

// todo: generate submitted stories
// /newest/twodayslate.json
