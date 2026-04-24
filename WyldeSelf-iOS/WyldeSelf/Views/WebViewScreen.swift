import SwiftUI
import WebKit

struct WebViewScreen: View {
    let path: String

    var body: some View {
        WyldeWebView(path: path)
            .ignoresSafeArea(edges: .top)
            .padding(.bottom, 72) // Tab bar height
    }
}

// MARK: - WKWebView wrapper with JS ↔ Swift bridge

struct WyldeWebView: UIViewRepresentable {
    let path: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Enable inline media playback
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // JS → Swift message bridge
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "wyldeBridge")

        // Inject bridge script so web app can call native features
        let bridgeScript = WKUserScript(
            source: """
            window.WyldeNative = {
                isNative: true,
                haptic: function(type) {
                    window.webkit.messageHandlers.wyldeBridge.postMessage({action: 'haptic', type: type});
                },
                openCamera: function(purpose) {
                    window.webkit.messageHandlers.wyldeBridge.postMessage({action: 'camera', purpose: purpose});
                },
                syncHealth: function() {
                    window.webkit.messageHandlers.wyldeBridge.postMessage({action: 'syncHealth'});
                },
                scheduleNotification: function(title, body, seconds) {
                    window.webkit.messageHandlers.wyldeBridge.postMessage({action: 'notification', title: title, body: body, seconds: seconds});
                },
                awardXP: function(amount, reason) {
                    window.webkit.messageHandlers.wyldeBridge.postMessage({action: 'xp', amount: amount, reason: reason});
                },
                log: function(msg) {
                    window.webkit.messageHandlers.wyldeBridge.postMessage({action: 'log', message: msg});
                }
            };
            // Notify web app that native bridge is ready
            document.dispatchEvent(new CustomEvent('wyldeNativeReady'));
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        contentController.addUserScript(bridgeScript)

        // Hide the web app's bottom nav since we have native tabs
        let hideNavScript = WKUserScript(
            source: """
            var style = document.createElement('style');
            style.textContent = 'nav { display: none !important; } .screen { padding-bottom: 20px !important; }';
            document.head.appendChild(style);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        contentController.addUserScript(hideNavScript)

        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Theme.background)
        webView.scrollView.backgroundColor = UIColor(Theme.background)
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // Load the web app
        let urlString = "https://wyldeself.com/app.html\(path)"
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }

        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Navigate to the correct screen if the path changed
        let js = "if (typeof showScreen === 'function') { showScreen('\(path.replacingOccurrences(of: "#", with: ""))'); }"
        webView.evaluateJavaScript(js)
    }

    // MARK: - Coordinator handles JS → Swift messages

    class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }

            switch action {
            case "haptic":
                let type = body["type"] as? String ?? "light"
                switch type {
                case "success": HapticManager.shared.notification(.success)
                case "warning": HapticManager.shared.notification(.warning)
                case "error": HapticManager.shared.notification(.error)
                case "medium": HapticManager.shared.impact(.medium)
                case "heavy": HapticManager.shared.impact(.heavy)
                default: HapticManager.shared.impact(.light)
                }

            case "camera":
                let purpose = body["purpose"] as? String ?? "meal"
                NotificationCenter.default.post(
                    name: .openNativeCamera,
                    object: nil,
                    userInfo: ["purpose": purpose, "webView": webView as Any]
                )

            case "syncHealth":
                Task {
                    await HealthKitManager.shared.syncTodayData()
                }

            case "notification":
                if let title = body["title"] as? String,
                   let bodyText = body["body"] as? String,
                   let seconds = body["seconds"] as? Double {
                    NotificationManager.shared.scheduleLocal(
                        title: title,
                        body: bodyText,
                        after: seconds
                    )
                }

            case "xp":
                if let amount = body["amount"] as? Int,
                   let reason = body["reason"] as? String {
                    DispatchQueue.main.async {
                        // Post to AppState
                        NotificationCenter.default.post(
                            name: .awardXP,
                            object: nil,
                            userInfo: ["amount": amount, "reason": reason]
                        )
                    }
                }

            case "log":
                let msg = body["message"] as? String ?? ""
                print("[WyldeBridge] \(msg)")

            default:
                break
            }
        }
    }
}

extension Notification.Name {
    static let openNativeCamera = Notification.Name("openNativeCamera")
    static let awardXP = Notification.Name("awardXP")
}
