import Foundation
import SwiftUI

// A wrapper around AsyncImage for ``NewestUser``
struct UserAvatarLoader: View {
    var user: NewestUser
    var imageUrl: URL
    var size: CGFloat
    
    init(user: NewestUser, size: CGFloat = 100) {
        self.user = user
        self.size = size
        
        if let url = APIConfiguration.shared.userAvatarURL(avatarPath: user.avatar_url) {
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
        .frame(width: size, height: size, alignment: .center)
        .overlay(
            Circle().stroke(
                Color(UIColor.separator),
                lineWidth: max(1, size * 0.03)
            )
        )
        .clipShape(Circle())
        .shadow(radius: size * 0.05)
    }
}
