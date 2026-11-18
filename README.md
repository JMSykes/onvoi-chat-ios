# OnvoiChat for iOS

Put your Onvoi custom chat in an iOS app. Swift Package, iOS 15+.

**Xcode → File → Add Package Dependencies…** and add this package, or in `Package.swift`:

```swift
.package(url: "https://github.com/JMSykes/onvoi-chat-ios", from: "1.0.0")
```

## UIKit

```swift
import OnvoiChat

let chat = OnvoiChatView(
    origin: URL(string: "https://chat.acme.com")!,
    surface: "home",
    returnURL: URL(string: "acme://onvoi-chat")   // your app's scheme, for Face ID confirms
)
chat.delegate = self
chat.identify(token: jwtFromYourServer)           // optional: sign in with your login

func onvoiChat(_ view: OnvoiChatView, didReceive event: String, payload: [String: Any]) {
    if event == "close" { dismiss(animated: true) }
    if event == "actionCompleted" { refreshOrders() }
}
```

## SwiftUI

```swift
OnvoiChat(origin: URL(string: "https://chat.acme.com")!, surface: "home",
          returnURL: URL(string: "acme://onvoi-chat"), ssoToken: token) { event, payload in
    if event == "close" { dismiss() }
}
```

Methods: `identify(token:)`, `signOut()`, `startConversation(text:)`, `setContext(locale:)`, `reload()`.

Events: `ready`, `brand`, `close`, `signedIn`, `signedOut`, `unread`, `actionCompleted`. None of them carry the customer's email or id.

## Face ID confirms

Apple only lets a WKWebView use passkeys for the app's own associated domains, so the chat hands that step to `ASWebAuthenticationSession` and comes back. Register a URL scheme for your app and pass it as `returnURL`. The return link only ever carries `onvoi_handoff=done` or `failed`.

## Info.plist

`NSMicrophoneUsageDescription` if you want voice in the chat.

## Links

Links in the chat open in Safari. The view only ever shows the chat's own pages.

## App Store and Play review

The chat is one screen inside your native app, so the guidance on apps that are mostly web content doesn't apply to it. Links leave through the system browser, and nothing is downloaded or run outside the chat's own pages.
