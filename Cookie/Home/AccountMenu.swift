import SwiftUI

/// The circular account button from the design's header, opening a menu
/// with the signed-in address and Sign out.
struct AccountMenu: View {
    let profile: UserProfile
    let signOut: () async -> Void

    var body: some View {
        Menu {
            if let email = profile.email {
                Section(email) {
                    signOutButton
                }
            } else {
                signOutButton
            }
        } label: {
            Text(profile.initial)
                .font(CookieFont.text(.semibold, size: 17, relativeTo: .body))
                .foregroundStyle(Color(.surface))
                .frame(width: 44, height: 44)
                .background(Color(.primaryText), in: .circle)
                .overlay(Circle().strokeBorder(Color(.avatarRing), lineWidth: 2))
        }
        .accessibilityLabel("Account")
        .accessibilityIdentifier("accountMenu")
    }

    private var signOutButton: some View {
        Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
            Task { await signOut() }
        }
    }
}

#Preview {
    AccountMenu(profile: UserProfile(name: "Allister", email: "allister@example.com")) {}
        .padding()
}
