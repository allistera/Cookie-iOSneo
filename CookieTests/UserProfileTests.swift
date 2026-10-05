import Testing

@testable import Cookie

struct UserProfileTests {
    @Test func initialIsFirstLetterUppercased() {
        #expect(UserProfile(name: "allister", email: nil).initial == "A")
    }

    @Test func initialIsEmptyForEmptyName() {
        #expect(UserProfile(name: "", email: nil).initial.isEmpty)
    }
}
