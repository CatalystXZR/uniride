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

import '../core/supabase_client.dart';
import '../models/ride.dart';

class RideService {
  final _client = SupabaseConfig.client;

  Future<Ride> createRide(Ride ride) async {
    final data = await _client
        .from('rides')
        .insert(ride.toInsertJson())
        .select()
        .single();
    return Ride.fromJson(data);
  }

  /// Search rides with optional filters.
  Future<List<Ride>> searchRides({
    String? campusId,
    String? originCommune,
    String? direction, // 'to_campus' | 'from_campus'
    DateTime? date,
  }) async {
    var query = _client
        .from('rides')
        .select('''
          *,
          users_profile!driver_id(full_name),
          campuses!campus_id(name),
          universities!university_id(name)
        ''')
        .eq('status', 'active')
        .gt('seats_available', 0);

    if (campusId != null) query = query.eq('campus_id', campusId);
    if (originCommune != null) query = query.eq('origin_commune', originCommune);
    if (direction != null) query = query.eq('direction', direction);

    if (date != null) {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      query = query
          .gte('departure_at', start.toIso8601String())
          .lt('departure_at', end.toIso8601String());
    }

    final rows = await query.order('departure_at');

    return rows.map((row) {
      // flatten joined fields
      final flat = Map<String, dynamic>.from(row);
      flat['driver_name'] =
          (row['users_profile'] as Map?)?['full_name'];
      flat['campus_name'] = (row['campuses'] as Map?)?['name'];
      flat['university_name'] = (row['universities'] as Map?)?['name'];
      return Ride.fromJson(flat);
    }).toList();
  }

  Future<Ride?> getRideById(String rideId) async {
    final data = await _client
        .from('rides')
        .select()
        .eq('id', rideId)
        .maybeSingle();
    if (data == null) return null;
    return Ride.fromJson(data);
  }

  /// Returns all rides published by the current driver.
  Future<List<Ride>> getMyRides() async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('rides')
        .select()
        .eq('driver_id', uid)
        .order('departure_at', ascending: false);
    return rows.map(Ride.fromJson).toList();
  }
}
