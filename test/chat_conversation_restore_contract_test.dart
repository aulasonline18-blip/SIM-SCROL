import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/session/chat_conversation_store.dart';

void main() {
  test('snapshot de conversa invalido nao finge restore com sucesso', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = ChatConversationStore(prefs);
    await store.persist(
      lessonKey: 'lesson-chat',
      archiveSeq: 1,
      messages: const [
        ChatLessonMessage(
          id: 'm1',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.explanation,
          text: 'hello',
        ),
      ],
    );
    final key = prefs.getKeys().singleWhere(
      (key) => key.startsWith('sim.chat_aula.conversation.v1.'),
    );
    await prefs.setString(key, '{bad-json');

    final result = await store.restoreWithAudit('lesson-chat');

    expect(result.status, ChatConversationRestoreStatus.corrupted);
    expect(result.canMarkRestored, isFalse);
    expect(result.snapshot, isNull);
  });

  test('snapshot de conversa com lessonKey incompativel e rejeitado', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = ChatConversationStore(prefs);
    await store.persist(
      lessonKey: 'lesson-a',
      archiveSeq: 1,
      messages: const [
        ChatLessonMessage(
          id: 'm1',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.explanation,
          text: 'hello',
        ),
      ],
    );
    final key = prefs.getKeys().singleWhere(
      (key) => key.startsWith('sim.chat_aula.conversation.v1.'),
    );
    final decoded = jsonDecode(prefs.getString(key)!) as Map;
    await prefs.setString(
      key,
      jsonEncode({...decoded, 'lessonKey': 'lesson-b'}),
    );

    final result = await store.restoreWithAudit('lesson-a');

    expect(result.status, ChatConversationRestoreStatus.incompatible);
    expect(result.canMarkRestored, isFalse);
    expect(result.snapshot, isNull);
  });
}
