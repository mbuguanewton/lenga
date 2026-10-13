package com.lenga.lenga_app

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Native-side state shared by the service, the challenge activity and the
 * Flutter engines (through [BlockerPlugin]). Dart pushes config in; the
 * challenge writes lockouts, unlock windows and stats back.
 */
object NativeStore {
    private const val FILE = "lenga_native"
    private const val MAX_EVENTS = 2000

    private fun prefs(c: Context): SharedPreferences =
        c.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    // Config pushed from Dart

    fun blocked(c: Context): Set<String> = prefs(c).getStringSet("blocked", emptySet()) ?: emptySet()

    fun setBlocked(c: Context, packages: Collection<String>) {
        prefs(c).edit().putStringSet("blocked", packages.toSet()).apply()
    }

    fun setLockoutMinutes(c: Context, minutes: Int) = prefs(c).edit().putInt("lockoutMinutes", minutes).apply()

    var Context.blockingEnabled: Boolean
        get() = prefs(this).getBoolean("blockingEnabled", false)
        set(v) = prefs(this).edit().putBoolean("blockingEnabled", v).apply()

    // Lockout and unlock windows

    fun lockedUntil(c: Context): Long = prefs(c).getLong("lockedUntil", 0L)

    fun setLockedUntil(c: Context, ms: Long) = prefs(c).edit().putLong("lockedUntil", ms).apply()

    fun unlockedUntil(c: Context, pkg: String): Long = prefs(c).getLong("unlock.$pkg", 0L)

    fun setUnlockedUntil(c: Context, pkg: String, ms: Long) = prefs(c).edit().putLong("unlock.$pkg", ms).apply()

    // Service watchdog

    fun heartbeat(c: Context) = prefs(c).edit().putLong("heartbeat", System.currentTimeMillis()).apply()

    fun lastHeartbeat(c: Context): Long = prefs(c).getLong("heartbeat", 0L)

    // Calendar windows: [{id,title,start,end}] in epoch millis

    fun setWindows(c: Context, json: String) = prefs(c).edit().putString("windows", json).apply()

    fun windows(c: Context): List<JSONObject> {
        val arr = JSONArray(prefs(c).getString("windows", "[]"))
        return List(arr.length()) { arr.getJSONObject(it) }
    }

    fun activeWindow(c: Context, now: Long): JSONObject? =
        windows(c).firstOrNull { it.getLong("start") <= now && now < it.getLong("end") }

    // Stats events

    @Synchronized
    fun recordEvent(c: Context, json: String) {
        val arr = JSONArray(prefs(c).getString("events", "[]"))
        arr.put(JSONObject(json))
        val trimmed = if (arr.length() > MAX_EVENTS) {
            JSONArray().also { out -> for (i in arr.length() - MAX_EVENTS until arr.length()) out.put(arr.get(i)) }
        } else arr
        prefs(c).edit().putString("events", trimmed.toString()).apply()
    }

    fun eventsJson(c: Context): String = prefs(c).getString("events", "[]") ?: "[]"

    // AI problem queue, one JSON array per difficulty

    @Synchronized
    fun popProblem(c: Context, difficulty: String): String? {
        val arr = JSONArray(prefs(c).getString("queue.$difficulty", "[]"))
        if (arr.length() == 0) return null
        val first = arr.getJSONObject(0).toString()
        val rest = JSONArray().also { out -> for (i in 1 until arr.length()) out.put(arr.get(i)) }
        prefs(c).edit().putString("queue.$difficulty", rest.toString()).apply()
        return first
    }

    fun queueSize(c: Context, difficulty: String): Int =
        JSONArray(prefs(c).getString("queue.$difficulty", "[]")).length()

    @Synchronized
    fun pushProblems(c: Context, difficulty: String, json: String) {
        val arr = JSONArray(prefs(c).getString("queue.$difficulty", "[]"))
        val add = JSONArray(json)
        for (i in 0 until add.length()) arr.put(add.get(i))
        prefs(c).edit().putString("queue.$difficulty", arr.toString()).apply()
    }

    // Misc

    fun askedNotifications(c: Context) = prefs(c).getBoolean("askedNotifications", false)

    fun setAskedNotifications(c: Context) = prefs(c).edit().putBoolean("askedNotifications", true).apply()
}
