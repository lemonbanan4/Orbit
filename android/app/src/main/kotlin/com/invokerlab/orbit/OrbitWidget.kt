package com.invokerlab.orbit

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
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

            // iOS sets .widgetURL on its equivalent widgets to deep-link via
            // orbit:// (handled in main.dart's _handleWidgetNavigation); this
            // was never wired up on Android at all, so tapping the widget did
            // nothing here despite HomeWidget.widgetClicked already being
            // registered and ready to receive it. Empty host -> '/' (the
            // dashboard, go_router's root route) -- this widget isn't tied
            // to one specific habit like HabitWidget below.
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("orbit://")
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
