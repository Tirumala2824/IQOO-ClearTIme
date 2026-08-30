import 'local_model_runtime.dart';
import 'llama_runtime_stub.dart'
    if (dart.library.io) 'llama_runtime_io.dart'
    if (dart.library.js_interop) 'llama_runtime_web.dart' as impl;

/// Creates the platform-appropriate local model runtime via conditional
/// imports: native llama.cpp on Android/iOS/desktop, WebGPU on supported
/// browsers, and a truthful unavailable runtime elsewhere.
LocalModelRuntime createLocalModelRuntime() => impl.createPlatformRuntime();