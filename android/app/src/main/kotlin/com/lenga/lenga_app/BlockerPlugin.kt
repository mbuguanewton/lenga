package com.lenga.lenga_app

import android.Manifest
import android.app.Activity
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import com.lenga.lenga_app.NativeStore.blockingEnabled
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.concurrent.Executors

/** Channel `com.lenga/blocker`; the Dart side is `AndroidPlatformBridge`. */
class BlockerPlugin(
    context: Context,
    /** Null in the headless background-sync engine, which has no UI. */
    private val activity: Activity?,
    private val onBackgroundSyncDone: (() -> Unit)? = null,
) : MethodChannel.MethodCallHandler {
    private val ctx: Context = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private val scope = CoroutineScope(Dispatchers.Main)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            handle(call, result)
        } catch (e: Exception) {
            result.error("native_error", e.message, null)
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installedApps" -> io.execute {
                val apps = installedApps()
                main.post { result.success(apps) }
            }
            "permissions" -> result.success(
                mapOf("usageAccess" to hasUsageAccess(), "overlay" to Settings.canDrawOverlays(ctx), "notifications" to hasNotifications())
            )
            "setCalendarSync" -> {
                if (call.arguments as Boolean) CalendarSyncWorker.schedule(ctx) else CalendarSyncWorker.cancel(ctx)
                result.success(null)
            }
            "finishBackgroundSync" -> {
                onBackgroundSyncDone?.invoke()
                result.success(null)
            }
            "openUsageAccessSettings" -> {
                openSettings(Settings.ACTION_USAGE_ACCESS_SETTINGS, withPackage = true)
                result.success(null)
            }
            "openOverlaySettings" -> {
                openSettings(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, withPackage = true)
                result.success(null)
            }
            "requestNotifications" -> {
                requestNotifications()
                result.success(null)
            }
            "openBatterySettings" -> {
                openSettings(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, withPackage = true)
                result.success(null)
            }
            "syncConfig" -> {
                val blocked = call.argument<List<String>>("blocked") ?: emptyList()
                NativeStore.setBlocked(ctx, blocked)
                NativeStore.setLockoutMinutes(ctx, call.argument<Int>("lockoutMinutes") ?: 15)
                result.success(null)
            }
            "setBlockingEnabled" -> {
                val on = call.arguments as Boolean
                ctx.blockingEnabled = on
                if (on) BlockerService.startIfNeeded(ctx) else BlockerService.stop(ctx)
                result.success(null)
            }
            "blockingPaused" -> {
                val wanted = ctx.blockingEnabled && NativeStore.blocked(ctx).isNotEmpty()
                val stale = System.currentTimeMillis() - NativeStore.lastHeartbeat(ctx) > 60_000
                result.success(wanted && stale)
            }
            "statsEvents" -> result.success(NativeStore.eventsJson(ctx))
            "blockStatus" -> {
                val packages = (call.arguments as List<*>).filterIsInstance<String>()
                val window = NativeStore.activeWindow(ctx, System.currentTimeMillis())
                result.success(
                    mapOf(
                        "lockedUntil" to NativeStore.lockedUntil(ctx),
                        "calendarTitle" to window?.optString("title"),
                        "calendarEnd" to window?.getLong("end"),
                        "unlocked" to packages.associateWith { NativeStore.unlockedUntil(ctx, it) },
                    )
                )
            }
            "syncCalendarWindows" -> {
                val old = CalendarBlockScheduler.currentIds(ctx)
                NativeStore.setWindows(ctx, call.arguments as String)
                CalendarBlockScheduler.schedule(ctx, old)
                result.success(null)
            }
            "challengeContext" -> result.success(challengeContext())
            "launchApp" -> {
                val activity = activity ?: return result.error("no_activity", "launchApp needs an Activity", null)
                val pkg = call.arguments as String
                ctx.packageManager.getLaunchIntentForPackage(pkg)?.let {
                    it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(it)
                }
                activity.finishAndRemoveTask()
                result.success(null)
            }
            "exitToHome" -> {
                val activity = activity ?: return result.error("no_activity", "exitToHome needs an Activity", null)
                activity.startActivity(
                    Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                activity.finishAndRemoveTask()
                result.success(null)
            }
            "getLockedUntil" -> result.success(NativeStore.lockedUntil(ctx))
            "setLockedUntil" -> {
                NativeStore.setLockedUntil(ctx, (call.arguments as Number).toLong())
                result.success(null)
            }
            "setUnlockedUntil" -> {
                NativeStore.setUnlockedUntil(ctx, call.argument<String>("package")!!, call.argument<Number>("until")!!.toLong())
                result.success(null)
            }
            "recordEvent" -> {
                NativeStore.recordEvent(ctx, call.arguments as String)
                result.success(null)
            }
            "popProblem" -> result.success(NativeStore.popProblem(ctx, call.arguments as String))
            "problemQueueSize" -> result.success(NativeStore.queueSize(ctx, call.arguments as String))
            "pushProblems" -> {
                NativeStore.pushProblems(ctx, call.argument<String>("difficulty")!!, call.argument<String>("problems")!!)
                result.success(null)
            }
            "aiAvailability" -> scope.launch { result.success(AiProblemService.availability()) }
            "aiGenerate" -> scope.launch {
                try {
                    result.success(AiProblemService.generate(call.arguments as String))
                } catch (e: Throwable) {
                    result.error("ai_error", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun installedApps(): List<Map<String, String>> {
        val pm = ctx.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .map { it.activityInfo.packageName to it }
            .filter { it.first != ctx.packageName }
            .distinctBy { it.first }
            .map { (pkg, ri) -> mapOf("package" to pkg, "name" to ri.loadLabel(pm).toString()) }
    }

    private fun hasUsageAccess(): Boolean {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= 29) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hasNotifications(): Boolean = NotificationManagerCompat.from(ctx).areNotificationsEnabled()

    private fun requestNotifications() {
        val activity = activity ?: return
        // The runtime prompt only shows once; after that, send the user to settings.
        if (Build.VERSION.SDK_INT >= 33 && !NativeStore.askedNotifications(ctx)) {
            NativeStore.setAskedNotifications(ctx)
            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
        } else {
            val i = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
            activity.startActivity(i)
        }
    }

    private fun openSettings(action: String, withPackage: Boolean) {
        val activity = activity ?: return
        val i = Intent(action)
        if (withPackage) i.data = Uri.parse("package:${ctx.packageName}")
        try {
            activity.startActivity(i)
        } catch (_: Exception) {
            activity.startActivity(Intent(action)) // some OEMs reject the package URI
        }
    }

    private fun challengeContext(): Map<String, Any?>? {
        val activity = activity as? ChallengeActivity ?: return null
        val pkg = activity.intent.getStringExtra(ChallengeActivity.EXTRA_PACKAGE) ?: return null
        val pm = ctx.packageManager
        val name = try {
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            pkg
        }
        val end = activity.intent.getLongExtra(ChallengeActivity.EXTRA_CAL_END, 0L)
        return mapOf(
            "package" to pkg,
            "name" to name,
            "calendarTitle" to activity.intent.getStringExtra(ChallengeActivity.EXTRA_CAL_TITLE),
            "calendarEnd" to if (end > 0) end else null,
        )
    }

    companion object {
        fun register(engine: FlutterEngine, activity: Activity) {
            MethodChannel(engine.dartExecutor.binaryMessenger, "com.lenga/blocker")
                .setMethodCallHandler(BlockerPlugin(activity, activity))
        }

        /** For the headless sync engine: no Activity, and a callback when Dart is done. */
        fun registerHeadless(engine: FlutterEngine, context: Context, onDone: () -> Unit) {
            MethodChannel(engine.dartExecutor.binaryMessenger, "com.lenga/blocker")
                .setMethodCallHandler(BlockerPlugin(context, null, onDone))
        }
    }
}
