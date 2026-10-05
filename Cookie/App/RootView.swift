import SwiftUI

/// Shows the sign-in screen or the signed-in app, following `Session`.
struct RootView: View {
    let session: Session
    let client: APIClient

    var body: some View {
        switch session.state {
        case .signedOut:
            SignInView(session: session)
        case .signedIn(let profile):
            HomeView(profile: profile, client: client, signOut: session.signOut)
        }
    }
}
