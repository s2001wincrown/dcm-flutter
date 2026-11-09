package dcm.player

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Android 屏幕推流的配套插件：只负责 mediaProjection 前台服务的启停。
 *
 * 实际的屏幕采集（MediaProjection 授权 + ScreenCapturerAndroid + VideoSource
 * + VideoTrack）由 flutter_webrtc 的 getDisplayMedia 完成，无需重复实现。
 *
 * 但 Android 14+ 强制要求：调用 MediaProjectionManager.getMediaProjection()
 * 之前必须已启动 foregroundServiceType="mediaProjection" 的前台服务，
 * 否则抛 SecurityException。flutter_webrtc 不托管该服务，故在此补充。
 */
class WebRtcProjectionPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "dcm/webrtc_projection"
    }

    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context?.let { WebRtcProjectionService.stop(it) }
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context
        if (ctx == null) {
            result.error("NO_CONTEXT", "Plugin not attached to engine", null)
            return
        }
        when (call.method) {
            "startService" -> {
                // 应用处于后台时 Android 12+ 会拒绝启动前台服务，此处降级返回 false。
                val started = try {
                    WebRtcProjectionService.start(ctx)
                    true
                } catch (t: Throwable) {
                    android.util.Log.e("DCM_WebRtc", "startForegroundService failed", t)
                    false
                }
                result.success(started)
            }

            "stopService" -> {
                WebRtcProjectionService.stop(ctx)
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }
}
