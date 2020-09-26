import Foundation
import SwiftUI

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
