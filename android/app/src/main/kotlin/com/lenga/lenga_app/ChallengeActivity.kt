package com.lenga.lenga_app

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import org.json.JSONObject

/**
 * Full-screen challenge shown over a blocked app. Runs the Dart entrypoint
 * `challengeMain` in its own engine. It never lingers: leaving it in any way
 * (Back, Home, Recents) finishes it, so the blocked app is never revealed
 * without solving the problem.
 */
class ChallengeActivity : FlutterActivity() {
    override fun getDartEntrypointFunctionName() = "challengeMain"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BlockerPlugin.register(flutterEngine, this)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) setShowWhenLocked(true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        recreate() // new target app: restart with a fresh engine and problem
    }

    override fun onStop() {
        super.onStop()
        if (!isChangingConfigurations) finishAndRemoveTask()
    }

    companion object {
        const val EXTRA_PACKAGE = "package"
        const val EXTRA_CAL_TITLE = "calendarTitle"
        const val EXTRA_CAL_END = "calendarEnd"

        fun show(c: Context, pkg: String, window: JSONObject?) {
            val i = Intent(c, ChallengeActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtra(EXTRA_PACKAGE, pkg)
            if (window != null) {
                i.putExtra(EXTRA_CAL_TITLE, window.optString("title", "Calendar event"))
                i.putExtra(EXTRA_CAL_END, window.getLong("end"))
            }
            c.startActivity(i)
        }
    }
}
