package com.cleartime.cleartime

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Deprecated platform bridge.
 *
 * Real inference now runs through the Dart-side llama.cpp runtime
 * (llama_cpp_dart). This channel remains only so older callers receive a
 * truthful "model not available" answer instead of a fabricated one.
 */
class LocalLlmHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.cleartime.cleartime/local_llm"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(false)
            "getModelInfo" -> result.success(
                mapOf(
                    "modelName" to "No model loaded",
                    "version" to "-",
                    "contextLimit" to 0,
                    "quantization" to "-",
                    "sizeMb" to 0,
                    "isLoaded" to false,
                    "engineType" to "llama.cpp (Dart runtime)",
                    "memoryUsageMb" to 0,
                    "isInstalled" to false
                )
            )
            "getInstalledModels", "getAvailableModels" -> result.success(emptyList<Map<String, Any>>())
            "getContextLimit" -> result.success(0)
            "getMemoryUsage" -> result.success(0)
            "generate", "testInference" -> result.error(
                "LOCAL_LLM_UNAVAILABLE",
                "The local model is managed by the Dart llama.cpp runtime. " +
                        "No inference is available through this channel.",
                null
            )
            else -> result.notImplemented()
        }
    }
}
