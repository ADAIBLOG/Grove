package com.resurrect.grove

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject

class HabitPickerActivity : Activity() {

    companion object {
        private const val TAG           = "GroveHabitPicker"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val KEY_HABITS    = "flutter.grove_v2_ids"
        private const val LIST_PREFIX   = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"
    }

    private var widgetId   = AppWidgetManager.INVALID_APPWIDGET_ID
    private var isCalendar = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        setResult(RESULT_CANCELED,
                  Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))

        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) { finish(); return }

        val mgr          = AppWidgetManager.getInstance(this)
        val providerName = mgr.getAppWidgetInfo(widgetId)?.provider?.className ?: ""
        isCalendar       = providerName.contains("Calendar", ignoreCase = true)

        val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)

        // ── Dump every key in the prefs file so we can see what's actually there ──
        Log.d(TAG, "=== FlutterSharedPreferences dump ===")
        val allKeys = prefs.all
        Log.d(TAG, "Total keys: ${allKeys.size}")
        allKeys.forEach { (k, v) ->
            val preview = when (v) {
                is String -> if (v.length > 120) v.take(120) + "…" else v
                is Set<*> -> "StringSet(${v.size}): ${v.take(3)}…"
                else      -> v.toString()
            }
            Log.d(TAG, "  KEY='$k'  TYPE=${v?.javaClass?.simpleName}  VAL=$preview")
        }
        Log.d(TAG, "=== end dump ===")

        val habitIds = loadHabitIds(prefs)
        Log.d(TAG, "Loaded ${habitIds.size} habit IDs: $habitIds")

        val habits = habitIds.mapNotNull { id ->
            val obj = loadHabit(prefs, id)
            Log.d(TAG, "  habit '$id' -> ${if (obj != null) obj.optString("name", "?") else "NOT FOUND"}")
            obj ?: return@mapNotNull null
            Pair(id, obj.optString("name", id))
        }

        setContentView(buildUI(habits))
    }

    // ── Build UI programmatically ─────────────────────────────────────────

    private fun buildUI(habits: List<Pair<String, String>>): View {
        val dp = { n: Int ->
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, n.toFloat(), resources.displayMetrics
            ).toInt()
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#1A1A2E"))
            setPadding(dp(16), dp(24), dp(16), dp(16))
        }

        val widgetTypeLabel = if (isCalendar) "Calendar Widget" else "Tree Widget"
        root.addView(TextView(this).apply {
            text = "Select a habit for your $widgetTypeLabel"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setTypeface(null, Typeface.BOLD)
            setPadding(0, 0, 0, dp(16))
        })

        if (habits.isEmpty()) {
            root.addView(TextView(this).apply {
                text = "No habits found.\nCreate a habit in Grove first."
                setTextColor(Color.parseColor("#AAAAAA"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                gravity = Gravity.CENTER
                setPadding(dp(8), dp(32), dp(8), dp(32))
            })
            return root
        }

        val scroll = ScrollView(this)
        val list   = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }

        habits.forEach { (id, name) ->
            list.addView(TextView(this).apply {
                text = "🌿  $name"
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                setPadding(dp(16), dp(14), dp(16), dp(14))
                setBackgroundColor(Color.parseColor("#2A2A3E"))
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).also { it.setMargins(0, 0, 0, dp(8)) }
                isClickable = true
                isFocusable = true
                setOnClickListener { onHabitSelected(id) }
            })
        }

        scroll.addView(list)
        root.addView(scroll)
        return root
    }

    // ── Selection ─────────────────────────────────────────────────────────

    private fun onHabitSelected(habitId: String) {
        saveSelection(habitId)
        triggerWidgetUpdate()
        setResult(RESULT_OK,
                  Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        finish()
    }

    private fun saveSelection(habitId: String) {
        if (isCalendar) {
            getSharedPreferences(CalendarWidgetProvider.NAV_PREFS, Context.MODE_PRIVATE)
            .edit().putString("cal_habit_id_$widgetId", habitId).apply()
        } else {
            getSharedPreferences("grove_widget_nav", Context.MODE_PRIVATE)
            .edit().putString("tree_habit_id_$widgetId", habitId).apply()
        }
    }

    private fun triggerWidgetUpdate() {
        val mgr = AppWidgetManager.getInstance(this)
        val cls = if (isCalendar) CalendarWidgetProvider::class.java
        else            TreeWidgetProvider::class.java
            val ids = mgr.getAppWidgetIds(ComponentName(this, cls))
            if (ids.isNotEmpty()) {
                sendBroadcast(Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                    component = ComponentName(this@HabitPickerActivity, cls)
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                })
            }
    }

    // ── Data helpers ──────────────────────────────────────────────────────

    private fun loadHabitIds(prefs: android.content.SharedPreferences): List<String> {
        // Try 1: native StringSet (shared_preferences 2.x)
        try {
            val set = prefs.getStringSet(KEY_HABITS, null)
            if (!set.isNullOrEmpty()) {
                Log.d(TAG, "loadHabitIds: found StringSet with ${set.size} items")
                return set.toList()
            }
        } catch (e: ClassCastException) {
            Log.d(TAG, "loadHabitIds: not a StringSet, trying String")
        }

        val raw = prefs.getString(KEY_HABITS, null)
        if (raw == null) {
            Log.d(TAG, "loadHabitIds: key '$KEY_HABITS' not found at all")
            return emptyList()
        }
        Log.d(TAG, "loadHabitIds: raw value (first 200): ${raw.take(200)}")

        // Try 2: "This is the prefix for a list." + "!" + JSON array
        // e.g. VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!["id1","id2"]
        if (raw.startsWith(LIST_PREFIX)) {
            val bang = raw.indexOf('!')
            if (bang >= 0) {
                val jsonPart = raw.substring(bang + 1)
                return try {
                    val arr = JSONArray(jsonPart)
                    (0 until arr.length()).map { arr.getString(it) }
                } catch (_: Exception) { emptyList() }
            }
        }

        // Try 3: plain JSON array
        return try {
            val arr = JSONArray(raw)
            val items = (0 until arr.length()).map { arr.getString(it) }
            Log.d(TAG, "loadHabitIds: decoded JSON array: $items")
            items
        } catch (e: Exception) {
            Log.e(TAG, "loadHabitIds: all formats failed. raw='$raw'", e)
            emptyList()
        }
    }

    private fun loadHabit(prefs: android.content.SharedPreferences, id: String): JSONObject? {
        val json = prefs.getString("flutter.$id", null) ?: return null
        return try { JSONObject(json) } catch (_: Exception) { null }
    }
}
