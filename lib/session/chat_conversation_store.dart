import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/classroom/chat_aula_messages.dart';
import '../sim/classroom/classroom_text_scale.dart';

class ChatConversationSnapshot {
  const ChatConversationSnapshot({
    required this.messages,
    required this.archiveSeq,
  });

  final List<ChatLessonMessage> messages;
  final int archiveSeq;
}

class ChatConversationStore {
  const ChatConversationStore([this._prefs]);

  static const _conversationSnapshotPrefix = 'sim.chat_aula.conversation.v1.';

  final SharedPreferences? _prefs;

  Future<SharedPreferences> _resolvedPrefs() async =>
      _prefs ?? SharedPreferences.getInstance();

  Future<int> loadFontScaleLevel() async {
    final prefs = await _resolvedPrefs();
    return ClassroomTextScale.normalize(
      prefs.getInt(ClassroomTextScale.prefsKey) ??
          ClassroomTextScale.defaultLevel,
    );
  }

  Future<void> saveFontScaleLevel(int level) async {
    final prefs = await _resolvedPrefs();
    await prefs.setInt(ClassroomTextScale.prefsKey, level);
  }

  Future<ChatConversationSnapshot?> restore(String lessonKey) async {
    final prefs = await _resolvedPrefs();
    final raw = prefs.getString(_snapshotKey(lessonKey));
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final messagesRaw = decoded['messages'];
    if (messagesRaw is! List) return null;
    final messages = messagesRaw
        .map(ChatLessonMessage.fromJson)
        .nonNulls
        .toList(growable: false);
    if (messages.isEmpty) return null;
    final archiveSeq = decoded['archiveSeq'];
    return ChatConversationSnapshot(
      messages: messages,
      archiveSeq: archiveSeq is int ? archiveSeq : messages.length,
    );
  }

  Future<void> persist({
    required String lessonKey,
    required int archiveSeq,
    required List<ChatLessonMessage> messages,
  }) async {
    final prefs = await _resolvedPrefs();
    await prefs.setString(
      _snapshotKey(lessonKey),
      jsonEncode({
        'version': 1,
        'lessonKey': lessonKey,
        'archiveSeq': archiveSeq,
        'messages': messages
            .map((message) => message.toJson(includeInlineImageData: false))
            .toList(),
      }),
    );
  }

  String _snapshotKey(String lessonKey) {
    final encoded = base64Url.encode(utf8.encode(lessonKey));
    return '$_conversationSnapshotPrefix$encoded';
  }
}
