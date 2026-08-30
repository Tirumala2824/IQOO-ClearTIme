import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../../data/models/llm_models.dart';
import 'local_model_runtime.dart';
import 'model_installer_stub.dart'
    if (dart.library.io) 'model_installer_io.dart'
    if (dart.library.js_interop) 'model_installer_web.dart'
    as installer;

/// One catalog entry from the signed model manifest.
class ManifestModelEntry {
  final String id;
  final String name;
  final String version;
  final int versionNumber;
  final String license;
  final String licenseUrl;
  final int sizeMb;
  final int contextTokens;
  final String quantization;
  final int minMemoryMb;
  final List<String> platforms;
  final Map<String, ManifestArtifact> artifacts;

  const ManifestModelEntry({
    required this.id,
    required this.name,
    required this.version,
    required this.versionNumber,
    required this.license,
    required this.licenseUrl,
    required this.sizeMb,
    required this.contextTokens,
    required this.quantization,
    required this.minMemoryMb,
    required this.platforms,
    required this.artifacts,
  });

  factory ManifestModelEntry.fromJson(Map<String, dynamic> json) {
    final artifacts = <String, ManifestArtifact>{};
    final artifactsJson = json['artifacts'] as Map<String, dynamic>? ?? {};
    artifactsJson.forEach((platform, value) {
      artifacts[platform] =
          ManifestArtifact.fromJson(Map<String, dynamic>.from(value as Map));
    });
    return ManifestModelEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      versionNumber: (json['version_number'] as num? ?? 1).toInt(),
      license: json['license'] as String? ?? 'All rights reserved',
      licenseUrl: json['license_url'] as String? ?? '',
      sizeMb: (json['size_mb'] as num).toInt(),
      contextTokens: (json['context_tokens'] as num).toInt(),
      quantization: json['quantization'] as String? ?? 'q4_k_m',
      minMemoryMb: (json['min_memory_mb'] as num? ?? 2048).toInt(),
      platforms: List<String>.from(json['platforms'] as List? ?? []),
      artifacts: artifacts,
    );
  }

  LocalModelCatalogEntry toCatalogEntry({bool isInstalled = false}) {
    return LocalModelCatalogEntry(
      id: id,
      name: name,
      version: version,
      sizeDescription: '$sizeMb MB',
      sizeMb: sizeMb,
      contextTokens: contextTokens,
      quantization: quantization,
      compatibility: platforms.join(', '),
      isInstalled: isInstalled,
      isActive: false,
      description: 'Local model ($license)',
    );
  }
}

/// A signed per-platform model artifact.
class ManifestArtifact {
  final String url;
  final String sha256;
  final String signature; // base64 Ed25519 signature over the raw bytes

  const ManifestArtifact({
    required this.url,
    required this.sha256,
    required this.signature,
  });

  factory ManifestArtifact.fromJson(Map<String, dynamic> json) =>
      ManifestArtifact(
        url: json['url'] as String,
        sha256: json['sha256'] as String,
        signature: json['signature'] as String? ?? '',
      );
}

/// The signed manifest document.
class SignedModelManifest {
  final int manifestVersion;
  final List<ManifestModelEntry> models;
  final String publicKey; // base64 Ed25519 public key
  final String signature; // base64 signature over the canonical payload

  const SignedModelManifest({
    required this.manifestVersion,
    required this.models,
    required this.publicKey,
    required this.signature,
  });

  factory SignedModelManifest.fromJson(Map<String, dynamic> json) =>
      SignedModelManifest(
        manifestVersion: (json['manifest_version'] as num? ?? 1).toInt(),
        models: (json['models'] as List<dynamic>? ?? [])
            .map((m) => ManifestModelEntry.fromJson(
                Map<String, dynamic>.from(m as Map)))
            .toList(),
        publicKey: json['public_key'] as String? ?? '',
        signature: json['signature'] as String? ?? '',
      );

  Map<String, dynamic> payloadForVerification() => {
        'manifest_version': manifestVersion,
        'models': models
            .map((m) => {
                  'id': m.id,
                  'name': m.name,
                  'version': m.version,
                  'version_number': m.versionNumber,
                  'license': m.license,
                  'license_url': m.licenseUrl,
                  'size_mb': m.sizeMb,
                  'context_tokens': m.contextTokens,
                  'quantization': m.quantization,
                  'min_memory_mb': m.minMemoryMb,
                  'platforms': m.platforms,
                  'artifacts': m.artifacts.map((platform, a) => MapEntry(platform, {
                        'url': a.url,
                        'sha256': a.sha256,
                        'signature': a.signature,
                      })),
                })
            .toList(),
      };
}

Future<bool> verifyEd25519({
  required String publicKeyBase64,
  required String signatureBase64,
  required List<int> message,
}) async {
  try {
    final algorithm = Ed25519();
    final publicKey = SimplePublicKey(
      base64Decode(publicKeyBase64),
      type: KeyPairType.ed25519,
    );
    return await algorithm.verify(
      message,
      signature: Signature(base64Decode(signatureBase64), publicKey: publicKey),
    );
  } catch (_) {
    return false;
  }
}

/// Downloads and verifies the licensed, signed model distribution manifest
/// and its artifacts. First-run setup is always explicit: nothing downloads
/// unless [fetchManifest] or [installModel] is called by the user.
class ModelDistributionService {
  static const String defaultManifestUrl =
      'https://models.cleartime.app/manifest.json';

  final http.Client _client;

  ModelDistributionService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches and verifies the manifest from [manifestUrl].
  Future<SignedModelManifest> fetchManifest({String? manifestUrl}) async {
    final url = manifestUrl ?? defaultManifestUrl;
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw LocalModelUnavailableException(
        ModelRuntimeStatus.error,
        'Model catalog unavailable (HTTP ${response.statusCode}).',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final manifest = SignedModelManifest.fromJson(json);
    if (manifest.publicKey.isEmpty || manifest.signature.isEmpty) {
      throw const LocalModelUnavailableException(
        ModelRuntimeStatus.error,
        'Model catalog is not signed.',
      );
    }
    final verified = await verifyEd25519(
      publicKeyBase64: manifest.publicKey,
      signatureBase64: manifest.signature,
      message: utf8.encode(jsonEncode(manifest.payloadForVerification())),
    );
    if (!verified) {
      throw const LocalModelUnavailableException(
        ModelRuntimeStatus.error,
        'Model catalog signature check failed.',
      );
    }
    return manifest;
  }

  /// Installs a model for the current platform, reporting progress via
  /// [onProgress] (0.0–1.0). Returns the verified local artifact.
  Future<VerifiedModelArtifact> installModel({
    required SignedModelManifest manifest,
    required String modelId,
    void Function(double progress)? onProgress,
  }) {
    return installer.installModel(
      manifest: manifest,
      modelId: modelId,
      platformKey: installer.currentPlatformKey(),
      client: _client,
      onProgress: onProgress,
    );
  }

  /// Locally installed artifacts that still match their recorded checksum.
  Future<List<VerifiedModelArtifact>> installedArtifacts() =>
      installer.installedArtifacts();

  /// Deletes a local model file. Returns true when the file existed.
  Future<bool> deleteModelFile(String filePath) =>
      installer.deleteModelFile(filePath);

  /// Raw hash for verifying a downloaded payload against a manifest entry.
  static String sha256Bytes(List<int> bytes) =>
      sha256.convert(bytes).toString();
}