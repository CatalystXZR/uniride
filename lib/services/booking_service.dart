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
import '../models/booking.dart';

class BookingService {
  final _client = SupabaseConfig.client;

  /// Calls the `create_booking` Postgres RPC.
  /// Atomically deducts saldo, holds funds, decrements seats.
  Future<String> createBooking(String rideId) async {
    final result = await _client.rpc('create_booking', params: {
      'p_ride_id': rideId,
    });
    return result as String;
  }

  /// Calls the `confirm_boarding` Postgres RPC.
  /// Releases held funds to the driver.
  Future<void> confirmBoarding(String bookingId) async {
    await _client.rpc('confirm_boarding', params: {
      'p_booking_id': bookingId,
    });
  }

  /// Calls the `cancel_booking` Postgres RPC.
  /// Refunds held funds to the passenger and increments available seats.
  Future<void> cancelBooking(String bookingId) async {
    await _client.rpc('cancel_booking', params: {
      'p_booking_id': bookingId,
    });
  }

  /// Returns all bookings for the current passenger.
  Future<List<Booking>> getMyBookings() async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('bookings')
        .select('''
          *,
          rides!ride_id(
            origin_commune,
            departure_at,
            universities!university_id(name),
            campuses!campus_id(name)
          )
        ''')
        .eq('passenger_id', uid)
        .order('created_at', ascending: false);

    return rows.map((row) {
      final flat = Map<String, dynamic>.from(row);
      final ride = row['rides'] as Map?;
      flat['ride_origin_commune'] = ride?['origin_commune'];
      flat['ride_departure_at'] = ride?['departure_at'];
      flat['university_name'] =
          (ride?['universities'] as Map?)?['name'];
      flat['campus_name'] = (ride?['campuses'] as Map?)?['name'];
      return Booking.fromJson(flat);
    }).toList();
  }

  /// Returns bookings on rides driven by the current user.
  /// Fetches the driver's ride IDs first, then queries bookings for those rides.
  Future<List<Booking>> getBookingsForMyRides() async {
    final uid = _client.auth.currentUser!.id;

    // Step 1: get all ride IDs owned by this driver
    final rideRows = await _client
        .from('rides')
        .select('id')
        .eq('driver_id', uid);

    if (rideRows.isEmpty) return [];

    final rideIds = rideRows.map((r) => r['id'] as String).toList();

    // Step 2: fetch bookings for those rides
    final rows = await _client
        .from('bookings')
        .select('''
          *,
          rides!ride_id(origin_commune, departure_at,
            universities!university_id(name),
            campuses!campus_id(name)
          )
        ''')
        .inFilter('ride_id', rideIds)
        .order('created_at', ascending: false);

    return rows.map((row) {
      final flat = Map<String, dynamic>.from(row);
      final ride = row['rides'] as Map?;
      flat['ride_origin_commune'] = ride?['origin_commune'];
      flat['ride_departure_at']   = ride?['departure_at'];
      flat['university_name']     = (ride?['universities'] as Map?)?['name'];
      flat['campus_name']         = (ride?['campuses'] as Map?)?['name'];
      return Booking.fromJson(flat);
    }).toList();
  }
}
