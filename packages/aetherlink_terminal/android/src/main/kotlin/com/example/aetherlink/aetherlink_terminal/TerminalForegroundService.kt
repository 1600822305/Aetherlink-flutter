package com.example.aetherlink.aetherlink_terminal

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the app process (and its PRoot ptrace child chain) alive while PTY
 * sessions are running — aggressive OEM background killers reap the whole
 * chain otherwise (设计文档 §2.3). Started on the first PTY session, stopped
 * when the last one exits.
 *
 * Android 14+ compliance: declared with `foregroundServiceType="dataSync"` in
 * the plugin manifest plus FOREGROUND_SERVICE / FOREGROUND_SERVICE_DATA_SYNC
 * permissions. Without POST_NOTIFICATIONS the notification is silent but the
 * service still runs.
 */
class TerminalForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "aetherlink_terminal"
        private const val NOTIFICATION_ID = 0x7E01

        fun start(context: Context) {
            val intent = Intent(context, TerminalForegroundService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (_: Exception) {
                // App in background on Android 12+ — sessions still run, just
                // without keep-alive; the next foreground start retries.
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, TerminalForegroundService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "内置终端",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("内置终端运行中")
            .setContentText("终端会话正在后台保持运行")
            .setOngoing(true)
            .build()
    }
}
