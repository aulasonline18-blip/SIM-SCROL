import '../state/student_learning_state.dart';
import 'amparo_room_engine.dart';
import 'aux_room_models.dart';
import 'student_aux_room_service.dart';
import 'student_aux_rooms.dart';

class AmparoRoomService {
  const AmparoRoomService(
    this.service, {
    this.planEngine = const AmparoPlanEngine(),
  });

  final StudentAuxRoomService service;
  final AmparoPlanEngine planEngine;

  bool shouldStartAmparoRoom(String lessonLocalId) {
    if (service.shouldLessonBlockFinalCompletion(lessonLocalId)) return false;
    final state = service.readState(lessonLocalId);
    final amparo = ensureAuxRooms(state)['amparo'] as Map;
    return amparo['pending'] == true &&
        ((amparo['completedCycles'] as num?)?.toInt() ?? 0) <=
            AmparoGate.maxCycles;
  }

  Future<AmparoRoomView> startAmparoRoom(AmparoRoomContext context) async {
    if (!shouldStartAmparoRoom(context.lessonLocalId)) {
      return const AmparoRoomView(
        status: AmparoRoomStatus.done,
        stations: [],
        idx: 0,
        amparoLvl: 0,
      );
    }
    final state = service.readState(context.lessonLocalId);
    final amparo = ensureAuxRooms(state)['amparo'] as Map;
    final level = ((amparo['amparoLvl'] as num?)?.toInt() ?? 1).clamp(
      1,
      AmparoGate.maxCycles,
    );
    final stations = planEngine.buildStations();
    service.registerAmparoStarted(context.lessonLocalId, stations, level);
    return _prepare(context: context, stations: stations, idx: 0, level: level);
  }

  Future<AmparoRoomView> _prepare({
    required AmparoRoomContext context,
    required List<AmparoStation> stations,
    required int idx,
    required int level,
  }) async {
    if (idx >= stations.length) {
      service.registerAmparoCompleted(context.lessonLocalId);
      return AmparoRoomView(
        status: AmparoRoomStatus.done,
        stations: stations,
        idx: idx,
        amparoLvl: level,
      );
    }
    final prepared = await service.prepareAmparoRoomStep(
      context: context,
      station: stations[idx],
      amparoLevel: level,
    );
    if (!prepared.ok) {
      return AmparoRoomView(
        status: AmparoRoomStatus.failed,
        stations: stations,
        idx: idx,
        amparoLvl: level,
        errMsg: prepared.error,
      );
    }
    return AmparoRoomView(
      status: AmparoRoomStatus.ready,
      stations: stations,
      idx: idx,
      amparoLvl: level,
      conteudo: prepared.conteudo,
    );
  }

  AmparoRoomView selectLetter(AmparoRoomView view, AnswerLetter letra) {
    return view.copyWith(status: AmparoRoomStatus.answering, letra: letra);
  }

  AmparoRoomView answerAmparoRoom(
    AmparoRoomContext context,
    AmparoRoomView view,
    DecisionSignal sinal,
  ) {
    final conteudo = view.conteudo;
    final letra = view.letra;
    final marker = context.marker;
    if (conteudo == null || letra == null || marker == null) {
      return view.copyWith(
        status: AmparoRoomStatus.failed,
        errMsg: 'amparo answer missing data',
      );
    }
    service.recordAuxRoomAnswer(
      lessonLocalId: context.lessonLocalId,
      marker: marker,
      layer: context.layer,
      items: context.items,
      conteudo: conteudo,
      letra: letra,
      sinal: sinal,
      source: 'amparo:${view.idx}',
    );
    return view.copyWith(
      status: AmparoRoomStatus.result,
      sinal: sinal,
      resultCorrect: letra == conteudo.correctAnswer,
      resultMsg: letra == conteudo.correctAnswer
          ? 'Caminho retomado.'
          : 'Vamos manter o amparo curto e seguir para o próximo passo.',
    );
  }

  Future<AmparoRoomView> nextAmparoRoom(
    AmparoRoomContext context,
    AmparoRoomView view,
  ) {
    return _prepare(
      context: context,
      stations: view.stations,
      idx: view.idx + 1,
      level: view.amparoLvl,
    );
  }

  AmparoRoomView finishAmparoRoom(String lessonLocalId, AmparoRoomView view) {
    service.registerAmparoCompleted(lessonLocalId);
    return view.copyWith(status: AmparoRoomStatus.done);
  }
}
