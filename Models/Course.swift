import Foundation

struct Course: Identifiable, Decodable, Hashable {
    let id: String
    let code: String
    let title: String?
    let term: String?
    let start_date: String?
    let end_date: String?
    let grace_days: Int?
}
