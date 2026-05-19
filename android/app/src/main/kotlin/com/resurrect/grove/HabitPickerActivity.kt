package com.resurrect.grove

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.ListView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import org.json.JSONArray
import org.json.JSONObject

class HabitPickerActivity : AppCompatActivity() {

    companion object {
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val KEY_HABITS    = "flutter.grove_v2_ids"
    }

    private var widgetId   = AppWidgetManager.INVALID_APPWIDGET_ID
    private var isCalendar = true   // true = calendar widget, false = tree widget

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

        setContentView(R.layout.activity_habit_picker)

        val widgetTypeLabel = if (isCalendar) "Calendar Widget" else "Tree Widget"
        findViewById<TextView>(R.id.picker_widget_type).text = widgetTypeLabel

        val prefs    = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val habitIds = loadHabitIds(prefs)
        val habits   = habitIds.mapNotNull { id ->
            val obj = loadHabit(prefs, id) ?: return@mapNotNull null
            Pair(id, obj.optString("name", id))
        }

        val listView  = findViewById<ListView>(R.id.picker_list)
        val emptyView = findViewById<TextView>(R.id.picker_empty)

        if (habits.isEmpty()) {
            listView.visibility  = View.GONE
            emptyView.visibility = View.VISIBLE
            return
        }

        listView.adapter = HabitAdapter(habits)
        listView.setOnItemClickListener { _, _, position, _ ->
            val (habitId, _) = habits[position]
            saveSelection(habitId)
            triggerWidgetUpdate()

            setResult(RESULT_OK,
                      Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
            finish()
        }
    }

    // ── Persistence ───────────────────────────────────────────────────────

    private fun saveSelection(habitId: String) {
        if (isCalendar) {
            getSharedPreferences(CalendarWidgetProvider.NAV_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString("cal_habit_id_$widgetId", habitId)
            .apply()
        } else {
            getSharedPreferences("grove_widget_nav", Context.MODE_PRIVATE)
            .edit()
            .putString("tree_habit_id_$widgetId", habitId)
            .apply()
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
        val raw = prefs.getString(KEY_HABITS, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { arr.getString(it) }
        } catch (_: Exception) { emptyList() }
    }

    private fun loadHabit(prefs: android.content.SharedPreferences, id: String): JSONObject? {
        val json = prefs.getString("flutter.$id", null) ?: return null
        return try { JSONObject(json) } catch (_: Exception) { null }
    }

    // ── Adapter ───────────────────────────────────────────────────────────

    inner class HabitAdapter(
        private val habits: List<Pair<String, String>>
    ) : ArrayAdapter<Pair<String, String>>(this@HabitPickerActivity, 0, habits) {

        override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
            val view = convertView
            ?: LayoutInflater.from(context)
            .inflate(R.layout.list_item_habit, parent, false)
            view.findViewById<TextView>(R.id.habit_item_name).text = habits[position].second
            return view
        }
    }
}
