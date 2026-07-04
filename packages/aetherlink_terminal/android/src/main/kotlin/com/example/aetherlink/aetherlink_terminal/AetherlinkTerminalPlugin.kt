package com.example.aetherlink.aetherlink_terminal

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * Platform side of the built-in PRoot terminal (docs/内置终端PRoot-设计文档.md).
 *
 * MethodChannel `aetherlink_terminal`:
 *  · getNativeLibDir            → path where libproot.so was extracted
 *  · extractTarGz {archivePath, destPath}
 *  · ptyStart {cmd, args, env, cwd, rows, columns} → session id
 *  · ptyWrite {id, data}  · ptyResize {id, rows, columns}  · ptyKill {id}
 *
 * EventChannel `aetherlink_terminal/events` broadcasts
 * {id, data: bytes} output chunks and {id, exitCode} termination events for
 * every live PTY session.
 */
class AetherlinkTerminalPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var events: EventChannel
    private lateinit var context: Context

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newCachedThreadPool()
    private val sessions = ConcurrentHashMap<Int, PtySession>()
    private val nextSessionId = AtomicInteger(1)
    @Volatile private var eventSink: EventChannel.EventSink? = null

    private class PtySession(
        val pid: Int,
        val fileDescriptor: ParcelFileDescriptor,
        val output: FileInputStream,
        val input: FileOutputStream,
    )

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "aetherlink_terminal")
        channel.setMethodCallHandler(this)
        events = EventChannel(binding.binaryMessenger, "aetherlink_terminal/events")
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                eventSink = sink
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        events.setStreamHandler(null)
        for (id in sessions.keys) killSession(id)
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getNativeLibDir" -> result.success(context.applicationInfo.nativeLibraryDir)
            "extractTarGz" -> extractTarGz(call, result)
            "ptyStart" -> ptyStart(call, result)
            "ptyWrite" -> ptyWrite(call, result)
            "ptyResize" -> ptyResize(call, result)
            "ptyKill" -> {
                killSession(call.argument<Int>("id") ?: -1)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun extractTarGz(call: MethodCall, result: MethodChannel.Result) {
        val archivePath = call.argument<String>("archivePath")
        val destPath = call.argument<String>("destPath")
        if (archivePath == null || destPath == null) {
            result.error("bad_args", "archivePath / destPath 不能为空", null)
            return
        }
        executor.execute {
            try {
                TarGzExtractor.extract(archivePath, destPath)
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("extract_failed", e.message ?: e.toString(), null)
                }
            }
        }
    }

    private fun ptyStart(call: MethodCall, result: MethodChannel.Result) {
        val cmd = call.argument<String>("cmd")
        if (cmd == null) {
            result.error("bad_args", "cmd 不能为空", null)
            return
        }
        val args = call.argument<List<String>>("args") ?: emptyList()
        val env = call.argument<List<String>>("env") ?: emptyList()
        val cwd = call.argument<String>("cwd")
        val rows = call.argument<Int>("rows") ?: 24
        val columns = call.argument<Int>("columns") ?: 80

        val processId = IntArray(1)
        val masterFd: Int
        try {
            masterFd = AetherPty.createSubprocess(
                cmd, cwd, args.toTypedArray(), env.toTypedArray(),
                rows, columns, processId,
            )
        } catch (e: Exception) {
            result.error("pty_failed", e.message ?: e.toString(), null)
            return
        }

        val id = nextSessionId.getAndIncrement()
        val pfd = ParcelFileDescriptor.adoptFd(masterFd)
        val session = PtySession(
            pid = processId[0],
            fileDescriptor = pfd,
            output = FileInputStream(pfd.fileDescriptor),
            input = FileOutputStream(pfd.fileDescriptor),
        )
        sessions[id] = session
        // 保活：有存活会话期间起前台服务，防止 OEM 杀后台连带杀掉 ptrace 子链。
        TerminalForegroundService.start(context)

        // Reader: pump master-fd output to the event stream until EOF/close.
        executor.execute {
            val buffer = ByteArray(8 * 1024)
            try {
                while (true) {
                    val n = session.output.read(buffer)
                    if (n < 0) break
                    val chunk = buffer.copyOf(n)
                    mainHandler.post {
                        eventSink?.success(mapOf("id" to id, "data" to chunk))
                    }
                }
            } catch (_: Exception) {
                // fd closed (session killed) — the waiter reports the exit.
            }
        }
        // Waiter: report the exit code, then clean up.
        executor.execute {
            val exitCode = AetherPty.waitFor(session.pid)
            mainHandler.post {
                eventSink?.success(mapOf("id" to id, "exitCode" to exitCode))
            }
            closeSession(id)
        }

        result.success(id)
    }

    private fun ptyWrite(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Int>("id") ?: -1
        val data = call.argument<ByteArray>("data")
        val session = sessions[id]
        if (session == null || data == null) {
            result.success(null)
            return
        }
        executor.execute {
            try {
                session.input.write(data)
                session.input.flush()
            } catch (_: Exception) {
                // Session already gone.
            }
        }
        result.success(null)
    }

    private fun ptyResize(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Int>("id") ?: -1
        val session = sessions[id]
        if (session != null) {
            val rows = call.argument<Int>("rows") ?: 24
            val columns = call.argument<Int>("columns") ?: 80
            AetherPty.setPtyWindowSize(session.fileDescriptor.fd, rows, columns)
        }
        result.success(null)
    }

    private fun killSession(id: Int) {
        val session = sessions[id] ?: return
        try {
            AetherPty.kill(session.pid)
        } catch (_: Exception) {
        }
        // The waiter thread reaps the pid and calls closeSession.
    }

    private fun closeSession(id: Int) {
        val session = sessions.remove(id) ?: return
        try {
            session.fileDescriptor.close()
        } catch (_: Exception) {
        }
        if (sessions.isEmpty()) {
            mainHandler.post {
                if (sessions.isEmpty()) TerminalForegroundService.stop(context)
            }
        }
    }
}
