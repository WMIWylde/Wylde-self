import SwiftUI

// ════════════════════════════════════════════════════════════════════
//  ErrorBanner — lightweight global error notification system.
//
//  Services post errors via ErrorBanner.shared.show(...)
//  Views display them using the .errorBanner() modifier.
//
//  Errors auto-dismiss after a timeout unless they have a retry action.
// ════════════════════════════════════════════════════════════════════

@MainActor
final class ErrorBanner: ObservableObject {
    static let shared = ErrorBanner()
    private init() {}

    struct BannerItem: Identifiable {
        let id = UUID()
        let message: String
        let type: BannerType
        let retry: (() -> Void)?
    }

    enum BannerType {
        case networkError
        case authError
        case generationFailed
        case syncFailed

        var icon: String {
            switch self {
            case .networkError: return "wifi.slash"
            case .authError: return "lock.slash"
            case .generationFailed: return "exclamationmark.triangle"
            case .syncFailed: return "arrow.triangle.2.circlepath"
            }
        }
    }

    @Published var current: BannerItem?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, type: BannerType = .syncFailed, retry: (() -> Void)? = nil) {
        dismissTask?.cancel()
        current = BannerItem(message: message, type: type, retry: retry)

        // Auto-dismiss after 5 seconds if no retry action
        if retry == nil {
            dismissTask = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !Task.isCancelled { self.dismiss() }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

// MARK: - View modifier

struct ErrorBannerModifier: ViewModifier {
    @ObservedObject var banner = ErrorBanner.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let item = banner.current {
                HStack(spacing: 10) {
                    Image(systemName: item.type.icon)
                        .font(.system(size: 14, weight: .medium))
                    Text(item.message)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if let retry = item.retry {
                        Button("Retry") {
                            banner.dismiss()
                            retry()
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.25)))
                    }
                    Button {
                        banner.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 0.35, green: 0.30, blue: 0.27))
                        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: banner.current?.id)
            }
        }
    }
}

extension View {
    func errorBanner() -> some View {
        modifier(ErrorBannerModifier())
    }
}
