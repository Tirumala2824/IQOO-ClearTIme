import 'dart:io';

import 'package:llama_cpp_dart/llama_cpp_dart.dart' as llama;

import 'local_model_runtime.dart';

/// Native GGUF / llama.cpp runtime via llama_cpp_dart.
///
/// The llama.cpp library itself must be provisioned per platform
/// (Android .so via JNI config, iOS framework, desktop .dll/.so/.dylib).
/// When the library or model cannot be loaded, the runtime reports an
/// honest error state and generation refuses to run — there is no
/// simulated output path.
class LlamaCppRuntime implements LocalModelRuntime {
  llama.Llama? _llama;
  ModelRuntimeStatus _status = ModelRuntimeStatus.notInstalled;
  String _errorMessage = '';
  String? _libraryPath;

  LlamaCppRuntime({String? libraryPath}) : _libraryPath = libraryPath;

  @override
  String get engineName => 'llama.cpp (native)';

  @override
  ModelRuntimeStatus get status => _status;

  String get errorMessage => _errorMessage;

  @override
  Future<void> initialize() async {
    // On mobile the library ships via the runner/JNI; on desktop it must be
    // discoverable. The default resolution below matches the llama.cpp
    // library name convention for the host platform.
    _libraryPath ??= switch (Platform.operatingSystem) {
      'windows' => 'llama.dll',
      'macos' => 'libllama.dylib',
      _ => 'libllama.so',
    };
    try {
      llama.Llama.libraryPath = _libraryPath!;
    } catch (_) {
      _status = ModelRuntimeStatus.unsupported;
      _errorMessage =
          'llama.cpp runtime library is not available on this device.';
    }
  }

  @override
  Future<void> loadModel(VerifiedModelArtifact artifact) async {
    try {
      if (!File(artifact.filePath).existsSync()) {
        throw const LocalModelUnavailableException(
          ModelRuntimeStatus.error,
          'Model file was deleted. Download it again from the signed catalog.',
        );
      }
      _status = ModelRuntimeStatus.loading;
      final previous = _llama;
      _llama = llama.Llama(artifact.filePath);
      _status = ModelRuntimeStatus.ready;
      previous?.dispose();
    } catch (e) {
      _status = ModelRuntimeStatus.error;
      _errorMessage = 'Model could not be loaded: $e';
    }
  }

  @override
  Future<void> unload() async {
    _llama?.dispose();
    _llama = null;
    _status = ModelRuntimeStatus.notInstalled;
  }

  @override
  Future<ModelGenerationResult> generate(
    String prompt, {
    int maxTokens = 512,
  }) async {
    if (_status != ModelRuntimeStatus.ready || _llama == null) {
      throw LocalModelUnavailableException(
        _status,
        _status == ModelRuntimeStatus.notInstalled
            ? 'No model is installed. Set up the local model first.'
            : 'The model is not ready ($_errorMessage)',
      );
    }

    final stopwatch = Stopwatch()..start();
    final buffer = StringBuffer();
    var tokens = 0;

    _llama!.setPrompt(prompt);
    while (true) {
      final (String token, bool done) = _llama!.getNext();
      if (token.isEmpty) break;
      buffer.write(token);
      tokens++;
      if (done || tokens >= maxTokens) break;
    }
    stopwatch.stop();

    return ModelGenerationResult(
      text: buffer.toString().trim(),
      tokensGenerated: tokens,
      elapsed: stopwatch.elapsed,
    );
  }

  @override
  Future<void> dispose() async {
    _llama?.dispose();
    _llama = null;
  }
}

LocalModelRuntime createPlatformRuntime() => LlamaCppRuntime();