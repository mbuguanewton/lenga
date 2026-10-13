package com.lenga.lenga_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Sets an exact alarm at the start of each blocked calendar event so the
 * blocker service is guaranteed to be running when the window opens. The
 * window itself is enforced by [BlockerService] reading [NativeStore.windows],
 * so a missed alarm can't leave an event unblocked while the service is alive.
 */
object CalendarBlockScheduler {
    private const val ACTION = "com.lenga.lenga_app.CALENDAR_WINDOW"

    fun schedule(c: Context, previousIds: Set<Int> = emptySet()) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        previousIds.forEach { am.cancel(pending(c, it)) }
        val now = System.currentTimeMillis()
        for (w in NativeStore.windows(c)) {
            val start = w.getLong("start")
            if (start <= now) continue
            val pi = pending(c, requestCode(w.getString("id")))
            val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
            if (exact) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, start, pi)
            else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, start, pi)
        }
    }

    /** Request codes of the currently stored windows, to cancel before rescheduling. */
    fun currentIds(c: Context): Set<Int> = NativeStore.windows(c).map { requestCode(it.getString("id")) }.toSet()

    private fun requestCode(eventId: String) = eventId.hashCode()

    private fun pending(c: Context, code: Int): PendingIntent =
        PendingIntent.getBroadcast(
            c, code,
            Intent(c, AlarmReceiver::class.java).setAction(ACTION),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

    class AlarmReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            BlockerService.startIfNeeded(context)
        }
    }
}
