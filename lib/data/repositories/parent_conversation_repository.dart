import '../models/approved_report_model.dart';

abstract class ParentConversationRepository {
  Future<List<ParentAIConversation>> getConversations(String childId);
  Future<ParentAIConversation?> getConversation(String conversationId);
  Future<void> saveConversation(ParentAIConversation conversation);
  Future<void> deleteConversation(String conversationId);
  Future<void> deleteAllConversations(String childId);
  Future<void> clearAll();
}

/// InMemoryParentConversationRepository stores parent AI chats exclusively
/// on the local parent device with zero cloud sync.
class InMemoryParentConversationRepository
    implements ParentConversationRepository {
  final Map<String, ParentAIConversation> _conversations = {};

  InMemoryParentConversationRepository() {
    _seedDefaultConversation();
  }

  void _seedDefaultConversation() {
    final now = DateTime.now();
    final sampleConvo = ParentAIConversation(
      id: 'convo-alex-welcome',
      childId: 'child-1',
      title: 'Weekly Balance Discussion',
      selectedReportIds: ['rep-alex-weekly-current'],
      messages: [
        ParentChatMessage(
          id: 'm1',
          text:
              'Hello! I am your On-Device Parenting Assistant. I analyze approved wellbeing summaries entirely offline on this device to provide objective habit insights.',
          isUser: false,
          timestamp: now.subtract(const Duration(minutes: 10)),
        ),
      ],
      createdAt: now.subtract(const Duration(minutes: 10)),
      updatedAt: now.subtract(const Duration(minutes: 10)),
    );
    _conversations[sampleConvo.id] = sampleConvo;
  }

  @override
  Future<List<ParentAIConversation>> getConversations(String childId) async {
    return _conversations.values.where((c) => c.childId == childId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<ParentAIConversation?> getConversation(String conversationId) async {
    return _conversations[conversationId];
  }

  @override
  Future<void> saveConversation(ParentAIConversation conversation) async {
    _conversations[conversation.id] = conversation;
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    _conversations.remove(conversationId);
  }

  @override
  Future<void> deleteAllConversations(String childId) async {
    _conversations.removeWhere((_, c) => c.childId == childId);
  }

  @override
  Future<void> clearAll() async {
    _conversations.clear();
  }
}
