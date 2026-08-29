package com.cleartime.cleartime

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class UsageStatsHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.cleartime.cleartime/usage_stats"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "hasUsagePermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestUsagePermission" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                    result.success(true)
                }
                "getTodayUsage" -> {
                    val cal = Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, 0)
                        set(Calendar.MINUTE, 0)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }
                    val startTime = cal.timeInMillis
                    val endTime = System.currentTimeMillis()
                    val data = getAggregatedUsageData(startTime, endTime)
                    result.success(data)
                }
                "getUsageRange" -> {
                    val startTime = (call.argument<Number>("startTime") ?: 0L).toLong()
                    val endTime = (call.argument<Number>("endTime") ?: System.currentTimeMillis()).toLong()
                    val data = getAggregatedUsageData(startTime, endTime)
                    result.success(data)
                }
                "getTimeline" -> {
                    val startTime = (call.argument<Number>("startTime") ?: 0L).toLong()
                    val endTime = (call.argument<Number>("endTime") ?: System.currentTimeMillis()).toLong()
                    val events = getUsageTimeline(startTime, endTime)
                    result.success(events)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("USAGE_STATS_ERROR", e.localizedMessage, e.stackTraceToString())
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getAggregatedUsageData(startTime: Long, endTime: Long): Map<String, Any> {
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyMap()

        val statsMap = usageStatsManager.queryAndAggregateUsageStats(startTime, endTime)
        val pm = context.packageManager

        var totalTimeInForegroundMs = 0L
        val appSummaries = mutableListOf<Map<String, Any>>()
        val categoryMinutes = mutableMapOf<String, Long>()

        for ((pkgName, stats) in statsMap) {
            val totalTime = stats.totalTimeInForeground
            if (totalTime > 1000) { // filter out negligible <1s usage
                totalTimeInForegroundMs += totalTime
                val appName = getAppName(pm, pkgName)
                val category = categorizeApp(pm, pkgName)
                val minutes = totalTime / (1000 * 60)

                if (minutes > 0) {
                    categoryMinutes[category] = (categoryMinutes[category] ?: 0L) + minutes
                    appSummaries.add(
                        mapOf(
                            "packageName" to pkgName,
                            "appName" to appName,
                            "category" to category,
                            "durationMinutes" to minutes.toInt(),
                            "launchCount" to 0
                        )
                    )
                }
            }
        }

        // Sort apps by duration descending
        appSummaries.sortByDescending { (it["durationMinutes"] as? Int) ?: 0 }

        val totalMinutes = (totalTimeInForegroundMs / (1000 * 60)).toInt()

        return mapOf(
            "totalMinutes" to totalMinutes,
            "categoryMinutes" to categoryMinutes.mapValues { it.value.toInt() },
            "topApps" to appSummaries.take(10)
        )
    }

    private fun getUsageTimeline(startTime: Long, endTime: Long): List<Map<String, Any>> {
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyList()

        val events = usageStatsManager.queryEvents(startTime, endTime)
        val pm = context.packageManager
        val timeline = mutableListOf<Map<String, Any>>()

        val event = UsageEvents.Event()
        var currentPkg: String? = null
        var sessionStart: Long = 0

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val eventType = event.eventType
            val pkg = event.packageName

            if (eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                if (currentPkg != null && sessionStart > 0 && event.timeStamp > sessionStart) {
                    val durationMin = ((event.timeStamp - sessionStart) / (1000 * 60)).toInt()
                    if (durationMin > 0) {
                        timeline.add(
                            mapOf(
                                "packageName" to currentPkg,
                                "appName" to getAppName(pm, currentPkg),
                                "category" to categorizeApp(pm, currentPkg),
                                "startTime" to sessionStart,
                                "endTime" to event.timeStamp,
                                "durationMinutes" to durationMin
                            )
                        )
                    }
                }
                currentPkg = pkg
                sessionStart = event.timeStamp
            } else if (eventType == UsageEvents.Event.ACTIVITY_PAUSED || eventType == UsageEvents.Event.ACTIVITY_STOPPED) {
                if (currentPkg == pkg && sessionStart > 0 && event.timeStamp > sessionStart) {
                    val durationMin = ((event.timeStamp - sessionStart) / (1000 * 60)).toInt()
                    if (durationMin > 0) {
                        timeline.add(
                            mapOf(
                                "packageName" to pkg,
                                "appName" to getAppName(pm, pkg),
                                "category" to categorizeApp(pm, pkg),
                                "startTime" to sessionStart,
                                "endTime" to event.timeStamp,
                                "durationMinutes" to durationMin
                            )
                        )
                    }
                    currentPkg = null
                    sessionStart = 0
                }
            }
        }

        return timeline
    }

    private fun getAppName(pm: PackageManager, packageName: String): String {
        return try {
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (_: Exception) {
            packageName.substringAfterLast('.')
        }
    }

    private fun categorizeApp(pm: PackageManager, packageName: String): String {
        try {
            val appInfo = pm.getApplicationInfo(packageName, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                when (appInfo.category) {
                    ApplicationInfo.CATEGORY_GAME -> return "Games"
                    ApplicationInfo.CATEGORY_AUDIO, ApplicationInfo.CATEGORY_VIDEO, ApplicationInfo.CATEGORY_IMAGE -> return "Entertainment"
                    ApplicationInfo.CATEGORY_SOCIAL -> return "Social"
                    ApplicationInfo.CATEGORY_NEWS -> return "Reading & News"
                    ApplicationInfo.CATEGORY_MAPS, ApplicationInfo.CATEGORY_PRODUCTIVITY -> return "Productivity"
                    ApplicationInfo.CATEGORY_ACCESSIBILITY -> return "Utilities"
                }
            }
        } catch (_: Exception) {
            // fallback heuristic below
        }

        val lowerPkg = packageName.lowercase()
        return when {
            lowerPkg.contains("game") || lowerPkg.contains("play") || lowerPkg.contains("roblox") || lowerPkg.contains("minecraft") -> "Games"
            lowerPkg.contains("youtube") || lowerPkg.contains("netflix") || lowerPkg.contains("video") || lowerPkg.contains("music") || lowerPkg.contains("spotify") -> "Entertainment"
            lowerPkg.contains("instagram") || lowerPkg.contains("tiktok") || lowerPkg.contains("snapchat") || lowerPkg.contains("social") || lowerPkg.contains("facebook") || lowerPkg.contains("twitter") || lowerPkg.contains("threads") -> "Social"
            lowerPkg.contains("duolingo") || lowerPkg.contains("khan") || lowerPkg.contains("learn") || lowerPkg.contains("study") || lowerPkg.contains("read") || lowerPkg.contains("book") || lowerPkg.contains("kindle") || lowerPkg.contains("classroom") -> "Education"
            lowerPkg.contains("draw") || lowerPkg.contains("paint") || lowerPkg.contains("camera") || lowerPkg.contains("photo") || lowerPkg.contains("creative") -> "Creativity"
            lowerPkg.contains("whatsapp") || lowerPkg.contains("message") || lowerPkg.contains("telegram") || lowerPkg.contains("call") || lowerPkg.contains("dialer") -> "Communication"
            else -> "Utilities"
        }
    }
}
