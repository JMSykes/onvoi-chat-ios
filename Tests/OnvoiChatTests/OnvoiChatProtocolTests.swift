import XCTest
@testable import OnvoiChat

final class OnvoiChatProtocolTests: XCTestCase {
    func testChatURL() throws {
        let u = try OnvoiChatProtocol.chatURL(origin: URL(string: "https://chat.acme.com/x")!, surface: "home", returnURL: URL(string: "acme://onvoi-chat"))
        let c = URLComponents(url: u, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(c.host, "chat.acme.com")
        XCTAssertEqual(c.path, "/c/home")
        XCTAssertEqual(c.queryItems?.first(where: { $0.name == "platform" })?.value, "ios")
        XCTAssertEqual(c.queryItems?.first(where: { $0.name == "return" })?.value, "acme://onvoi-chat")
        XCTAssertThrowsError(try OnvoiChatProtocol.chatURL(origin: URL(string: "file:///etc")!, surface: "home", returnURL: nil))
    }

    func testParse() {
        XCTAssertNotNil(OnvoiChatProtocol.parse(["onvoi": 1, "type": "ready"]))
        XCTAssertNil(OnvoiChatProtocol.parse(["onvoi": 1, "type": "identify"]))
        XCTAssertNil(OnvoiChatProtocol.parse("nope"))
        XCTAssertNotNil(OnvoiChatProtocol.parse("{\"onvoi\":1,\"type\":\"close\"}"))
    }

    func testInjectionEscapes() throws {
        let js = try OnvoiChatProtocol.injection("identify", ["token": "</script>\u{2028}"])
        XCTAssertFalse(js.contains("</script>"))
        XCTAssertFalse(js.contains("\u{2028}"))
        XCTAssertThrowsError(try OnvoiChatProtocol.injection("ready"))
    }

    func testNavigationAndHandoff() {
        let o = URL(string: "https://chat.acme.com")!
        XCTAssertTrue(OnvoiChatProtocol.staysInChat(URL(string: "https://chat.acme.com/c/home/passkey")!, origin: o))
        XCTAssertFalse(OnvoiChatProtocol.staysInChat(URL(string: "https://evil.example/c/home")!, origin: o))
        XCTAssertFalse(OnvoiChatProtocol.externalAllowed(URL(string: "javascript:alert(1)")!))
        XCTAssertTrue(OnvoiChatProtocol.handoffSucceeded(URL(string: "acme://x?onvoi_handoff=done")))
        XCTAssertFalse(OnvoiChatProtocol.handoffSucceeded(URL(string: "acme://x?onvoi_handoff=failed")))
    }
}
