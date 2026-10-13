package one.jiri.easydict

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Passes text selected in other apps ("EasyDict" in the text selection menu,
 * Intent.ACTION_PROCESS_TEXT) to the Flutter side to look it up.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "one.jiri.easydict/text").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "initialText") result.success(selectedText(intent)) else result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        selectedText(intent)?.let { channel?.invokeMethod("text", it) }
    }

    private fun selectedText(intent: Intent?): String? =
        intent?.takeIf { it.action == Intent.ACTION_PROCESS_TEXT }
            ?.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)
            ?.toString()
}
