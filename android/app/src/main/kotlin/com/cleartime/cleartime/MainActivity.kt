package com.cleartime.cleartime

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register Android UsageStats platform channel
        val usageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UsageStatsHandler.CHANNEL_NAME)
        usageChannel.setMethodCallHandler(UsageStatsHandler(this))

        // Register Local On-Device LLM platform channel
        val llmChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LocalLlmHandler.CHANNEL_NAME)
        llmChannel.setMethodCallHandler(LocalLlmHandler(this))
    }
}
