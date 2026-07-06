package com.example.native_keyboard_height

import android.app.Activity
import android.os.Build
import android.view.View
import kotlin.math.max
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import kotlin.math.roundToInt

/**
 * Flutter plugin that provides native keyboard height events matching
 * Capacitor's `keyboardWillShow` / `keyboardWillHide` behavior.
 *
 * Uses [WindowInsetsAnimationCompat.Callback.onStart] to obtain the **final**
 * keyboard height **before** the OS animation starts — so Flutter can snap the
 * layout in a single frame with zero delay.
 *
 * Ported 1:1 from `capacitor-edge-to-edge` Android implementation
 * (`EdgeToEdge.setupKeyboardListener`).
 *
 * Events sent via [EventChannel]:
 *   {type: "willShow", height: <int dp>}
 *   {type: "progress", height: <int dp>}   // per animation frame, frame-synced
 *   {type: "didShow",  height: <int dp>}
 *   {type: "willHide"}
 *   {type: "didHide"}
 */
class NativeKeyboardHeightPlugin : FlutterPlugin, ActivityAware, EventChannel.StreamHandler {
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var activity: Activity? = null

    /** Last sane keyboard height (px), used as the fallback for implausible readings. */
    private var lastGoodHeightPx = 0

    /**
     * Keyboard height in dp above the navigation bar — the QQ/WeChat convention:
     * `ime insets − navigation bar insets`, so the value composes with the
     * safe-area padding instead of double-counting the nav bar. Also guards
     * against implausible readings (> 80% of screen height) with the last good
     * value (or a 280dp default), mirroring QQ's AdjustCommonStrategy.
     */
    private fun keyboardHeightDp(act: Activity, insets: WindowInsetsCompat): Int {
        val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
        val nav = insets.getInsets(WindowInsetsCompat.Type.navigationBars())
        var heightPx = max(0, ime.bottom - nav.bottom)

        val metrics = act.resources.displayMetrics
        val density = metrics.density
        if (heightPx > metrics.heightPixels * 0.8) {
            heightPx = if (lastGoodHeightPx > 0) lastGoodHeightPx else (280 * density).toInt()
        } else if (heightPx > 0) {
            lastGoodHeightPx = heightPx
        }
        return (heightPx / density).roundToInt()
    }

    /** Multi-window / split-screen layouts confuse inset math — skip, like WeChat/QQ. */
    private fun inMultiWindow(act: Activity): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && act.isInMultiWindowMode

    // ── FlutterPlugin ────────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        eventChannel = EventChannel(
            binding.binaryMessenger,
            "com.example.native_keyboard_height/events",
        )
        eventChannel?.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        eventChannel?.setStreamHandler(null)
        eventChannel = null
    }

    // ── ActivityAware ────────────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        setupKeyboardListener()
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        setupKeyboardListener()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    // ── EventChannel.StreamHandler ───────────────────────────────────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // ── Keyboard listener (1:1 port of EdgeToEdge.setupKeyboardListener) ─────

    private fun setupKeyboardListener() {
        val act = activity ?: return
        val content = act.window.decorView.findViewById<View>(android.R.id.content)
        val rootView = content.rootView

        ViewCompat.setWindowInsetsAnimationCallback(
            rootView,
            object : WindowInsetsAnimationCompat.Callback(DISPATCH_MODE_STOP) {

                /**
                 * Fires every animation frame with the interpolated insets —
                 * the same signal native apps (WeChat/QQ) use to pan their
                 * content in exact sync with the IME's top edge.
                 */
                override fun onProgress(
                    insets: WindowInsetsCompat,
                    runningAnimations: List<WindowInsetsAnimationCompat>,
                ): WindowInsetsCompat {
                    val imeAnimating = runningAnimations.any {
                        it.typeMask and WindowInsetsCompat.Type.ime() != 0
                    }
                    if (imeAnimating && !inMultiWindow(act)) {
                        val imeHeightDp = keyboardHeightDp(act, insets)
                        eventSink?.success(mapOf("type" to "progress", "height" to imeHeightDp))
                    }
                    return insets
                }

                /**
                 * Fires **before** the keyboard animation starts.
                 * [ViewCompat.getRootWindowInsets] returns the **target** (end)
                 * state, so `ime().bottom` is the final keyboard height.
                 *
                 * Original: EdgeToEdge.java lines 272-293
                 */
                override fun onStart(
                    animation: WindowInsetsAnimationCompat,
                    bounds: WindowInsetsAnimationCompat.BoundsCompat,
                ): WindowInsetsAnimationCompat.BoundsCompat {
                    val currentInsets = ViewCompat.getRootWindowInsets(rootView)
                        ?: return super.onStart(animation, bounds)
                    if (inMultiWindow(act)) return super.onStart(animation, bounds)

                    val showingKeyboard = currentInsets.isVisible(WindowInsetsCompat.Type.ime())
                    val imeHeightDp = keyboardHeightDp(act, currentInsets)

                    if (showingKeyboard) {
                        eventSink?.success(mapOf("type" to "willShow", "height" to imeHeightDp))
                    } else {
                        eventSink?.success(mapOf("type" to "willHide"))
                    }
                    return super.onStart(animation, bounds)
                }

                /**
                 * Fires **after** the keyboard animation completes.
                 *
                 * Original: EdgeToEdge.java lines 296-314
                 */
                override fun onEnd(animation: WindowInsetsAnimationCompat) {
                    super.onEnd(animation)
                    val currentInsets = ViewCompat.getRootWindowInsets(rootView) ?: return
                    if (inMultiWindow(act)) return
                    val showingKeyboard = currentInsets.isVisible(WindowInsetsCompat.Type.ime())
                    val imeHeightDp = keyboardHeightDp(act, currentInsets)

                    if (showingKeyboard) {
                        eventSink?.success(mapOf("type" to "didShow", "height" to imeHeightDp))
                    } else {
                        eventSink?.success(mapOf("type" to "didHide"))
                    }
                }
            },
        )
    }
}
