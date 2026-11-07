package dcm.player

import android.app.Activity
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.Display
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * 多显示器枚举与热插拔监听（Android）。
 *
 * 通道：dcm/multiscreen
 *  - getDisplays        -> List<Map>，含稳定字段 output，按 output 升序
 *  - onDisplayEvent     <- 原生主动推送 {action, displayId, displays}
 */
class MultiScreenPlugin(private val activity: Activity) : DisplayManager.DisplayListener {

    companion object {
        const val CHANNEL = "dcm/multiscreen"
        private const val TAG = "MultiScreenPlugin"
    }

    private val displayManager =
        activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null

    fun register(messenger: BinaryMessenger) {
        if (channel != null) return

        val methodChannel = MethodChannel(messenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getDisplays" -> result.success(getDisplays())
                "getCurrentDisplayId" -> result.success(currentDisplayId())
                else -> result.notImplemented()
            }
        }

        channel = methodChannel
        displayManager.registerDisplayListener(this, mainHandler)
    }

    fun unregister() {
        displayManager.unregisterDisplayListener(this)
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun currentDisplayId(): Int =
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            activity.display?.displayId ?: Display.DEFAULT_DISPLAY
        } else {
            Display.DEFAULT_DISPLAY
        }

    private fun getDisplays(): List<Map<String, Any?>> {
        val ordered = displayManager.displays
            .sortedWith(
                compareBy<Display> { if (it.displayId == Display.DEFAULT_DISPLAY) 0 else 1 }
                    .thenBy { it.displayId }
            )
        // 输出序号使用持久化的稳定映射，拔插显示器后同一块屏仍对应原输出。
        val outputs = DisplayOutputRegistry.resolve(activity, ordered)
        return ordered
            .map { display -> toMap(display, outputs[display.displayId] ?: 0) }
            .sortedBy { (it["output"] as? Int) ?: 0 }
    }

    private fun toMap(display: Display, output: Int): Map<String, Any?> {
        val metrics = DisplayMetrics()
        display.getRealMetrics(metrics)
        return mapOf(
            "displayId" to display.displayId,
            "output" to output,
            "name" to (display.name ?: ""),
            "width" to metrics.widthPixels,
            "height" to metrics.heightPixels,
            "densityDpi" to metrics.densityDpi,
            "rotation" to display.rotation,
            "isPrimary" to (display.displayId == Display.DEFAULT_DISPLAY),
            "isPresentationSupported" to
                    ((display.flags and Display.FLAG_PRESENTATION) != 0)
        )
    }

    override fun onDisplayAdded(displayId: Int) {
        notifyChanged("added", displayId)
    }

    override fun onDisplayRemoved(displayId: Int) {
        notifyChanged("removed", displayId)
    }

    override fun onDisplayChanged(displayId: Int) {
        notifyChanged("changed", displayId)
    }

    private fun notifyChanged(action: String, displayId: Int) {
        mainHandler.post {
            val payload = mapOf(
                "action" to action,
                "displayId" to displayId,
                "displays" to getDisplays()
            )
            channel?.invokeMethod("onDisplayEvent", payload)
        }
    }
}
