import SwiftUI

/// The signed-out screen. The design has no sign-in screen, so this follows
/// its palette and wordmark with one native prominent button.
struct SignInView: View {
    let session: Session

    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(.logo)
                .resizable()
                .frame(width: 88, height: 88)
                .clipShape(.rect(cornerRadius: 22))
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Text("Cookie")
                    .font(CookieFont.text(.bold, size: 32, relativeTo: .largeTitle))
                    .foregroundStyle(Color(.primaryText))
                Text("Email")
                    .font(CookieFont.text(.regular, size: 32, relativeTo: .largeTitle))
                    .foregroundStyle(Color(.secondaryText))
            }
            .accessibilityElement(children: .combine)
            Spacer()
            if let error = session.signInError {
                Text(error)
                    .font(CookieFont.text(.regular, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button {
                isSigningIn = true
            } label: {
                Text("Sign in")
                    .font(CookieFont.text(.semibold, size: 17, relativeTo: .body))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isSigningIn)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.surface))
        .task(id: isSigningIn) {
            guard isSigningIn else { return }
            await session.signIn()
            isSigningIn = false
        }
    }
}

#if DEBUG
    @MainActor
    private final class PreviewCredentialsSource: CredentialsSource {
        let failure: CredentialsFailure
        init(failure: CredentialsFailure) { self.failure = failure }

        var hasStoredCredentials: Bool { false }
        func storedProfile() -> UserProfile? { nil }
        func signIn() async throws { throw failure }
        func accessToken() async throws -> String { throw CredentialsFailure.signInRequired }
        func renewedAccessToken() async throws -> String { throw CredentialsFailure.signInRequired }
        func clear() {}
        func endWebSession() async {}
    }

    #Preview("Signed out") {
        SignInView(session: Session(source: PreviewCredentialsSource(failure: .cancelled)))
    }

    #Preview("Sign-in error") {
        // Tap Sign in to show the error state.
        SignInView(session: Session(source: PreviewCredentialsSource(failure: .transient)))
    }
#endif
