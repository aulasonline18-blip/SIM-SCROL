part of 'lab_session.dart';

extension LabSessionBackupFlowExtensions on LabSession {
  String buildDrawerBackupText() {
    final store = canonicalStore;
    if (store == null) {
      throw StateError('Backup indisponivel.');
    }
    final states = store.listLocalStates(includeDeleted: false);
    if (states.isEmpty) {
      throw StateError('Nenhuma aula para exportar.');
    }
    final snapshots = <String, dynamic>{};
    final lessons = <Map<String, dynamic>>[];
    for (final state in states) {
      snapshots[state.lessonLocalId] = state.toJson();
      lessons.add(_cyberLessonFromState(state));
    }
    final file = <String, dynamic>{
      'magic': 'SIM_CYBER_BACKUP_V1',
      'exportedAt': DateTime.now().millisecondsSinceEpoch,
      'lessons': lessons,
      'studentLearningStates': snapshots,
    };
    final encoded = base64.encode(utf8.encode(jsonEncode(file)));
    return [
      'SIM — BACKUP DE AULA',
      'SIM_CYBER_V1_BEGIN',
      encoded,
      'SIM_CYBER_V1_END',
    ].join('\n');
  }

  Future<File> writeDrawerBackupFile(String text) async {
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final fileName = 'sim-backup-$stamp.txt';
    final savedPath = await _saveTextFile(fileName: fileName, text: text);
    if (savedPath != null && savedPath.trim().isNotEmpty) {
      return File(savedPath);
    }
    final file = File('${Directory.systemTemp.path}/$fileName');
    return file.writeAsString(text);
  }

  Future<String?> pickDrawerBackupFileText() async {
    final injected = _drawerBackupFileTextPicker;
    if (injected != null) return injected();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'json'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return null;
    final bytes = file.bytes;
    if (bytes != null) return utf8.decode(bytes);
    final path = file.path;
    if (path == null || path.trim().isEmpty) return null;
    return File(path).readAsString();
  }

  String buildDrawerStatusText() {
    final id = lessonLocalId;
    final store = canonicalStore;
    if (id == null || store == null) {
      throw StateError('Curriculo nao encontrado.');
    }
    final state = store.readState(id);
    final progress = state.progress;
    final curriculum = state.curriculum;
    return [
      'SIM - STATUS PEDAGOGICO',
      'Objetivo: ${state.profile.objetivo ?? '-'}',
      'Topico: ${curriculum?.topic ?? '-'}',
      'Item: ${state.current?.marker ?? '-'}',
      'Camada: ${state.current?.layer.name ?? '-'}',
      'Progresso: ${progress?.concluidos.length ?? 0}/${curriculum?.totalItems ?? 0}',
      'Tentativas: ${state.attempts.length}',
    ].join('\n');
  }

  Future<File> writeDrawerStatusFile(String text) async {
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final fileName = 'sim-status-$stamp.txt';
    final savedPath = await _saveTextFile(fileName: fileName, text: text);
    if (savedPath != null && savedPath.trim().isNotEmpty) {
      return File(savedPath);
    }
    final file = File('${Directory.systemTemp.path}/$fileName');
    return file.writeAsString(text);
  }

  Future<String?> _saveTextFile({
    required String fileName,
    required String text,
  }) async {
    final injected = _drawerBackupFileSaver;
    if (injected != null) return injected(fileName, text);
    try {
      return await FilePicker.platform.saveFile(
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        bytes: Uint8List.fromList(utf8.encode(text)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<StudentLearningState> importDrawerBackup(String raw) async {
    final store = canonicalStore;
    if (store == null) {
      throw StateError('Backup indisponivel.');
    }
    final backup = store.parseBackupText(raw);
    final ids = _lessonIdsFromBackup(backup);
    final state = store.importBackup(backup);
    lessonLocalId = state.lessonLocalId;
    for (final id in ids.isEmpty ? <String>[state.lessonLocalId] : ids) {
      final imported = _readExistingLocalState(id);
      if (imported == null || _stateDeleted(imported)) continue;
      _enqueueLessonForRemoteVaultSync(id, reason: 'drawer_backup_imported');
    }
    if (authed) {
      final engine = _remoteVaultSync();
      if (engine != null) {
        await engine.drain();
      }
    }
    _notifyFromChild();
    return state;
  }
}
