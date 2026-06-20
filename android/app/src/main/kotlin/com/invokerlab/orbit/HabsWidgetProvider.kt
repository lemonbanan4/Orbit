package com.invokerlab.orbit

import com.invokerlab.orbit.R

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class HabsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            // Retrieve the streak count saved from Flutter!
            val streakCount = widgetData.getInt("streakCount", 0)
            views.setTextViewText(R.id.streak_text, streakCount.toString())

            

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}