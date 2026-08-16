package com.invokerlab.orbit // Check your MainActivity.kt to ensure this matches

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
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

                // iOS's equivalent widget sets .widgetURL to deep-link via
                // orbit://habit (handled in main.dart's
                // _handleWidgetNavigation); this was never wired up on
                // Android, so tapping the widget did nothing.
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("orbit://habit")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}