import Flutter
import UIKit

/// Flutter plugin that provides native keyboard height events matching
/// Capacitor's `keyboardWillShow` / `keyboardWillHide` behavior.
///
/// Ported 1:1 from `capacitor-edge-to-edge` iOS implementation
/// (`EdgeToEdge.swift` keyboard notification handlers).
///
/// Events sent via `FlutterEventChannel`:
///   {"type": "willShow", "height": <CGFloat pt>}
///   {"type": "didShow",  "height": <CGFloat pt>}
///   {"type": "willHide"}
///   {"type": "didHide"}
public class NativeKeyboardHeightPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    /// Remembered keyboard height — mirrors original's `keyboardHeight` ivar.
    private var keyboardHeight: CGFloat = 0

    /// Whether the keyboard is currently visible.
    private var isKeyboardVisible = false

    /// iPad Stage Manager offset cache (original: `stageManagerOffset`).
    private var stageManagerOffset: CGFloat = 0

    /// State version counter — incremented on every show/hide to cancel stale
    /// delayed callbacks (original: `keyboardStateVersion`).
    private var stateVersion: Int = 0

    /// Debounce timer for hide events (original: `hideTimer`).
    private var hideTimer: Timer?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterEventChannel(
            name: "com.example.native_keyboard_height/events",
            binaryMessenger: registrar.messenger()
        )
        let instance = NativeKeyboardHeightPlugin()
        channel.setStreamHandler(instance)
        instance.setupKeyboardNotifications()
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // MARK: - Keyboard notifications (1:1 port of EdgeToEdge.swift)

    private func setupKeyboardNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillShow),
                       name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillHide),
                       name: UIResponder.keyboardWillHideNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardDidShow),
                       name: UIResponder.keyboardDidShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardDidHide),
                       name: UIResponder.keyboardDidHideNotification, object: nil)
    }

    /// Original: EdgeToEdge.swift `keyboardWillShow(notification:)`
    @objc private func keyboardWillShow(notification: NSNotification) {
        // Cancel any pending hide timer (original line 375-376)
        hideTimer?.invalidate()
        hideTimer = nil

        // Bump state version to cancel stale callbacks (original line 379-380)
        stateVersion += 1

        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        var height = keyboardFrame.size.height

        // iPad Stage Manager correction (original lines 388-404)
        if UIDevice.current.userInterfaceIdiom == .pad {
            if stageManagerOffset > 0 {
                height = stageManagerOffset
            } else {
                // Find the key window's root view controller
                let keyWindow: UIWindow?
                if #available(iOS 13.0, *) {
                    keyWindow = UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .flatMap { $0.windows }
                        .first { $0.isKeyWindow }
                } else {
                    keyWindow = UIApplication.shared.keyWindow
                }

                if let window = keyWindow,
                   let rootView = window.rootViewController?.view {
                    let screen = window.screen
                    let viewAbsolute = rootView.convert(rootView.frame, to: screen.coordinateSpace)
                    let corrected = (viewAbsolute.size.height + viewAbsolute.origin.y) -
                                    (screen.bounds.size.height - keyboardFrame.size.height)
                    height = max(corrected, 0)
                    stageManagerOffset = height
                }
            }
        }

        keyboardHeight = height
        isKeyboardVisible = true

        eventSink?(["type": "willShow", "height": height])
    }

    /// Original: EdgeToEdge.swift `keyboardDidShow(notification:)`
    @objc private func keyboardDidShow(notification: NSNotification) {
        if isKeyboardVisible {
            eventSink?(["type": "didShow", "height": keyboardHeight])
        }
    }

    /// Original: EdgeToEdge.swift `keyboardWillHide(notification:)`
    @objc private func keyboardWillHide(notification: NSNotification) {
        stateVersion += 1

        keyboardHeight = 0
        isKeyboardVisible = false

        eventSink?(["type": "willHide"])
    }

    /// Original: EdgeToEdge.swift `keyboardDidHide(notification:)`
    @objc private func keyboardDidHide(notification: NSNotification) {
        let capturedVersion = stateVersion

        // Reset Stage Manager offset (original line 469)
        stageManagerOffset = 0

        if !isKeyboardVisible {
            eventSink?(["type": "didHide"])
        }

        // Delayed cleanup, guarded by state version (original lines 485-489)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self, self.stateVersion == capturedVersion else { return }
            // No-op in Flutter (original resets WebView scroll here)
        }
    }

    deinit {
        hideTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
