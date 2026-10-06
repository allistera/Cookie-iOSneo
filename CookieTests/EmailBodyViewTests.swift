import Testing

@testable import Cookie

struct EmailBodyViewTests {
    @Test func detectsRemoteContent() {
        let samples = [
            #"<img src="https://t.example/p.gif">"#, #"<img SRC='http://x/y.png'>"#,
            #"<div style="background: url(https://x/y.png)">"#, #"<td background="https://x/y.png">"#,
            #"<link rel="stylesheet" href="https://x/a.css">"#, #"<style>@import "https://x/a.css";</style>"#,
            #"<video src="https://x/a.mp4">"#,
        ]
        for html in samples {
            #expect(EmailBodyView.hasBlockedRemoteContent(html), "\(html)")
        }
    }

    @Test func ignoresLinksAndInlineData() {
        let samples = [
            "", "<p>Hello</p>", #"<a href="https://x">link</a>"#,
            #"<img src="data:image/png;base64,AAAA">"#, #"<img src="cid:part1">"#,
        ]
        for html in samples {
            #expect(!EmailBodyView.hasBlockedRemoteContent(html), "\(html)")
        }
    }
}
