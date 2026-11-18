// SwiftUI wrapper for OnvoiChatView.
#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import SwiftUI

public struct OnvoiChat: UIViewRepresentable {
    public let origin: URL
    public let surface: String
    public var returnURL: URL?
    public var ssoToken: String?
    public var onEvent: ((String, [String: Any]) -> Void)?

    public init(origin: URL, surface: String, returnURL: URL? = nil, ssoToken: String? = nil, onEvent: ((String, [String: Any]) -> Void)? = nil) {
        self.origin = origin
        self.surface = surface
        self.returnURL = returnURL
        self.ssoToken = ssoToken
        self.onEvent = onEvent
    }

    public final class Coordinator: OnvoiChatViewDelegate {
        var onEvent: ((String, [String: Any]) -> Void)?
        var lastToken: String?
        public func onvoiChat(_ view: OnvoiChatView, didReceive event: String, payload: [String: Any]) { onEvent?(event, payload) }
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public func makeUIView(context: Context) -> OnvoiChatView {
        let v = OnvoiChatView(origin: origin, surface: surface, returnURL: returnURL)
        v.delegate = context.coordinator
        return v
    }

    public func updateUIView(_ view: OnvoiChatView, context: Context) {
        context.coordinator.onEvent = onEvent
        if let t = ssoToken, t != context.coordinator.lastToken {
            context.coordinator.lastToken = t
            view.identify(token: t)
        }
    }
}
#endif
