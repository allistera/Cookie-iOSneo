import Foundation
import SwiftUI
import Testing
import WebKit

@testable import Cookie

@MainActor
private final class NavigationFinishDelegate: NSObject, WKNavigationDelegate {
    private let coordinator: EmailBodyView.Coordinator?
    private var result: Result<Void, Error>?
    private var continuation: CheckedContinuation<Result<Void, Error>, Never>?

    init(coordinator: EmailBodyView.Coordinator? = nil) {
        self.coordinator = coordinator
    }

    func waitForCompletion() async -> Result<Void, Error> {
        await withTaskCancellationHandler(
            operation: {
                await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, Error>, Never>) in
                    if let result {
                        continuation.resume(returning: result)
                    } else {
                        self.continuation = continuation
                    }
                }
            },
            onCancel: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.finish(.failure(CancellationError()))
                }
            })
    }

    private func finish(_ result: Result<Void, Error>) {
        guard self.result == nil else { return }
        self.result = result
        continuation?.resume(returning: result)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        coordinator?.webView(webView, didFinish: navigation)
        finish(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
        coordinator?.webView(webView, didFail: navigation, withError: error)
        finish(.failure(error))
    }

    func webView(
        _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error
    ) {
        coordinator?.webView(webView, didFailProvisionalNavigation: navigation, withError: error)
        finish(.failure(error))
    }
}

@MainActor
struct EmailBodyViewTests {
    @Test func readerConfigurationDisablesJavaScriptAndPersistsNoWebData() {
        let configuration = EmailBodyView.makeConfiguration()

        #expect(configuration.defaultWebpagePreferences.allowsContentJavaScript == false)
        #expect(configuration.websiteDataStore.isPersistent == false)
        #expect(configuration.allowsInlineMediaPlayback == false)
    }

    @Test(.timeLimit(.minutes(1))) func readerUsesScaledFontInputForAccessibility() async {
        // JavaScript is enabled only on this test instance so the test can inspect
        // WebKit's computed style. The production reader configuration remains disabled.
        let configuration = EmailBodyView.makeConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        let coordinator = EmailBodyView.Coordinator(contentHeight: .constant(0))
        let delegate = NavigationFinishDelegate(coordinator: coordinator)
        defer { coordinator.teardown(webView) }
        webView.navigationDelegate = delegate
        coordinator.load(
            html: #"<p style="font-size: 8px">Hello</p>"#, blocksRemoteContent: false, baseFontSize: 34, into: webView)

        let completion = await delegate.waitForCompletion()
        guard case .success = completion else {
            if case .failure(let error) = completion {
                Issue.record("reader document failed to load: \(error)")
            }
            return
        }

        let result: Any?
        do {
            result = try await webView.evaluateJavaScript(
                "getComputedStyle(document.querySelector('p')).fontSize")
        } catch {
            Issue.record("could not inspect rendered reader font: \(error)")
            return
        }
        let cssValue = result as? String ?? ""
        let renderedFontSize = Double(cssValue.replacingOccurrences(of: "px", with: ""))
        guard let renderedFontSize else {
            Issue.record("unexpected computed font size: \(cssValue)")
            return
        }
        #expect(renderedFontSize >= 33.5)
    }

    @Test(.timeLimit(.minutes(1))) func senderScriptDoesNotExecuteInReaderWebView() async {
        let webView = WKWebView(frame: .zero, configuration: EmailBodyView.makeConfiguration())
        let delegate = NavigationFinishDelegate()
        defer {
            webView.stopLoading()
            webView.navigationDelegate = nil
        }
        webView.navigationDelegate = delegate
        webView.loadHTMLString(
            #"<html><head><title>safe</title>"#
                + #"<script>document.title = "executed"</script></head><body>Message</body></html>"#,
            baseURL: nil)

        let completion = await delegate.waitForCompletion()

        #expect(
            {
                if case .success = completion { return true }
                return false
            }())
        #expect(webView.title == "safe")
    }
}
