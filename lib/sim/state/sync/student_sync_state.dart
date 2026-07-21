part of '../student_learning_state.dart';

enum SyncStatus { clean, dirty, syncing, synced, conflict, failed }

class StudentSyncStatus {
  const StudentSyncStatus({
    required this.status,
    required this.pendingJobs,
    required this.highWaterMark,
    required this.updatedAt,
    this.lastSyncedAt,
    this.lastError,
  });

  final String status;
  final int pendingJobs;
  final int highWaterMark;
  final int updatedAt;
  final int? lastSyncedAt;
  final String? lastError;

  factory StudentSyncStatus.empty([int now = 0]) => StudentSyncStatus(
    status: 'idle',
    pendingJobs: 0,
    highWaterMark: 0,
    updatedAt: now,
  );

  JsonMap toJson() => {
    'status': status,
    'pending_jobs': pendingJobs,
    'high_water_mark': highWaterMark,
    'updated_at': updatedAt,
    if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
    if (lastError != null) 'last_error': lastError,
  };

  factory StudentSyncStatus.fromJson(JsonMap json) => StudentSyncStatus(
    status: (json['status'] ?? 'idle').toString(),
    pendingJobs: (json['pending_jobs'] as num?)?.toInt() ?? 0,
    highWaterMark: (json['high_water_mark'] as num?)?.toInt() ?? 0,
    updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
    lastSyncedAt: (json['last_synced_at'] as num?)?.toInt(),
    lastError: json['last_error'] as String?,
  );

  StudentSyncStatus copyWith({
    String? status,
    int? pendingJobs,
    int? highWaterMark,
    int? updatedAt,
    int? lastSyncedAt,
    String? lastError,
  }) {
    return StudentSyncStatus(
      status: status ?? this.status,
      pendingJobs: pendingJobs ?? this.pendingJobs,
      highWaterMark: highWaterMark ?? this.highWaterMark,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: lastError ?? this.lastError,
    );
  }
}

class StudentSyncState {
  const StudentSyncState({
    required this.status,
    required this.pendingJobs,
    required this.highWaterMark,
    required this.updatedAt,
    this.lastSyncedAt,
    this.lastError,
  });

  final String status;
  final int pendingJobs;
  final int highWaterMark;
  final int updatedAt;
  final int? lastSyncedAt;
  final String? lastError;

  factory StudentSyncState.fromStatus(StudentSyncStatus? status) {
    final value = status ?? StudentSyncStatus.empty();
    return StudentSyncState(
      status: value.status,
      pendingJobs: value.pendingJobs,
      highWaterMark: value.highWaterMark,
      updatedAt: value.updatedAt,
      lastSyncedAt: value.lastSyncedAt,
      lastError: value.lastError,
    );
  }

  JsonMap toJson() => {
    'status': status,
    'pending_jobs': pendingJobs,
    'high_water_mark': highWaterMark,
    'updated_at': updatedAt,
    if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
    if (lastError != null) 'last_error': lastError,
  };
}
