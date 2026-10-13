package app.resonance.resonance

import android.app.UiModeManager
import android.content.Intent
import android.content.res.Configuration
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var channel: MethodChannel? = null
    private var pendingAction: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingAction = quickAction(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "resonance/home_widget").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        ResonanceWidgetProvider.update(
                            this@MainActivity,
                            call.argument<String>("title") ?: "Resonance",
                            call.argument<String>("artist") ?: "",
                            call.argument<String>("artworkUrl"),
                            call.argument<Boolean>("playing") ?: false,
                        )
                        result.success(null)
                    }
                    "consumeLaunchAction" -> {
                        result.success(pendingAction)
                        pendingAction = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.resonance/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTelevision" -> result.success(isTelevision())
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val action = quickAction(intent) ?: return
        channel?.invokeMethod("action", action)
    }

    private fun quickAction(intent: Intent?): String? =
        if (intent?.action == ResonanceWidgetProvider.ACTION_QUICK) {
            intent.getStringExtra(ResonanceWidgetProvider.EXTRA_ACTION)
        } else {
            null
        }

    private fun isTelevision(): Boolean {
        val uiMode = getSystemService(UI_MODE_SERVICE) as? UiModeManager
        return uiMode?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature("android.software.leanback")
    }
}
