package com.cleartime.cleartime

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DeviceHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.cleartime.cleartime/device_info"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getDeviceId" -> {
                    val id = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
                    result.success(id ?: "android_dev_local")
                }
                "getDeviceName" -> {
                    val manufacturer = Build.MANUFACTURER.replaceFirstChar { it.uppercase() }
                    val model = Build.MODEL
                    result.success("$manufacturer $model")
                }
                "getOsVersion" -> {
                    result.success("Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
                }
                "getClientVersion" -> {
                    val pInfo = context.packageManager.getPackageInfo(context.packageName, 0)
                    result.success(pInfo.versionName ?: "1.0.0")
                }
                "isBatteryOptimizationIgnored" -> {
                    val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isIgnored = pm?.isIgnoringBatteryOptimizations(context.packageName) ?: true
                    result.success(isIgnored)
                }
                "getAvailableMemoryMb" -> {
                    val actManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                    val memInfo = ActivityManager.MemoryInfo()
                    actManager?.getMemoryInfo(memInfo)
                    val availableMb = (memInfo.availMem / (1024 * 1024)).toInt()
                    result.success(availableMb)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("DEVICE_INFO_ERROR", e.localizedMessage, e.stackTraceToString())
        }
    }
}
