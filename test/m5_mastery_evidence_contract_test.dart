import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  group('M5 server mastery evidence contract', () {
    test('App entende MasteryEvidence e WeaknessRecord vindos do servidor', () {
      final state = StudentLearningState.fromJson({
        'lessonLocalId': 'lesson-m5',
        'truth_typed': {
          'mastery_evidence': [
            {
              'marker': 'M1',
              'itemIdx': 0,
              'recognitionPassed': true,
              'understandingPassed': true,
              'applicationPassed': true,
              'retentionPassed': false,
              'integratedPassed': false,
              'confidencePattern': [1, 1, 1],
              'errorCount': 0,
              'hesitationCount': 0,
              'masteryScore': 75,
              'status': 'provisional',
              'updatedAt': '2026-07-08T00:00:00.000Z',
              'evidenceEvents': ['a1', 'a2', 'a3'],
            },
          ],
          'weakness_records': [
            {
              'weaknessId': 'weak-M2',
              'marker': 'M2',
              'concept': 'fractions',
              'reason': 'low_confidence',
              'severity': 'medium',
              'active': true,
              'repairAttempts': 0,
              'lastSeenAt': '2026-07-08T00:00:00.000Z',
              'createdAt': '2026-07-08T00:00:00.000Z',
            },
          ],
          'conquest_records': [
            {
              'conquestId': 'conq-M3',
              'marker': 'M3',
              'itemIdx': 2,
              'conqueredAt': '2026-07-08T00:00:00.000Z',
              'evidenceSummary': 'all_required_evidence_passed',
              'version': 1,
            },
          ],
          'item_consolidation_status': {'M1': 'provisional', 'M3': 'conquered'},
        },
      });

      expect(state.truth.masteryEvidence.single['status'], 'provisional');
      expect(state.truth.weaknessRecords.single['reason'], 'low_confidence');
      expect(state.truth.conquestRecords.single['marker'], 'M3');
      expect(state.truth.itemConsolidationStatus['M3'], 'conquered');
    });

    test('App nao sobrescreve dominio remoto com verdade local antiga', () {
      final local = StudentLearningState.fromJson({
        'lessonLocalId': 'lesson-m5',
        'progress': {'itemIdx': 3, 'layer': 3, 'mainAdvances': 3},
        'truth_typed': {
          'mastery_evidence': [
            {'marker': 'M1', 'status': 'needs_review'},
          ],
          'item_consolidation_status': {'M1': 'needs_review'},
        },
      });
      final remote = StudentLearningState.fromJson({
        'lessonLocalId': 'lesson-m5',
        'progress': {'itemIdx': 2, 'layer': 3, 'mainAdvances': 2},
        'truth_typed': {
          'mastery_evidence': [
            {'marker': 'M1', 'status': 'conquered'},
          ],
          'weakness_records': [
            {
              'weaknessId': 'weak-M2',
              'marker': 'M2',
              'reason': 'false_mastery',
            },
          ],
          'conquest_records': [
            {'conquestId': 'conq-M1', 'marker': 'M1'},
          ],
          'item_consolidation_status': {'M1': 'conquered'},
        },
      });

      final merged = mergeStudentLearningStateFromCloud(local, remote);

      expect(merged.truth.itemConsolidationStatus['M1'], 'conquered');
      expect(merged.truth.masteryEvidence.single['status'], 'conquered');
      expect(merged.truth.weaknessRecords.single['marker'], 'M2');
      expect(merged.truth.conquestRecords.single['marker'], 'M1');
    });

    test(
      'App preserva cache local, mas nao declara conquista final contra servidor',
      () {
        final local = StudentLearningState.fromJson({
          'lessonLocalId': 'lesson-m5',
          'readyLessonMaterials': {
            'slot-local': {'question': 'Q'},
          },
          'truth_typed': {
            'mastery_evidence': [
              {'marker': 'M1', 'status': 'conquered'},
            ],
            'item_consolidation_status': {'M1': 'conquered'},
          },
        });
        final remote = StudentLearningState.fromJson({
          'lessonLocalId': 'lesson-m5',
          'truth_typed': {
            'mastery_evidence': [
              {'marker': 'M1', 'status': 'provisional'},
            ],
            'item_consolidation_status': {'M1': 'provisional'},
          },
        });

        final merged = mergeStudentLearningStateFromCloud(local, remote);

        expect(merged.readyLessonMaterials.containsKey('slot-local'), isTrue);
        expect(merged.truth.itemConsolidationStatus['M1'], 'provisional');
      },
    );
  });
}
