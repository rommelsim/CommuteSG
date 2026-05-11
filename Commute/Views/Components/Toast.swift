import SwiftUI
import Observation

/// One toast on the queue. Toasts auto-dismiss; multiple in quick succession
/// replace each other (we don't stack — keeps the UI calm).
struct Toast: Identifiable, Equatable {
    enum Style: Equatable {
        case success
        case info
        case warning
        case error
    }
    let id = UUID()
    let message: String
    let style: Style
    let symbol: String?
    let duration: TimeInterval

    static func success(_ message: String, symbol: String? = nil) -> Toast {
        Toast(message: message, style: .success, symbol: symbol ?? "checkmark.circle.fill", duration: 2.0)
    }
    static func info(_ message: String, symbol: String? = nil) -> Toast {
        Toast(message: message, style: .info, symbol: symbol ?? "info.circle.fill", duration: 2.4)
    }
    static func warning(_ message: String, symbol: String? = nil) -> Toast {
        Toast(message: message, style: .warning, symbol: symbol ?? "exclamationmark.triangle.fill", duration: 3.0)
    }
    static func error(_ message: String, symbol: String? = nil) -> Toast {
        Toast(message: message, style: .error, symbol: symbol ?? "xmark.octagon.fill", duration: 3.5)
    }
}

/// Singleton toast bus. Any view can call `ToastCenter.shared.show(.success("…"))`
/// from any actor — the property assignment hops to MainActor before mutating
/// observable state, so SwiftUI sees a clean update.
@Observable
@MainActor
final class ToastCenter {
    static let shared = ToastCenter()
    private init() {}

    /// The toast currently shown. Setting nil dismisses it. The view layer
    /// observes this and animates in/out.
    var current: Toast?

    private var dismissTask: Task<Void, Never>?

    func show(_ toast: Toast) {
        dismissTask?.cancel()
        // Light haptic + replace the current toast.
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        current = toast
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

// MARK: - View overlay

/// Drop this at the root via `.toastOverlay()`. It floats a single toast pill
/// in from the top, auto-dismissing after the toast's duration.
struct ToastOverlay: View {
    @State private var center = ToastCenter.shared

    var body: some View {
        VStack {
            if let toast = center.current {
                ToastPill(toast: toast) {
                    center.dismiss()
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.smooth(duration: 0.35), value: center.current)
        .allowsHitTesting(center.current != nil)
    }
}

private struct ToastPill: View {
    let toast: Toast
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if let symbol = toast.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                }
                Text(toast.message)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.appText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.appBorder, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }

    private var accent: Color {
        switch toast.style {
        case .success: Color.appSuccess
        case .info:    Color.appInfo
        case .warning: Color.appWarning
        case .error:   Color.appDanger
        }
    }
}

// MARK: - View modifier convenience

extension View {
    /// Attach the toast overlay to a root view (e.g. `RootView`).
    func toastOverlay() -> some View {
        overlay(alignment: .top) { ToastOverlay() }
    }
}
