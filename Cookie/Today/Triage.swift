import Foundation

/// One email the triage cites.
struct TriageItem: Decodable, Hashable, Identifiable, Sendable {
    let messageId: String
    let headline: String
    let note: String
    var unread: Bool

    var id: String { messageId }
}

/// A group such as "Reply Needed" or "Review".
struct TriageTopic: Decodable, Hashable, Identifiable, Sendable {
    let emoji: String
    let title: String
    var items: [TriageItem]

    var id: String { title }
}

struct NoiseCategory: Decodable, Hashable, Sendable {
    let category: String
    let count: Int
}

/// Mail the triage set aside, counted by category and never listed.
struct TriageNoise: Decodable, Hashable, Sendable {
    let count: Int
    let categories: [NoiseCategory]
}

/// The stored inbox triage from `GET /tasks`.
struct TriageDigest: Decodable, Hashable, Sendable {
    let overview: String
    let createdAt: Date
    var topics: [TriageTopic]
    let noise: TriageNoise
}

/// Only the triage is read; to-dos and the retired news round-up are ignored.
struct TodayResponse: Decodable, Sendable {
    let digest: TriageDigest?
}

/// `POST /tasks/refresh` takes no fields.
struct EmptyBody: Encodable, Sendable {}
