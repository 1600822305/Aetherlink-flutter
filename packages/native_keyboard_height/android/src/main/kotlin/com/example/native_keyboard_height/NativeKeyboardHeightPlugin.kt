package com.example.native_keyboard_height

import android.app.Activity
import android.view.View
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
 *   {type: "didShow",  height: <int dp>}
 *   {type: "willHide"}
 *   {type: "didHide"}
 */
class NativeKeyboardHeightPlugin : FlutterPlugin, ActivityAware, EventChannel.StreamHandler {
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var activity: Activity? = null

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

                override fun onProgress(
                    insets: WindowInsetsCompat,
                    runningAnimations: List<WindowInsetsAnimationCompat>,
                ): WindowInsetsCompat = insets

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

                    val showingKeyboard = currentInsets.isVisible(WindowInsetsCompat.Type.ime())
                    val imeHeightPx = currentInsets.getInsets(WindowInsetsCompat.Type.ime()).bottom
                    val density = act.resources.displayMetrics.density
                    val imeHeightDp = (imeHeightPx / density).roundToInt()

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
                    val showingKeyboard = currentInsets.isVisible(WindowInsetsCompat.Type.ime())
                    val imeHeightPx = currentInsets.getInsets(WindowInsetsCompat.Type.ime()).bottom
                    val density = act.resources.displayMetrics.density
                    val imeHeightDp = (imeHeightPx / density).roundToInt()

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
