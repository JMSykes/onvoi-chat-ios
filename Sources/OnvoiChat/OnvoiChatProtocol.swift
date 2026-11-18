// Host protocol v1, the app side (Onvoi spec 2026-11-17 embed-anywhere §4, §6).
// Pure logic, no UIKit — OnvoiChatView uses it and the tests exercise it.
import Foundation

public enum OnvoiChatProtocol {
    public static let version = 1
    public static let wrapperVersion = "1.0.0"
    // Copies of @onvoi/shared constants/custom-chat-protocol.js — Onvoi's verify:custom-chat-embed checks them.
    public static let chatToHost: Set<String> = ["ready", "brand", "close", "signedIn", "signedOut", "unread", "actionCompleted", "openExternal", "authRequired", "resize"]
    public static let hostToChat: Set<String> = ["init", "identify", "signOut", "startConversation", "setContext", "authResult"]

    public enum Failure: Error { case badOrigin, missingSurface, unknownMessage(String) }

    /// The chat's origin (scheme://host[:port]); only http(s).
    public static func origin(_ raw: URL) throws -> URL {
        guard let scheme = raw.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = raw.host else { throw Failure.badOrigin }
        var c = URLComponents()
        c.scheme = scheme
        c.host = host
        c.port = raw.port
        guard let u = c.url else { throw Failure.badOrigin }
        return u
    }

    /// The hosted page for this platform. `returnURL` is the app's scheme, used by the Face ID sheet.
    public static func chatURL(origin raw: URL, surface: String, platform: String = "ios", returnURL: URL?) throws -> URL {
        guard !surface.isEmpty else { throw Failure.missingSurface }
        let o = try origin(raw)
        var c = URLComponents(url: o, resolvingAgainstBaseURL: false)!
        let encoded = surface.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? surface
        c.percentEncodedPath = "/c/\(encoded)"
        var q = [URLQueryItem(name: "embed", value: "1"), URLQueryItem(name: "platform", value: platform)]
        if let r = returnURL { q.append(URLQueryItem(name: "return", value: r.absoluteString)) }
        c.queryItems = q
        return c.url!
    }

    /// A message from the page, or nil.
    public static func parse(_ body: Any) -> [String: Any]? {
        var dict: [String: Any]?
        if let d = body as? [String: Any] { dict = d }
        else if let s = body as? String, let data = s.data(using: .utf8) { dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] }
        guard let d = dict, (d["onvoi"] as? Int) == version, let type = d["type"] as? String, chatToHost.contains(type) else { return nil }
        return d
    }

    /// JavaScript that delivers one host message into the page.
    public static func injection(_ type: String, _ payload: [String: Any] = [:]) throws -> String {
        guard hostToChat.contains(type) else { throw Failure.unknownMessage(type) }
        var msg = payload
        msg["onvoi"] = version
        msg["type"] = type
        let data = try JSONSerialization.data(withJSONObject: msg, options: [])
        var lit = String(data: data, encoding: .utf8)!
        lit = lit.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
            .replacingOccurrences(of: "</", with: "<\\/")
        return "(function(){if(window.__onvoiChatReceive){window.__onvoiChatReceive(\(lit));}})();true;"
    }

    /// Only the chat's own pages load inside the view.
    public static func staysInChat(_ url: URL, origin raw: URL) -> Bool {
        if ["about", "blob", "data"].contains(url.scheme?.lowercased() ?? "") { return true }
        guard let o = try? origin(raw), let uo = try? origin(url) else { return false }
        return o == uo && url.path.hasPrefix("/c/")
    }

    public static func externalAllowed(_ url: URL) -> Bool {
        ["https", "http", "mailto", "tel"].contains(url.scheme?.lowercased() ?? "")
    }

    public static func handoffSucceeded(_ url: URL?) -> Bool {
        guard let u = url, let items = URLComponents(url: u, resolvingAgainstBaseURL: false)?.queryItems else { return false }
        return items.first(where: { $0.name == "onvoi_handoff" })?.value == "done"
    }
}
