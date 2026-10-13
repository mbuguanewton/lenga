package com.lenga.lenga_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.lenga.lenga_app.NativeStore.blockingEnabled

/**
 * Foreground service that polls UsageStatsManager for the app in the
 * foreground and puts [ChallengeActivity] over any blocked app that has no
 * active unlock window. Polling (not accessibility) keeps the Play footprint small.
 */
class BlockerService : Service() {
    private lateinit var thread: HandlerThread
    private lateinit var handler: Handler
    private lateinit var usage: UsageStatsManager

    private var lastQuery = 0L
    private var foreground: String? = null
    private var lastLaunch = 0L
    private var lastHeartbeat = 0L

    private val tick = object : Runnable {
        override fun run() {
            try {
                poll()
            } catch (_: Exception) {
                // Never let one bad poll kill the loop.
            }
            handler.postDelayed(this, POLL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        usage = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        thread = HandlerThread("lenga-blocker").also { it.start() }
        handler = Handler(thread.looper)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startInForeground()
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        thread.quitSafely()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startInForeground() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "Blocking", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Shown while Lenga is watching for blocked apps"
                setShowBadge(false)
            }
        )
        val open = android.app.PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
        )
        val n: Notification = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Lenga is blocking")
            .setContentText("Blocked apps will ask for a quick problem first.")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(open)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    private fun poll() {
        val now = System.currentTimeMillis()
        if (now - lastHeartbeat > HEARTBEAT_MS) {
            NativeStore.heartbeat(this)
            lastHeartbeat = now
        }

        // First poll looks back far enough to learn what is already on screen.
        val from = if (lastQuery == 0L) now - 2 * 60 * 60 * 1000L else lastQuery - 500
        lastQuery = now
        val events = usage.queryEvents(from, now)
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            when (e.eventType) {
                ACTIVITY_RESUMED -> foreground = e.packageName
                ACTIVITY_PAUSED -> if (foreground == e.packageName) foreground = null
            }
        }

        val pkg = foreground ?: return
        if (pkg == packageName || pkg !in NativeStore.blocked(this)) return
        if (now - lastLaunch < RELAUNCH_MS) return

        val window = NativeStore.activeWindow(this, now)
        val locked = NativeStore.lockedUntil(this) > now
        val unlocked = NativeStore.unlockedUntil(this, pkg) > now
        if (window == null && !locked && unlocked) return

        lastLaunch = now
        ChallengeActivity.show(this, pkg, window)
    }

    companion object {
        private const val CHANNEL = "blocking"
        private const val NOTIF_ID = 1
        private const val POLL_MS = 400L
        private const val RELAUNCH_MS = 1500L
        private const val HEARTBEAT_MS = 20_000L

        // UsageEvents.Event types (named constants need API 29).
        private const val ACTIVITY_RESUMED = 1
        private const val ACTIVITY_PAUSED = 2

        /** Starts the service if blocking is wanted; safe to call from receivers. */
        fun startIfNeeded(c: Context) {
            if (!c.blockingEnabled || NativeStore.blocked(c).isEmpty()) return
            try {
                ContextCompat.startForegroundService(c, Intent(c, BlockerService::class.java))
            } catch (_: Exception) {
                // Background start not allowed right now; the watchdog banner covers this.
            }
        }

        fun stop(c: Context) {
            c.stopService(Intent(c, BlockerService::class.java))
        }
    }
}
