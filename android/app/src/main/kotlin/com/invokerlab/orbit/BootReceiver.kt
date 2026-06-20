package com.invokerlab.orbit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives ACTION_BOOT_COMPLETED after device reboot and restarts the Flutter
 * app in the background so it can reschedule its exact alarms via
 * flutter_local_notifications. Without this, all scheduled habit reminders
 * are lost on reboot because Android cancels all AlarmManager alarms.
 *
 * Declared in AndroidManifest.xml with:
 *   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        // Launch the main activity so Flutter can re-register all scheduled
        // notifications. The FLAG_ACTIVITY_NEW_TASK is required when starting
        // an Activity from a non-Activity context.
        val launch = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("boot_reschedule", true)
        }
        context.startActivity(launch)
    }
}
