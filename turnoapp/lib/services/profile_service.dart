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

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../models/user_profile.dart';
import '../models/enums.dart';

class ProfileService {
  final _client = SupabaseConfig.client;

  Future<UserProfile?> getProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final data = await _client
        .from('users_profile')
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  /// Upserts the profile. Used after sign-up to set name, university, campus.
  Future<UserProfile> upsertProfile(UserProfile profile) async {
    final data = await _client
        .from('users_profile')
        .upsert(profile.toJson())
        .select()
        .single();
    return UserProfile.fromJson(data);
  }

  Future<UserProfile> setRoleMode(RoleMode mode) async {
    final uid = _client.auth.currentUser!.id;
    final data = await _client
        .from('users_profile')
        .update({
          'role_mode': mode == RoleMode.driver ? 'driver' : 'passenger',
        })
        .eq('id', uid)
        .select()
        .single();
    return UserProfile.fromJson(data);
  }
}
