import SwiftUI
import UIKit
import WebKit

class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()

    @Published var showCamera = false
    @Published var capturedImage: UIImage?
    @Published var purpose: String = "meal"

    weak var webView: WKWebView?

    private override init() {
        super.init()
        // Listen for camera requests from WebView bridge
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCameraRequest),
            name: .openNativeCamera,
            object: nil
        )
    }

    @objc private func handleCameraRequest(_ notification: Notification) {
        guard let info = notification.userInfo else { return }
        purpose = info["purpose"] as? String ?? "meal"
        webView = info["webView"] as? WKWebView

        DispatchQueue.main.async {
            self.showCamera = true
        }
    }

    func sendImageToWeb(image: UIImage) {
        guard let webView = webView,
              let imageData = image.jpegData(compressionQuality: 0.7) else { return }

        let base64 = imageData.base64EncodedString()
        let js = "window.handleNativePhoto && window.handleNativePhoto('\(purpose)', 'data:image/jpeg;base64,\(base64)');"

        DispatchQueue.main.async {
            webView.evaluateJavaScript(js)
        }
    }
}

// MARK: - Camera View Controller Representable

struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
