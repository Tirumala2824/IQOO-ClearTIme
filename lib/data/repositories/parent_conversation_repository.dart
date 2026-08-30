import '../models/approved_report_model.dart';
import '../../services/storage/encrypted_device_store.dart';

abstract class ParentConversationRepository {
  Future<List<ParentAIConversation>> getConversations(String childId);
  Future<ParentAIConversation?> getConversation(String conversationId);
  Future<void> saveConversation(ParentAIConversation conversation);
  Future<void> deleteConversation(String conversationId);
  Future<void> deleteAllConversations(String childId);
  Future<void> clearAll();
}

/// Encrypted on-device parent AI chat storage. Never synced to a server.
class EncryptedParentConversationRepository
    implements ParentConversationRepository {
  final EncryptedDeviceStore _store;

  EncryptedParentConversationRepository({required EncryptedDeviceStore store})
      : _store = store;

  @override
  Future<List<ParentAIConversation>> getConversations(String childId) async {
    final jsons = await _store.getAllJson(
      EncryptedDeviceStore.parentConversationsBox,
      onCorrupt: (key, _) =>
          _store.delete(EncryptedDeviceStore.parentConversationsBox, key),
    );
    final conversations = <ParentAIConversation>[];
    for (final json in jsons) {
      try {
        final convo = ParentAIConversation.fromJson(json);
        if (convo.childId == childId) conversations.add(convo);
      } catch (_) {
        // Skip corrupted entries.
      }
    }
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  @override
  Future<ParentAIConversation?> getConversation(String conversationId) async {
    final json = await _store.getJson(
      EncryptedDeviceStore.parentConversationsBox,
      conversationId,
    );
    if (json == null) return null;
    try {
      return ParentAIConversation.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveConversation(ParentAIConversation conversation) async {
    await _store.putJson(
      EncryptedDeviceStore.parentConversationsBox,
      conversation.id,
      conversation.toJson(),
    );
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _store.delete(
      EncryptedDeviceStore.parentConversationsBox,
      conversationId,
    );
  }

  @override
  Future<void> deleteAllConversations(String childId) async {
    final conversations = await _allConversations();
    for (final c in conversations.where((c) => c.childId == childId)) {
      await deleteConversation(c.id);
    }
  }

  @override
  Future<void> clearAll() async {
    await _store.clearBox(EncryptedDeviceStore.parentConversationsBox);
  }

  Future<List<ParentAIConversation>> _allConversations() async {
    final jsons = await _store.getAllJson(
      EncryptedDeviceStore.parentConversationsBox,
    );
    final conversations = <ParentAIConversation>[];
    for (final json in jsons) {
      try {
        conversations.add(ParentAIConversation.fromJson(json));
      } catch (_) {
        // Skip corrupted entries.
      }
    }
    return conversations;
  }
}