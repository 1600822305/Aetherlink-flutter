package com.aetherlink.dexeditor

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.aetherlink.dexeditor.compat.JSObject
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.Executors
import org.json.JSONArray
import org.json.JSONObject

/**
 * Flutter bridge for the DEX/APK editing core.
 *
 * Architecture: this class is a thin transport layer. All operation logic lives
 * in [DexActionDispatcher] (transport-agnostic) over [DexManager]/[ApkManager];
 * the Capacitor-specific `Plugin` base class and `JSObject` marshalling were
 * dropped in favour of a `MethodChannel` + `EventChannel` pair.
 *
 * Channels:
 *  - method channel `com.aetherlink.dexeditor/methods`: `execute(action, params)`
 *    plus the editor launchers (`openSmaliEditor` / `openXmlEditor` /
 *    `openCodeEditor`).
 *  - event channel `com.aetherlink.dexeditor/events`: `compileProgress` stream.
 *
 * Long-running work runs on a background executor so the platform main thread is
 * never blocked; results are posted back on the main thread.
 */
class DexEditorFlutterPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private companion object {
        const val METHOD_CHANNEL = "com.aetherlink.dexeditor/methods"
        const val EVENT_CHANNEL = "com.aetherlink.dexeditor/events"
        const val EDITOR_REQUEST_CODE = 0xDE01
    }

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var appContext: Context
    private lateinit var dispatcher: DexActionDispatcher

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newCachedThreadPool()
    private var eventSink: EventChannel.EventSink? = null

    private var activityBinding: ActivityPluginBinding? = null
    private val activity: Activity? get() = activityBinding?.activity
    private var pendingEditorResult: MethodChannel.Result? = null

    // ===== FlutterPlugin lifecycle =====

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        dispatcher = DexActionDispatcher(appContext)
        dispatcher.setProgressCallback(object : DexManager.CompileProgress {
            override fun onProgress(current: Int, total: Int) {
                emitEvent(
                    mapOf(
                        "type" to "progress",
                        "current" to current,
                        "total" to total,
                        "percent" to if (total > 0) current * 100 / total else 0,
                    )
                )
            }

            override fun onMessage(message: String?) {
                emitEvent(mapOf("type" to "message", "message" to message))
            }

            override fun onTitle(title: String?) {
                emitEvent(mapOf("type" to "title", "title" to title))
            }
        })

        channel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
    }

    // ===== ActivityAware lifecycle =====

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    // ===== Method dispatch =====

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "execute" -> handleExecute(call, result)
            "openSmaliEditor" -> launchEditor(call, result, "smali.json", "Smali Editor")
            "openXmlEditor" -> launchEditor(call, result, "xml.json", "XML Editor")
            "openCodeEditor" -> launchEditor(
                call,
                result,
                call.argument<String>("syntaxFile") ?: "json.json",
                "Code Editor",
            )
            else -> result.notImplemented()
        }
    }

    private fun handleExecute(call: MethodCall, result: MethodChannel.Result) {
        val action = call.argument<String>("action")
        if (action.isNullOrEmpty()) {
            result.error("E_ARG", "Action is required", null)
            return
        }
        val paramsArg = call.argument<Map<String, Any?>>("params")
        val params = JSObject(paramsArg ?: emptyMap<String, Any?>())
        executor.execute {
            try {
                val out = dispatcher.dispatch(action, params)
                val dart = jsonToDart(out)
                mainHandler.post { result.success(dart) }
            } catch (t: Throwable) {
                mainHandler.post {
                    result.success(
                        mapOf(
                            "success" to false,
                            "error" to (t.message ?: t::class.java.simpleName),
                        )
                    )
                }
            }
        }
    }

    private fun launchEditor(
        call: MethodCall,
        result: MethodChannel.Result,
        defaultSyntax: String,
        defaultTitle: String,
    ) {
        val current = activity
        if (current == null) {
            result.error("E_NO_ACTIVITY", "No foreground activity for editor", null)
            return
        }
        if (pendingEditorResult != null) {
            result.error("E_BUSY", "An editor is already open", null)
            return
        }
        val intent = Intent(current, SmaliEditorActivity::class.java).apply {
            putExtra(SmaliEditorActivity.EXTRA_CONTENT, call.argument<String>("content") ?: "")
            putExtra(SmaliEditorActivity.EXTRA_TITLE, call.argument<String>("title") ?: defaultTitle)
            putExtra(
                SmaliEditorActivity.EXTRA_CLASS_NAME,
                call.argument<String>("className") ?: call.argument<String>("filePath") ?: "",
            )
            putExtra(SmaliEditorActivity.EXTRA_READ_ONLY, call.argument<Boolean>("readOnly") ?: false)
            putExtra(
                SmaliEditorActivity.EXTRA_SYNTAX_FILE,
                call.argument<String>("syntaxFile") ?: defaultSyntax,
            )
        }
        pendingEditorResult = result
        current.startActivityForResult(intent, EDITOR_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != EDITOR_REQUEST_CODE) return false
        val result = pendingEditorResult ?: return true
        pendingEditorResult = null
        if (resultCode == Activity.RESULT_OK && data != null) {
            result.success(
                mapOf(
                    "success" to true,
                    "content" to data.getStringExtra(SmaliEditorActivity.RESULT_CONTENT),
                    "modified" to data.getBooleanExtra(SmaliEditorActivity.RESULT_MODIFIED, false),
                )
            )
        } else {
            result.success(mapOf("success" to false, "cancelled" to true))
        }
        return true
    }

    // ===== helpers =====

    private fun emitEvent(payload: Map<String, Any?>) {
        mainHandler.post { eventSink?.success(payload) }
    }

    /** Recursively converts org.json trees (incl. the compat shims) into
     * StandardMessageCodec-friendly Map/List/primitive values. */
    private fun jsonToDart(value: Any?): Any? = when (value) {
        null, JSONObject.NULL -> null
        is JSONObject -> {
            val map = HashMap<String, Any?>(value.length())
            val keys = value.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                map[key] = jsonToDart(value.opt(key))
            }
            map
        }
        is JSONArray -> {
            val list = ArrayList<Any?>(value.length())
            for (i in 0 until value.length()) {
                list.add(jsonToDart(value.opt(i)))
            }
            list
        }
        else -> value
    }
}
