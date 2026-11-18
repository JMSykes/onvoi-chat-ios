// OnvoiChat example / test harness (Onvoi spec 2026-11-17 embed-anywhere §8 device checklist).
//
// A minimal SwiftUI app around OnvoiChatView. Configure with launch arguments:
//   -origin http://localhost:3000 -surface <key> [-token <host SSO JWT>]
// Every chat → host event is shown on screen and printed as
//   ONVOI_EVENT <type> <json>
// so a script can follow the run. URL scheme: onvoiharness:// (the Face ID return).
//
// Built for the simulator by build-sim.sh; open in Xcode for a device.
import SwiftUI

@main
struct OnvoiHarnessApp: App {
    var body: some Scene {
        WindowGroup { HarnessView() }
    }
}

struct HarnessView: View {
    private let origin = URL(string: UserDefaults.standard.string(forKey: "origin") ?? "http://localhost:3000")!
    private let surface = UserDefaults.standard.string(forKey: "surface") ?? "home"
    private let launchToken = UserDefaults.standard.string(forKey: "token")
    @State private var token: String? = nil
    @State private var log: [String] = []

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button("Sign in (SSO)") { token = launchToken }.disabled(launchToken == nil)
                Spacer()
                Text("\(surface)").font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(size: 10, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 90)
            .accessibilityIdentifier("eventLog")
            OnvoiChat(origin: origin, surface: surface, returnURL: URL(string: "onvoiharness://onvoi-chat"), ssoToken: token) { event, payload in
                let json = (try? JSONSerialization.data(withJSONObject: payload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                print("ONVOI_EVENT \(event) \(json)")
                fflush(stdout)
                log.insert("\(event) \(json)", at: 0)
            }
        }
    }
}
