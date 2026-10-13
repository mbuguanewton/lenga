package com.lenga.lenga_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Periodically refreshes calendar events while Lenga is closed. It boots a
 * headless Flutter engine running `calendarSyncMain`, which fetches events with
 * a silent Google token and pushes the blocking windows back through
 * [BlockerPlugin]. If the silent token isn't available it does nothing and the
 * next foreground refresh recovers.
 */
class CalendarSyncWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val done = CountDownLatch(1)
        val main = Handler(Looper.getMainLooper())
        var engine: FlutterEngine? = null

        main.post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)
                val e = FlutterEngine(applicationContext)
                engine = e
                BlockerPlugin.registerHeadless(e, applicationContext) { done.countDown() }
                e.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "calendarSyncMain")
                )
            } catch (_: Throwable) {
                done.countDown()
            }
        }

        val finished = done.await(TIMEOUT_SECONDS, TimeUnit.SECONDS)
        main.post { engine?.destroy() }
        // Periodic work runs again anyway, so a timeout isn't worth a retry storm.
        return if (finished) Result.success() else Result.failure()
    }

    companion object {
        private const val UNIQUE_NAME = "calendar-sync"
        private const val TIMEOUT_SECONDS = 90L
        private const val INTERVAL_MINUTES = 30L

        fun schedule(c: Context) {
            val request = PeriodicWorkRequestBuilder<CalendarSyncWorker>(INTERVAL_MINUTES, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            // KEEP: calling this on every foreground refresh must not reset the timer.
            WorkManager.getInstance(c).enqueueUniquePeriodicWork(UNIQUE_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }

        fun cancel(c: Context) {
            WorkManager.getInstance(c).cancelUniqueWork(UNIQUE_NAME)
        }
    }
}
