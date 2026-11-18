// OnvoiChatView — an Onvoi custom chat in an iOS app (Onvoi spec 2026-11-17 embed-anywhere §6).
//
//   let chat = OnvoiChatView(origin: URL(string: "https://chat.acme.com")!,
//                            surface: "home",
//                            returnURL: URL(string: "acme://onvoi-chat"))
//   chat.delegate = self
//   chat.identify(token: jwtFromYourServer)
//
// The chat is the hosted page loaded as a top-level page in a WKWebView. This
// view draws nothing of its own. Face ID confirms run in
// ASWebAuthenticationSession because a WKWebView can only use passkeys for
// the app's own associated domains.
#if canImport(UIKit) && canImport(WebKit)
import UIKit
import WebKit
import AuthenticationServices

public protocol OnvoiChatViewDelegate: AnyObject {
    func onvoiChat(_ view: OnvoiChatView, didReceive event: String, payload: [String: Any])
}

/// Breaks the WKUserContentController → handler retain cycle.
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(c, didReceive: m)
    }
}

public final class OnvoiChatView: UIView, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate, ASWebAuthenticationPresentationContextProviding {
    public weak var delegate: OnvoiChatViewDelegate?
    public let origin: URL
    public let surface: String
    public let returnURL: URL?

    private let webView: WKWebView
    private var ready = false
    private var queue: [String] = []
    private var authSession: ASWebAuthenticationSession?

    public init(origin: URL, surface: String, returnURL: URL? = nil) {
        self.origin = (try? OnvoiChatProtocol.origin(origin)) ?? origin
        self.surface = surface
        self.returnURL = returnURL
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: config)
        super.init(frame: .zero)
        config.userContentController.add(WeakScriptHandler(self), name: "onvoiChat")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        if let url = try? OnvoiChatProtocol.chatURL(origin: self.origin, surface: surface, returnURL: returnURL) {
            webView.load(URLRequest(url: url))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit { webView.configuration.userContentController.removeScriptMessageHandler(forName: "onvoiChat") }

    // MARK: API

    /// Host sign-in: a short HS256 JWT your server signed with the chat's sign-in secret.
    public func identify(token: String) { send("identify", ["token": token]) }
    public func signOut() { send("signOut") }
    public func startConversation(text: String? = nil) { send("startConversation", text.map { ["text": $0] } ?? [:]) }
    public func setContext(locale: String? = nil) { send("setContext", locale.map { ["locale": $0] } ?? [:]) }
    public func reload() { webView.reload() }

    private func send(_ type: String, _ payload: [String: Any] = [:]) {
        guard let js = try? OnvoiChatProtocol.injection(type, payload) else { return }
        if ready { webView.evaluateJavaScript(js, completionHandler: nil) } else { queue.append(js) }
    }

    // MARK: page → app

    public func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              let host = message.frameInfo.securityOrigin.host as String?,
              host == origin.host,
              let msg = OnvoiChatProtocol.parse(message.body),
              let type = msg["type"] as? String else { return }
        var payload = msg
        payload.removeValue(forKey: "onvoi")
        payload.removeValue(forKey: "type")
        switch type {
        case "ready":
            ready = true
            queue.forEach { webView.evaluateJavaScript($0, completionHandler: nil) }
            queue.removeAll()
        case "openExternal":
            if let s = payload["url"] as? String, let u = URL(string: s), OnvoiChatProtocol.externalAllowed(u) { UIApplication.shared.open(u) }
        case "authRequired":
            if let s = payload["url"] as? String, let u = URL(string: s) { runPasskeySheet(u) }
        default: break
        }
        delegate?.onvoiChat(self, didReceive: type, payload: payload)
    }

    private func runPasskeySheet(_ url: URL) {
        guard let scheme = returnURL?.scheme else {
            send("authResult", ["ok": false])
            return
        }
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { [weak self] back, _ in
            DispatchQueue.main.async {
                self?.send("authResult", ["ok": OnvoiChatProtocol.handoffSucceeded(back)])
                self?.authSession = nil
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        authSession = session
        if !session.start() { send("authResult", ["ok": false]) }
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        window ?? ASPresentationAnchor()
    }

    // MARK: navigation

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { ready = false }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let js = try? OnvoiChatProtocol.injection("init", ["protocol": OnvoiChatProtocol.version, "platform": "ios", "wrapperVersion": OnvoiChatProtocol.wrapperVersion]) {
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.cancel) }
        if OnvoiChatProtocol.staysInChat(url, origin: origin) { return decisionHandler(.allow) }
        if OnvoiChatProtocol.externalAllowed(url) { UIApplication.shared.open(url) }
        decisionHandler(.cancel)
    }

    @available(iOS 15.0, *)
    public func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(origin.host == self.origin.host ? .prompt : .deny)
    }
}
#endif
