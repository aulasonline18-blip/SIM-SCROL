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

enum ChatConversationRestoreStatus {
  restored,
  missing,
  corrupted,
  incompatible,
}

class ChatConversationRestoreResult {
  const ChatConversationRestoreResult({
    required this.status,
    this.snapshot,
    this.code,
  });

  final ChatConversationRestoreStatus status;
  final ChatConversationSnapshot? snapshot;
  final String? code;

  bool get canMarkRestored =>
      status == ChatConversationRestoreStatus.restored ||
      status == ChatConversationRestoreStatus.missing;
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
    return (await restoreWithAudit(lessonKey)).snapshot;
  }

  Future<ChatConversationRestoreResult> restoreWithAudit(
    String lessonKey,
  ) async {
    final prefs = await _resolvedPrefs();
    final raw = prefs.getString(_snapshotKey(lessonKey));
    if (raw == null || raw.trim().isEmpty) {
      return const ChatConversationRestoreResult(
        status: ChatConversationRestoreStatus.missing,
        code: 'CHAT_CONVERSATION_MISSING',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const ChatConversationRestoreResult(
        status: ChatConversationRestoreStatus.corrupted,
        code: 'CHAT_CONVERSATION_CORRUPTED_JSON',
      );
    }
    if (decoded is! Map) {
      return const ChatConversationRestoreResult(
        status: ChatConversationRestoreStatus.corrupted,
        code: 'CHAT_CONVERSATION_CORRUPTED_SHAPE',
      );
    }
    if (decoded['version'] != 1 || decoded['lessonKey'] != lessonKey) {
      return const ChatConversationRestoreResult(
        status: ChatConversationRestoreStatus.incompatible,
        code: 'CHAT_CONVERSATION_INCOMPATIBLE_IDENTITY',
      );
    }
    final messagesRaw = decoded['messages'];
    if (messagesRaw is! List) {
      return const ChatConversationRestoreResult(
        status: ChatConversationRestoreStatus.corrupted,
        code: 'CHAT_CONVERSATION_CORRUPTED_MESSAGES',
      );
    }
    final messages = messagesRaw
        .map(ChatLessonMessage.fromJson)
        .nonNulls
        .toList(growable: false);
    if (messages.isEmpty) {
      return const ChatConversationRestoreResult(
        status: ChatConversationRestoreStatus.corrupted,
        code: 'CHAT_CONVERSATION_EMPTY_AFTER_DECODE',
      );
    }
    final archiveSeq = decoded['archiveSeq'];
    return ChatConversationRestoreResult(
      status: ChatConversationRestoreStatus.restored,
      snapshot: ChatConversationSnapshot(
        messages: messages,
        archiveSeq: archiveSeq is int ? archiveSeq : messages.length,
      ),
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
