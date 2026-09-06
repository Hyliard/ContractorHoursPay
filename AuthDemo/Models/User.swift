import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let email: String
    let createdAt: String
}
