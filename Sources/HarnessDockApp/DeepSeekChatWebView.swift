import AppKit
import HarnessDockCore
import SwiftUI
import WebKit

struct DeepSeekChatWebView: NSViewRepresentable {
    let url: URL
    let reloadRequestID: Int
    let language: AppLanguage
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: DeepSeekChatEnterBehavior.userScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        context.coordinator.lastReloadRequestID = reloadRequestID
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        guard context.coordinator.lastReloadRequestID != reloadRequestID else { return }
        context.coordinator.lastReloadRequestID = reloadRequestID
        webView.reload()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: DeepSeekChatWebView
        var lastReloadRequestID = 0

        init(parent: DeepSeekChatWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.loadError = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.loadError = nil
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            updateFailure(error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            updateFailure(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            parent.isLoading = false
            parent.loadError = AppLocalization.localized(
                "网页进程已停止，请重新加载。",
                language: parent.language
            )
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.targetFrame?.isMainFrame != false,
                  let destination = navigationAction.request.url
            else {
                decisionHandler(.allow)
                return
            }

            if Self.isOfficialDeepSeekURL(destination) || destination.scheme == "about" {
                decisionHandler(.allow)
                return
            }

            NSWorkspace.shared.open(destination)
            decisionHandler(.cancel)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let destination = navigationAction.request.url else { return nil }
            if Self.isOfficialDeepSeekURL(destination) {
                webView.load(navigationAction.request)
            } else {
                NSWorkspace.shared.open(destination)
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping ([URL]?) -> Void
        ) {
            let panel = NSOpenPanel()
            panel.title = localized("选择要发送给 DeepSeek Chat 的文件")
            panel.message = localized("只有你确认选择的文件才会交给 DeepSeek 官方聊天页面。")
            panel.prompt = localized("选择")
            panel.canChooseFiles = true
            panel.canChooseDirectories = parameters.allowsDirectories
            panel.allowsMultipleSelection = parameters.allowsMultipleSelection

            panel.begin { response in
                completionHandler(response == .OK ? panel.urls : nil)
            }
        }

        private static func isOfficialDeepSeekURL(_ url: URL) -> Bool {
            guard url.scheme == "https", let host = url.host?.lowercased() else {
                return false
            }
            return host == "deepseek.com" || host.hasSuffix(".deepseek.com")
        }

        private func localized(_ key: String) -> String {
            AppLocalization.localized(key, language: parent.language)
        }

        private func updateFailure(_ error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain,
               nsError.code == NSURLErrorCancelled {
                return
            }
            parent.isLoading = false
            parent.loadError = error.localizedDescription
        }
    }
}
