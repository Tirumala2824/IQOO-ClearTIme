package com.cleartime.cleartime

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Register Android UsageStats platform channel
        val usageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UsageStatsHandler.CHANNEL_NAME)
        usageChannel.setMethodCallHandler(UsageStatsHandler(this))

        // 2. Register Local On-Device LLM platform channel
        val llmChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LocalLlmHandler.CHANNEL_NAME)
        llmChannel.setMethodCallHandler(LocalLlmHandler(this))

        // 3. Register Native Android Notification platform channel
        val notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NotificationHandler.CHANNEL_NAME)
        notificationChannel.setMethodCallHandler(NotificationHandler(this))

        // 4. Register Device Information platform channel
        val deviceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DeviceHandler.CHANNEL_NAME)
        deviceChannel.setMethodCallHandler(DeviceHandler(this))
    }
}
