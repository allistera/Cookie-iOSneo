import SwiftUI

@main
struct CookieApp: App {
    @State private var session: Session
    private let client: APIClient

    init() {
        let session = Session(source: Auth0CredentialsSource())
        _session = State(initialValue: session)
        client = APIClient(tokens: TokenProvider(session: session))
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session, client: client)
        }
    }
}
