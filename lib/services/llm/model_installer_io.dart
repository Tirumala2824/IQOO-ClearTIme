import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'local_model_runtime.dart';
import 'model_distribution_service.dart';

String currentPlatformKey() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}

Future<VerifiedModelArtifact> installModel({
  required SignedModelManifest manifest,
  required String modelId,
  required String platformKey,
  required http.Client client,
  void Function(double progress)? onProgress,
}) async {
  final model = manifest.models.where((m) => m.id == modelId).firstOrNull;
  if (model == null) {
    throw LocalModelUnavailableException(
      ModelRuntimeStatus.error,
      'Model "$modelId" is not in the signed catalog.',
    );
  }
  final artifact = model.artifacts[platformKey];
  if (artifact == null) {
    throw LocalModelUnavailableException(
      ModelRuntimeStatus.error,
      'Model "$modelId" is not available for this platform.',
    );
  }

  final dir = await getApplicationSupportDirectory();
  final modelsDir = Directory('${dir.path}/models');
  if (!modelsDir.existsSync()) {
    modelsDir.createSync(recursive: true);
  }
  final target = File('${modelsDir.path}/${model.id}-v${model.versionNumber}.gguf');

  if (target.existsSync()) {
    final existingHash = sha256.convert(await target.readAsBytes()).toString();
    if (existingHash == artifact.sha256) {
      onProgress?.call(1.0);
      return VerifiedModelArtifact(
        modelId: model.id,
        version: model.version,
        license: model.license,
        versionNumber: model.versionNumber,
        sha256: artifact.sha256,
        filePath: target.path,
      );
    }
  }

  final request = http.Request('GET', Uri.parse(artifact.url));
  final streamed = await client.send(request);
  if (streamed.statusCode != 200) {
    throw LocalModelUnavailableException(
      ModelRuntimeStatus.error,
      'Model download failed (HTTP ${streamed.statusCode}).',
    );
  }

  final bytesBuilder = BytesBuilder(copy: false);
  var downloaded = 0;
  final expected = streamed.contentLength ?? (model.sizeMb * 1024 * 1024);
  await for (final chunk in streamed.stream) {
    bytesBuilder.add(chunk);
    downloaded += chunk.length;
    if (expected > 0) {
      onProgress?.call((downloaded / expected).clamp(0.0, 1.0));
    }
  }

  final bytes = bytesBuilder.takeBytes();
  final hash = sha256.convert(bytes).toString();
  if (hash != artifact.sha256) {
    throw const LocalModelUnavailableException(
      ModelRuntimeStatus.error,
      'Downloaded model failed its checksum check.',
    );
  }

  if (artifact.signature.isNotEmpty) {
    final verified = await verifyEd25519(
      publicKeyBase64: manifest.publicKey,
      signatureBase64: artifact.signature,
      message: bytes,
    );
    if (!verified) {
      throw const LocalModelUnavailableException(
        ModelRuntimeStatus.error,
        'Downloaded model failed its signature check.',
      );
    }
  }

  await target.writeAsBytes(bytes, flush: true);
  onProgress?.call(1.0);
  return VerifiedModelArtifact(
    modelId: model.id,
    version: model.version,
    license: model.license,
    versionNumber: model.versionNumber,
    sha256: artifact.sha256,
    filePath: target.path,
  );
}

Future<List<VerifiedModelArtifact>> installedArtifacts() async {
  final dir = await getApplicationSupportDirectory();
  final modelsDir = Directory('${dir.path}/models');
  if (!modelsDir.existsSync()) return const [];
  final results = <VerifiedModelArtifact>[];
  await for (final entity in modelsDir.list()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.endsWith('.gguf')) continue;
    final hash = sha256.convert(await entity.readAsBytes()).toString();
    results.add(VerifiedModelArtifact(
      modelId: name.split('-v').first,
      version: name.replaceFirst('.gguf', ''),
      license: 'local',
      versionNumber: 0,
      sha256: hash,
      filePath: entity.path,
    ));
  }
  return results;
}

Future<bool> deleteModelFile(String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) return false;
  await file.delete();
  return true;
}
