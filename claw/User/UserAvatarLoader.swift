import Foundation
import SwiftUI

// A wrapper around AsyncImage for ``NewestUser``
struct UserAvatarLoader: View {
    var user: NewestUser
    var imageUrl: URL
    
    init(user: NewestUser) {
        self.user = user
        if let url = URL(string: "https://lobste.rs/"+user.avatar_url) {
            self.imageUrl = url
        } else {
            self.imageUrl = URL(string: user.avatar_url)!
        }
    }
    
    var body: some View {
        AsyncImage(url: imageUrl) { image in
            image.resizable()
        } placeholder: {
            Image(systemName: "person.circle.fill")
                .resizable()
                .imageScale(.large)
                .redacted(reason: .placeholder)
        }
        .frame(width: 100, height: 100, alignment: .center)
        .overlay(
            Circle().stroke(Color(UIColor.separator), lineWidth: 3.0)
        )
        .clipShape(Circle())
        .shadow(radius: 5.0)
    }
}
