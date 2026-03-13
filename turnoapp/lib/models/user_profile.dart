/**
 *
 * Project: TurnoApp
 *
 * Original Concept: Agustín Puelma, Cristobal Cordova, Carlos Ibarra
 *
 * Software Architecture & Code: Matías Toledo (catalystxzr)
 *
 * Description: Production-grade implementation for UDD carpooling system.
 *
 * Copyright (c) 2026. All rights reserved.
 *
 */

import 'enums.dart';

class UserProfile {
  final String id;
  final String? fullName;
  final String? universityId;
  final String? campusId;
  final RoleMode roleMode;
  final bool isDriverVerified;
  final int strikesCount;
  final DateTime? suspendedUntil;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    this.fullName,
    this.universityId,
    this.campusId,
    required this.roleMode,
    required this.isDriverVerified,
    required this.strikesCount,
    this.suspendedUntil,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      universityId: json['university_id'] as String?,
      campusId: json['campus_id'] as String?,
      roleMode: json['role_mode'] == 'driver'
          ? RoleMode.driver
          : RoleMode.passenger,
      isDriverVerified: (json['is_driver_verified'] as bool?) ?? false,
      strikesCount: (json['strikes_count'] as int?) ?? 0,
      suspendedUntil: json['suspended_until'] != null
          ? DateTime.parse(json['suspended_until'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'university_id': universityId,
        'campus_id': campusId,
        'role_mode': roleMode == RoleMode.driver ? 'driver' : 'passenger',
        'is_driver_verified': isDriverVerified,
        'strikes_count': strikesCount,
        'suspended_until': suspendedUntil?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  UserProfile copyWith({
    String? fullName,
    String? universityId,
    String? campusId,
    RoleMode? roleMode,
    bool? isDriverVerified,
    int? strikesCount,
    DateTime? suspendedUntil,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      universityId: universityId ?? this.universityId,
      campusId: campusId ?? this.campusId,
      roleMode: roleMode ?? this.roleMode,
      isDriverVerified: isDriverVerified ?? this.isDriverVerified,
      strikesCount: strikesCount ?? this.strikesCount,
      suspendedUntil: suspendedUntil ?? this.suspendedUntil,
      createdAt: createdAt,
    );
  }
}
