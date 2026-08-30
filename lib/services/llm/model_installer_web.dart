import 'package:http/http.dart' as http;

import 'local_model_runtime.dart';
import 'model_distribution_service.dart';

/// Web has no native GGUF file system path. Model installation on the web is
/// intentionally unsupported until a WebGPU-capable runtime is provisioned;
/// browsers then report the truthful unsupported state instead of running a
/// fake model.
String currentPlatformKey() => 'web';

Future<VerifiedModelArtifact> installModel({
  required SignedModelManifest manifest,
  required String modelId,
  required String platformKey,
  required http.Client client,
  void Function(double progress)? onProgress,
}) {
  throw const LocalModelUnavailableException(
    ModelRuntimeStatus.unsupported,
    'Model installation is not available in this browser.',
  );
}

Future<List<VerifiedModelArtifact>> installedArtifacts() async => const [];

Future<bool> deleteModelFile(String filePath) async => false;
