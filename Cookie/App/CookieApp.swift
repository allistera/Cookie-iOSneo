import SwiftUI

@main
struct CookieApp: App {
    @State private var session: Session
    private let client: APIClient

    init() {
        let session: Session
        #if DEBUG
            if UITestFixtures.isEnabled {
                session = UITestFixtures.session()
                client = UITestFixtures.client(session: session)
            } else {
                session = Session(source: Auth0CredentialsSource())
                client = APIClient(tokens: TokenProvider(session: session))
            }
        #else
            session = Session(source: Auth0CredentialsSource())
            client = APIClient(tokens: TokenProvider(session: session))
        #endif
        _session = State(initialValue: session)
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session, client: client)
        }
    }
}
