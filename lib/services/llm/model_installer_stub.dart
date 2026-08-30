import 'package:http/http.dart' as http;

import 'local_model_runtime.dart';
import 'model_distribution_service.dart';

String currentPlatformKey() => 'unknown';

Future<VerifiedModelArtifact> installModel({
  required SignedModelManifest manifest,
  required String modelId,
  required String platformKey,
  required http.Client client,
  void Function(double progress)? onProgress,
}) {
  throw const LocalModelUnavailableException(
    ModelRuntimeStatus.unsupported,
    'Model installation is not supported on this platform.',
  );
}

Future<List<VerifiedModelArtifact>> installedArtifacts() async => const [];

Future<bool> deleteModelFile(String filePath) async => false;
