package com.invokerlab.orbit

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class OrbitWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.orbit_widget)

            val streak = widgetData.getString("widget_streak", "0") ?: "0"
            val intention = widgetData.getString("widget_intention", "Set an intention today.")
                ?: "Set an intention today."

            views.setTextViewText(R.id.widget_streak, "$streak Day Streak")
            views.setTextViewText(R.id.widget_intention, intention)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
