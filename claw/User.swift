import Foundation
import SwiftUI
import Combine



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
            HStack(alignment: .center) {
                Spacer()
                UserAvatarLoader(user: user).overlay(
                    Circle()                        .stroke(Color(UIColor.separator), lineWidth: 3.0)
                ).clipShape(Circle()).shadow(radius: 5.0)
                Spacer()
            }
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
                    HTMLView(html: user.about)
                }
            }
        }.navigationBarTitle(user.username)
    }
}

struct UserAvatarLoader: View {
    var user: NewestUser
    @ObservedObject private var loader: ImageLoader
    
    init(user: NewestUser) {
        self.user = user
        if let url = URL(string: "https://lobste.rs/"+user.avatar_url) {
            self.loader = ImageLoader(url: url)
        } else {
            self.loader = ImageLoader(url: URL(string: user.avatar_url)!)
        }
    }
    
    var body: some View {
        if let image = loader.image {
            Image(uiImage: image).resizable().frame(width: 100, height: 100, alignment: .center)
        } else {
            Image(systemName: "person.circle.fill").resizable().imageScale(.large).frame(width: 100, height: 100, alignment: .center).redacted(reason: .placeholder)
        }
    }
}

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private let url: URL

    init(url: URL) {
        self.url = url
        load()
    }
    
    private var cancellable: AnyCancellable?
        
    deinit {
        cancellable?.cancel()
    }

    func load() {
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .assign(to: \.image, on: self)
    }
    
    func cancel() {
        cancellable?.cancel()
    }
}

// todo: generate submitted stories
// /newest/twodayslate.json

struct UserView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            UserView(user: NewestUser(username: "twodayslate", created_at: "2020-01-05T18:25:23.000-06:00", is_admin: false, about: "", is_moderator: false, karma: 64, avatar_url: "/avatars/twodayslate-100.png", invited_by_user: "kimjon", github_username: "twodayslate", twitter_username: "twodayslate", keybase_signatures: nil))
        }.previewLayout(.sizeThatFits)
        
    }
}
