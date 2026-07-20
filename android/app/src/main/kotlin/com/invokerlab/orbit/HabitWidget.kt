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
                // Read the same data saved by Flutter (RoutineProvider.
                // _updateFeaturedHabitWidget) -- title is a String, streak
                // is saved via HomeWidget.saveWidgetData<int> so it lands
                // in SharedPreferences as a real int, not a String.
                val title = widgetData.getString("title", "No Habit Data")
                val streak = widgetData.getInt("streak", 0)
                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_habit_streak, "$streak Day Streak")
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}