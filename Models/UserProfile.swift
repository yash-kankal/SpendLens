import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    var id: String = ""
    var displayName: String = ""
    var email: String = ""

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}
