package dcm.player

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var multiScreenPlugin: MultiScreenPlugin? = null
    private var secondaryDisplays: SecondaryDisplayController? = null
    private var webRtcProjectionPlugin: WebRtcProjectionPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        multiScreenPlugin = MultiScreenPlugin(this).also {
            it.register(flutterEngine.dartExecutor.binaryMessenger)
        }
        secondaryDisplays = SecondaryDisplayController(this).also {
            it.start()
        }
        webRtcProjectionPlugin = WebRtcProjectionPlugin().also {
            flutterEngine.plugins.add(it)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        webRtcProjectionPlugin = null
        secondaryDisplays?.stop()
        secondaryDisplays = null
        multiScreenPlugin?.unregister()
        multiScreenPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
