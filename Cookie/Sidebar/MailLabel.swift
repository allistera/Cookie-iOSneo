/// A user label from `GET /labels`.
struct MailLabel: Decodable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let color: String?
}

struct LabelList: Decodable, Equatable, Sendable {
    let labels: [MailLabel]
}
