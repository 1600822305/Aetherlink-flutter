import Flutter
import UIKit

/// Flutter plugin that provides native keyboard height events matching
/// Capacitor's `keyboardWillShow` / `keyboardWillHide` behavior.
///
/// Uses `UIResponder.keyboardWillShowNotification` with
/// `keyboardFrameEndUserInfoKey` to obtain the **final** keyboard height
/// **before** the OS animation starts.
///
/// Ported from `capacitor-edge-to-edge` iOS implementation
/// (`EdgeToEdge.keyboardWillShow` / `EdgeToEdge.keyboardWillHide`).
public class NativeKeyboardHeightPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

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

    // MARK: - Keyboard notifications (port of Capacitor EdgeToEdge)

    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    /// Fires **before** the keyboard animation starts.
    /// `keyboardFrameEndUserInfoKey` contains the **final** keyboard frame.
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let height = frame.size.height
        eventSink?(["type": "show", "height": height])
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        eventSink?(["type": "hide"])
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
