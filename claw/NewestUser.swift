import Foundation

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
    var karma: Int? // pushcx doesn't have any karma
    var avatar_url: String
    var invited_by_user: String? // jcs wasn't invited by anyone
    var github_username: String?
    var twitter_username: String?
    var keybase_signatures: [KeybaseSignatures]?
}
