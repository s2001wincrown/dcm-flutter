package dcm.player

import android.app.Activity
import android.app.Presentation
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.android.ExclusiveAppComponent
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * 为 Android 扩展显示器创建独立 Flutter 引擎，并通过 [Presentation] 渲染。
 *
 * 输出序号与 [MultiScreenPlugin] 返回的显示器顺序保持一致：主屏为 0，其余按
 * displayId 升序依次为 1、2……。每块扩展屏运行一个独立引擎，因此各屏拥有
 * 自己的播放状态和坐标空间。
 */
class SecondaryDisplayController(private val activity: Activity) :
    DisplayManager.DisplayListener {

    companion object {
        private const val TAG = "SecondaryDisplay"
        private const val ENTRYPOINT = "multiScreenMain"
    }

    private val displayManager =
        activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val handler = Handler(Looper.getMainLooper())
    private val sessions = LinkedHashMap<Int, Session>()
    private var started = false

    fun start() {
        if (started) return
        started = true
        displayManager.registerDisplayListener(this, handler)
        // 等主引擎完成首帧后再创建扩展屏引擎，避免拖慢启动。
        handler.post { sync() }
    }

    fun stop() {
        if (!started) return
        started = false
        displayManager.unregisterDisplayListener(this)
        // dismiss() 会触发 OnDismissListener 回调并可能修改 sessions，先复制一份。
        sessions.values.toList().forEach { destroy(it) }
        sessions.clear()
    }

    override fun onDisplayAdded(displayId: Int) {
        sync()
    }

    override fun onDisplayRemoved(displayId: Int) {
        sync()
    }

    override fun onDisplayChanged(displayId: Int) {
        sync()
    }

    /** 与 MultiScreenPlugin.getDisplays 保持一致的排序：主屏优先，其次按 id 升序。 */
    private fun orderedDisplays(): List<Display> =
        displayManager.displays.sortedWith(
            compareBy<Display> { if (it.displayId == Display.DEFAULT_DISPLAY) 0 else 1 }
                .thenBy { it.displayId }
        )

    private fun sync() {
        if (!started) return
        if (activity.isFinishing || activity.isDestroyed) return

        val ordered = orderedDisplays()
        // 输出序号与 MultiScreenPlugin 共用同一份稳定映射，拔插后不会串屏。
        val outputs = DisplayOutputRegistry.resolve(activity, ordered)
        val desired = LinkedHashMap<Int, Int>() // displayId -> output
        ordered.forEach { display ->
            if ((display.flags and Display.FLAG_PRESENTATION) != 0 &&
                display.displayId != Display.DEFAULT_DISPLAY
            ) {
                desired[display.displayId] = outputs[display.displayId] ?: return@forEach
            }
        }

        val stale = sessions.filterValues { session ->
            desired[session.displayId] != session.output
        }
        stale.forEach { (displayId, session) ->
            sessions.remove(displayId)
            destroy(session)
        }

        desired.forEach { (displayId, output) ->
            if (sessions.containsKey(displayId)) return@forEach
            val display = displayManager.getDisplay(displayId) ?: return@forEach
            try {
                sessions[displayId] = create(display, output)
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to create engine for display $displayId", t)
            }
        }
    }

    private fun create(display: Display, output: Int): Session {
        val engine = FlutterEngine(activity)
        val entrypoint = DartExecutor.DartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault().pathToBundle,
            ENTRYPOINT
        )

        GeneratedPluginRegistrant.registerWith(engine)
        // 次要引擎同样需要显示器枚举通道，用于按输出序号计算画布尺寸。
        val screenPlugin = MultiScreenPlugin(activity)
        screenPlugin.register(engine.dartExecutor.binaryMessenger)
        engine.activityControlSurface.attachToActivity(
            ActivityComponent(activity),
            (activity as LifecycleOwner).lifecycle
        )

        val view = FlutterView(activity)
        view.attachToFlutterEngine(engine)

        val presentation = Presentation(
            activity,
            display,
            android.R.style.Theme_DeviceDefault_NoActionBar_Fullscreen
        )
        presentation.window?.setBackgroundDrawable(ColorDrawable(Color.BLACK))
        presentation.setContentView(view)
        presentation.setOnDismissListener {
            val session = sessions.remove(display.displayId)
            if (session != null) {
                destroy(session)
            }
        }
        presentation.show()

        engine.dartExecutor.executeDartEntrypoint(entrypoint, listOf(output.toString()))
        engine.lifecycleChannel.appIsResumed()

        Log.i(TAG, "Secondary display ${display.displayId} started for output $output")
        return Session(
            output,
            display.displayId,
            engine,
            view,
            presentation,
            screenPlugin
        )
    }

    private fun destroy(session: Session) {
        if (session.destroyed) return
        session.destroyed = true
        try {
            session.presentation.dismiss()
        } catch (t: Throwable) {
            Log.w(TAG, "dismiss presentation failed", t)
        }
        try {
            session.view.detachFromFlutterEngine()
        } catch (t: Throwable) {
            Log.w(TAG, "detach flutter view failed", t)
        }
        try {
            session.screenPlugin.unregister()
        } catch (t: Throwable) {
            Log.w(TAG, "unregister multi screen channel failed", t)
        }
        try {
            session.engine.activityControlSurface.detachFromActivity()
        } catch (t: Throwable) {
            Log.w(TAG, "detach engine from activity failed", t)
        }
        try {
            session.engine.destroy()
        } catch (t: Throwable) {
            Log.w(TAG, "destroy engine failed", t)
        }
    }

    private class Session(
        val output: Int,
        val displayId: Int,
        val engine: FlutterEngine,
        val view: FlutterView,
        val presentation: Presentation,
        val screenPlugin: MultiScreenPlugin
    ) {
        var destroyed = false
    }

    private class ActivityComponent(
        private val activity: Activity
    ) : ExclusiveAppComponent<Activity> {
        override fun getAppComponent(): Activity = activity
        override fun detachFromFlutterEngine() {}
    }
}
