#if DEBUG
    import Foundation

    /// Local, synthetic data for UI regression tests. Release builds cannot select this path.
    @MainActor
    enum UITestFixtures {
        static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-ui-testing") }

        static func session() -> Session {
            Session(source: source(), logoutIntentStore: FixtureLogoutIntentStore())
        }

        private static func source() -> any CredentialsSource {
            FixtureCredentialsSource(signedIn: ProcessInfo.processInfo.arguments.contains("-ui-testing-signed-in"))
        }

        static func client(session: Session) -> APIClient {
            let transport = FixtureTransport(
                emptyToday: ProcessInfo.processInfo.arguments.contains("-ui-testing-empty-today"))
            return APIClient(tokens: TokenProvider(session: session)) { request in
                try await transport.respond(to: request)
            }
        }

        private final class FixtureLogoutIntentStore: LogoutIntentStore {
            var hasPendingLogout = false
        }

        private final class FixtureCredentialsSource: CredentialsSource {
            var hasStoredCredentials: Bool
            private let profile = UserProfile(name: "UI Test", email: "reader@example.com")

            init(signedIn: Bool) { hasStoredCredentials = signedIn }
            func storedProfile() -> UserProfile? { hasStoredCredentials ? profile : nil }
            func signIn() async throws { hasStoredCredentials = true }
            func accessToken() async throws -> String { "fixture" }
            func renewedAccessToken() async throws -> String { "fixture" }
            func clear() { hasStoredCredentials = false }
            func endWebSession() async {}
        }

        private actor FixtureTransport {
            let emptyToday: Bool
            private var isRead = false

            init(emptyToday: Bool) { self.emptyToday = emptyToday }

            func respond(to request: URLRequest) throws -> (Data, URLResponse) {
                guard let url = request.url else { throw URLError(.badURL) }
                let status = url.path == "/tasks/refresh" ? 429 : 200
                let body: String
                switch url.path {
                case "/categories", "/labels", "/drafts": body = Self.listBody(for: url.path)
                case "/emails":
                    let folder = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                        .first(where: { $0.name == "folder" })?.value
                    body = folder == "sent" ? Self.sentPage : inboxPage
                case "/messages" where request.httpMethod == "PATCH":
                    isRead = true
                    body = "{}"
                case "/messages":
                    let id =
                        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                        .first(where: { $0.name == "id" })?.value ?? "fixture-message"
                    body = Self.message.replacingOccurrences(of: "fixture-message", with: id)
                case "/tasks": body = emptyToday ? #"{"digest":null}"# : Self.digest
                case "/send", "/tasks/refresh": body = "{}"
                default: throw URLError(.unsupportedURL)
                }
                guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
                else { throw URLError(.badServerResponse) }
                return (Data(body.utf8), response)
            }

            private static func listBody(for path: String) -> String {
                switch path {
                case "/categories": #"{"categories":[]}"#
                case "/labels": #"{"labels":[]}"#
                default: #"{"drafts":[]}"#
                }
            }

            private var inboxPage: String {
                """
                {"emails":[{"id":"fixture-message","from_name":"Jordan","from_address":"jordan@example.com",
                "subject":"UI fixture message","snippet":"A synthetic message for regression coverage.",
                "sent_at":"2026-10-06T09:00:00Z","is_unread":\(!isRead),"priority":"high","labels":[]}],
                "nextCursor":null,"unreadCount":\(isRead ? 0 : 1)}
                """
            }

            private static let sentPage = """
                {"emails":[{"id":"fixture-sent","from_name":"UI Test","from_address":"reader@example.com",
                "subject":"Sent fixture message","snippet":"A synthetic outgoing message.",
                "sent_at":"2026-10-06T09:00:00Z","is_unread":false,"is_sent":true,"labels":[],
                "recipients":{"to":[{"name":"Jordan","address":"jordan@example.com"}]}}],
                "nextCursor":null,"unreadCount":0}
                """

            private static let message = """
                {"id":"fixture-message","subject":"UI fixture message",
                "body_html":"<p>Fixture body visible.</p><img srcset='https://example.invalid/image.png 1x'>",
                "body_text":"Fixture body visible.","thread":[{"id":"fixture-message","from_name":"Jordan",
                "from_address":"jordan@example.com","snippet":"Fixture body visible.",
                "sent_at":"2026-10-06T09:00:00Z"}]}
                """

            private static let digest = """
                {"digest":{"overview":"Fixture triage overview.","created_at":"2026-10-06T09:00:00Z",
                "topics":[{"emoji":"","title":"Needs a reply","items":[{"message_id":"fixture-message",
                "headline":"Read the fixture email","note":"Synthetic UI coverage.","unread":true}]}],
                "noise":{"count":0,"categories":[]}}}
                """
        }
    }
#endif
