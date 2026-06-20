package com.invokerlab.orbit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Handles the custom ACTION_ALARM_TRIGGERED broadcast sent by the app's
 * AlarmManager-based scheduling. Brings the Flutter app to the foreground
 * so it can display the triggered habit reminder.
 *
 * Action: com.orbit.habs.ACTION_ALARM_TRIGGERED
 * Declared in AndroidManifest.xml.
 */
class AlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_ALARM_TRIGGERED = "com.orbit.habs.ACTION_ALARM_TRIGGERED"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_ALARM_TRIGGERED) return

        // Forward to MainActivity so Flutter can handle the alarm payload.
        val launch = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("alarm_triggered", true)
                // Forward any extras the scheduler attached (e.g. habit id, title)
                intent.extras?.let { putExtras(it) }
            }
        launch?.let { context.startActivity(it) }
    }
}
