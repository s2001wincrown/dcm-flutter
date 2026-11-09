package dcm.player

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * MediaProjection 前台服务：Android 10+ 要求屏幕捕获必须由前台服务托管。
 * 服务创建时立即发一个持续运行的 notification，不做实际业务逻辑
 * （MediaProjection 生命周期在 Activity 的插件里管理）。
 */
class WebRtcProjectionService : Service() {

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "DCM 屏幕推流",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.description = "WebRTC 屏幕捕获正在进行"
            nm.createNotificationChannel(channel)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("DCM Player")
            .setContentText("正在通过 WebRTC 推流屏幕画面")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val NOTIFICATION_ID = 0x4450
        private const val CHANNEL_ID = "dcm_webrtc_projection"

        fun start(context: Context) {
            val intent = Intent(context, WebRtcProjectionService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, WebRtcProjectionService::class.java))
        }
    }
}
