import Testing

@testable import Cookie

struct AvatarToneTests {
    @Test func isStableAndInRange() {
        #expect(AvatarTone.index(for: "Jordan Blake") == AvatarTone.index(for: "Jordan Blake"))
        for name in ["", "A", "Mum", "The Platform Weekly", "noreply@example.com"] {
            #expect((0..<AvatarTone.count).contains(AvatarTone.index(for: name)))
        }
    }

    @Test func differentNamesSpreadAcrossTones() {
        let names = ["Jordan Blake", "Priya Shah", "Mum", "Euan Mackay", "Katie Ross", "Dentist"]
        #expect(Set(names.map(AvatarTone.index)).count > 1)
    }
}
