#if DEBUG
    import Foundation

    /// Deterministic fixtures for previews. Never used in production code.
    enum InboxPreviewData {
        /// Monday 5 October 2026, 11:20 UTC.
        static let now = Date(timeIntervalSince1970: 1_791_199_200)

        static let emails: [EmailSummary] = [
            EmailSummary(
                id: "1", fromName: "Jordan Blake", fromAddress: "jordan@example.com",
                subject: "Final terms for your funding round",
                snippet: "We've outlined the final terms for the round and need your sign-off by Thursday "
                    + "so legal can prepare the documents.",
                sentAt: now.addingTimeInterval(-5520), isUnread: true, priority: "high",
                labels: [EmailLabel(name: "Funding", color: "#327056")],
                category: EmailCategory(id: "work", name: "Work & Career", color: nil)),
            EmailSummary(
                id: "2", fromName: "Priya Shah", fromAddress: "priya@example.com",
                subject: "Acme renewal: contract redlines",
                snippet: "Legal have returned the redlines. Two clauses on liability still need your input.",
                sentAt: now.addingTimeInterval(-86400), isUnread: true, priority: "high",
                labels: [EmailLabel(name: "Legal", color: nil)], category: nil),
            EmailSummary(
                id: "3", fromName: "Thistle Bank", fromAddress: "statements@example.com",
                subject: "Your September statement is ready",
                snippet: "Your monthly statement for September is now available to view and download.",
                sentAt: now.addingTimeInterval(-2 * 86400), isUnread: false, priority: "normal", labels: [],
                category: EmailCategory(id: "finance", name: "Finance", color: nil)),
            EmailSummary(
                id: "4", fromName: nil, fromAddress: "noreply@example.com", subject: nil, snippet: nil,
                sentAt: now.addingTimeInterval(-9 * 86400), isUnread: false, priority: nil, labels: [],
                category: nil),
        ]

        static let pageJSON = """
            {"emails":[
            {"id":"1","from_name":"Jordan Blake","from_address":"jordan@example.com",
            "subject":"Final terms for your funding round",
            "snippet":"We've outlined the final terms for the round and need your sign-off by Thursday.",
            "sent_at":"2026-10-05T09:48:00Z","is_unread":true,"priority":"high",
            "labels":[{"name":"Funding","color":"#327056"}],
            "category":{"id":"work","name":"Work & Career","color":null}},
            {"id":"2","from_name":"Priya Shah","from_address":"priya@example.com",
            "subject":"Acme renewal: contract redlines",
            "snippet":"Legal have returned the redlines. Two clauses on liability still need your input.",
            "sent_at":"2026-10-04T11:20:00Z","is_unread":true,"priority":"high",
            "labels":[{"name":"Legal","color":null}],"category":null},
            {"id":"3","from_name":"Thistle Bank","from_address":"statements@example.com",
            "subject":"Your September statement is ready",
            "snippet":"Your monthly statement for September is now available to view and download.",
            "sent_at":"2026-10-03T08:30:00Z","is_unread":false,"priority":"normal","labels":[],
            "category":{"id":"finance","name":"Finance","color":null}},
            {"id":"4","from_name":null,"from_address":"noreply@example.com","subject":null,"snippet":null,
            "sent_at":"2026-09-26T08:30:00Z","is_unread":false,"priority":null,"labels":[],"category":null}
            ],"nextCursor":"2026-09-26T08:30:00.000000Z|4","unreadCount":2}
            """

        static let categoriesJSON = """
            {"categories":[{"id":"finance","name":"Finance","color":"#B3792A"},
            {"id":"work","name":"Work & Career","color":"#138A5E"}]}
            """

        static let labelsJSON = """
            {"labels":[{"id":"l1","name":"Newsletters","color":"#B3792A"},
            {"id":"l2","name":"Personal","color":"#B1463A"},{"id":"l3","name":"Work","color":"#138A5E"}]}
            """

        static let draftsJSON = """
            {"drafts":[{"id":"d1","to":"jordan@example.com","subject":"Re: Final terms",
            "preview":"Thanks Jordan, I'll confirm by Thursday.","updatedAt":"2026-10-05T10:02:00Z"},
            {"id":"d2","to":null,"subject":null,"preview":"Notes for the offsite",
            "updatedAt":"2026-10-03T08:30:00Z"}]}
            """

        static func client(emailsStatus: Int) -> APIClient {
            let tokens = TokenProvider(current: { "preview" }, renewed: { "preview" }, invalidate: {})
            return APIClient(tokens: tokens) { request in
                guard let url = request.url else { throw URLError(.badURL) }
                let (status, body): (Int, String) =
                    switch url.path {
                    case "/categories": (200, categoriesJSON)
                    case "/labels": (200, labelsJSON)
                    case "/drafts": (200, draftsJSON)
                    default: (emailsStatus, pageJSON)
                    }
                guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
                else { throw URLError(.badURL) }
                return (Data(body.utf8), response)
            }
        }
    }
#endif
