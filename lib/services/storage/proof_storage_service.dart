import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Private proof media storage.
///
/// Proof files are uploaded to the private `mission-proofs` bucket under
/// `{mission_id}/{file_name}`. Supabase storage RLS restricts uploads to the
/// assigned child and downloads to linked parents, so a local device path is
/// never sent as proof. When storage is unavailable the path stays local and
/// callers surface the failure truthfully.
class ProofStorageService {
  static const String bucketName = 'mission-proofs';

  ProofStorageService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get _safeClient {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Uploads [filePath] for [missionId]; returns the storage object path.
  Future<String> uploadProof({
    required String missionId,
    required String filePath,
  }) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) {
      throw StateError('Proof upload needs an authenticated session.');
    }
    final file = File(filePath);
    final fileName = file.uri.pathSegments.last;
    final objectPath = '$missionId/$fileName';
    await client.storage.from(bucketName).upload(objectPath, file);
    return objectPath;
  }

  /// Resolves a displayable (signed) URL for a stored proof object.
  Future<String?> downloadProofUrl(String objectPath) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return null;
    final url =
        await client.storage.from(bucketName).createSignedUrl(objectPath, 3600);
    return url;
  }

  /// Removes a previously uploaded proof object (e.g. replaced submission).
  Future<bool> deleteProof(String objectPath) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return false;
    await client.storage.from(bucketName).remove([objectPath]);
    return true;
  }
}