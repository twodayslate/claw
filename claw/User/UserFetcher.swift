import SwiftUI
import Combine

@MainActor
class UserFetcher: ObservableObject {
    var username: String
    
    init(_ username: String) {
        self.username = username
    }
    
    deinit {
        self.session?.cancel()
    }
    
    private var session: URLSessionTask? = nil
    
    func load() async throws -> NewestUser {
        let url = URL(string: "https://lobste.rs/~" + self.username + ".json")!

        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(NewestUser.self, from: data)
    }
}
