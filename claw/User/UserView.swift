import SwiftUI

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
            if let karma = user.karma {
                HStack {
                    Text("Karma").bold()
                    Text("\(karma)")
                }
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
                    VStack(alignment: .leading) {
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

struct UserView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            UserView(user: NewestUser(username: "twodayslate", created_at: "2020-01-05T18:25:23.000-06:00", is_admin: false, about: "", is_moderator: false, karma: 64, avatar_url: "/avatars/twodayslate-100.png", invited_by_user: "kimjon", github_username: "twodayslate", twitter_username: "twodayslate", keybase_signatures: nil))
        }.previewLayout(.sizeThatFits)
        
    }
}
