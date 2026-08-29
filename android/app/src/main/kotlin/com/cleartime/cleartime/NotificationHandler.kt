package com.cleartime.cleartime

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NotificationHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.cleartime.cleartime/notifications"
        const val CHANNEL_CHILD_WELLBEING = "cleartime_child_wellbeing"
        const val CHANNEL_PARENT_ALERTS = "cleartime_parent_alerts"
        const val CHANNEL_REPORTS = "cleartime_reports"
        const val CHANNEL_GENERAL = "cleartime_general"
    }

    init {
        createNotificationChannels()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initialize" -> {
                    createNotificationChannels()
                    result.success(true)
                }
                "hasPermission" -> {
                    result.success(hasNotificationPermission())
                }
                "requestPermission" -> {
                    result.success(hasNotificationPermission())
                }
                "showNotification" -> {
                    val id = (call.argument<Number>("id") ?: 100).toInt()
                    val title = call.argument<String>("title") ?: "ClearTime"
                    val body = call.argument<String>("body") ?: ""
                    val channelId = call.argument<String>("channelId") ?: CHANNEL_GENERAL

                    showLocalNotification(id, title, body, channelId)
                    result.success(true)
                }
                "scheduleNotification" -> {
                    val id = (call.argument<Number>("id") ?: 101).toInt()
                    val title = call.argument<String>("title") ?: "ClearTime"
                    val body = call.argument<String>("body") ?: ""
                    val channelId = call.argument<String>("channelId") ?: CHANNEL_REPORTS

                    showLocalNotification(id, title, body, channelId)
                    result.success(true)
                }
                "cancelNotification" -> {
                    val id = (call.argument<Number>("id") ?: 0).toInt()
                    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    manager?.cancel(id)
                    result.success(true)
                }
                "cancelAllNotifications" -> {
                    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    manager?.cancelAll()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("NOTIFICATION_ERROR", e.localizedMessage, e.stackTraceToString())
        }
    }

    private fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            NotificationManagerCompat.from(context).areNotificationsEnabled()
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

            // 1. Child Wellbeing Channel (Gentle, positive sound/vibe)
            val childChannel = NotificationChannel(
                CHANNEL_CHILD_WELLBEING,
                "Child Wellbeing & Quests",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Gentle quest milestones, mindful break reminders, and achievements."
                enableVibration(true)
            }

            // 2. Parent Alerts Channel (Privacy-safe trigger notifications)
            val parentChannel = NotificationChannel(
                CHANNEL_PARENT_ALERTS,
                "Parent Wellbeing Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Configured wellbeing alerts and mindful milestone updates."
                enableVibration(true)
            }

            // 3. Reports Channel
            val reportChannel = NotificationChannel(
                CHANNEL_REPORTS,
                "Scheduled Wellbeing Reports",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Weekly and daily approved report ready notifications."
            }

            // 4. General Channel
            val generalChannel = NotificationChannel(
                CHANNEL_GENERAL,
                "ClearTime General",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "General system notices and sync status."
            }

            manager.createNotificationChannel(childChannel)
            manager.createNotificationChannel(parentChannel)
            manager.createNotificationChannel(reportChannel)
            manager.createNotificationChannel(generalChannel)
        }
    }

    private fun showLocalNotification(id: Int, title: String, body: String, channelId: String) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val smallIconRes = context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName)
        val icon = if (smallIconRes != 0) smallIconRes else android.R.drawable.ic_dialog_info

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.notify(id, builder.build())
    }
}
