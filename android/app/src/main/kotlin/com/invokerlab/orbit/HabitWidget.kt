package com.invokerlab.orbit // Check your MainActivity.kt to ensure this matches

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class HabitWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.habit_widget).apply {
                // Read the same data string saved by Flutter
                val title = widgetData.getString("title", "No Habit Data")
                setTextViewText(R.id.widget_title, title)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}