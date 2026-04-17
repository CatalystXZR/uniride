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

  Future<void> driverAcceptBooking(String bookingId) async {
    await _client.rpc('driver_accept_booking', params: {
      'p_booking_id': bookingId,
    });
  }

  Future<void> driverRejectBooking(String bookingId, {String? reason}) async {
    await _client.rpc('driver_reject_booking', params: {
      'p_booking_id': bookingId,
      'p_reason': reason,
    });
  }

  Future<void> driverMarkArriving(String bookingId) async {
    await _client.rpc('driver_mark_arriving', params: {
      'p_booking_id': bookingId,
    });
  }

  Future<void> driverMarkArrived(String bookingId) async {
    await _client.rpc('driver_mark_arrived', params: {
      'p_booking_id': bookingId,
    });
  }

  Future<void> driverStartTrip(String bookingId) async {
    await _client.rpc('driver_start_trip', params: {
      'p_booking_id': bookingId,
    });
  }

  Future<void> driverCompleteTrip(String bookingId) async {
    await _client.rpc('driver_complete_trip', params: {
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

  Future<void> reportDriverNoShow(
    String bookingId, {
    String? notes,
  }) async {
    await _client.rpc('passenger_report_no_show', params: {
      'p_booking_id': bookingId,
      'p_notes': notes,
    });
  }

  /// Returns all bookings for the current passenger.
  Future<List<Booking>> getMyBookings({int limit = 80}) async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('bookings')
        .select('''
          *,
          rides!ride_id(
            driver_id,
            origin_commune,
            departure_at,
            universities!university_id(name),
            campuses!campus_id(name),
            users_profile!driver_id(
              full_name,
              rating_avg,
              profile_photo_url,
              vehicle_plate,
              vehicle_model,
              emergency_contact
            )
          ),
          users_profile!passenger_id(
            full_name,
            rating_avg,
            profile_photo_url,
            vehicle_plate,
            vehicle_model
          )
        ''')
        .eq('passenger_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows.map((row) {
      final flat = Map<String, dynamic>.from(row);
      final ride = row['rides'] as Map?;
      flat['ride_origin_commune'] = ride?['origin_commune'];
      flat['ride_departure_at'] = ride?['departure_at'];
      flat['driver_id'] = ride?['driver_id'];
      flat['university_name'] = (ride?['universities'] as Map?)?['name'];
      flat['campus_name'] = (ride?['campuses'] as Map?)?['name'];
      final passenger = row['users_profile'] as Map?;
      flat['passenger_name'] = passenger?['full_name'];
      flat['passenger_rating'] = passenger?['rating_avg'];
      flat['passenger_photo_url'] = passenger?['profile_photo_url'];
      flat['passenger_vehicle_plate'] = passenger?['vehicle_plate'];
      flat['passenger_vehicle_model'] = passenger?['vehicle_model'];
      final driver = (ride?['users_profile'] as Map?);
      flat['driver_name'] = driver?['full_name'];
      flat['driver_rating'] = driver?['rating_avg'];
      flat['driver_photo_url'] = driver?['profile_photo_url'];
      flat['driver_vehicle_plate'] = driver?['vehicle_plate'];
      flat['driver_vehicle_model'] = driver?['vehicle_model'];
      flat['driver_emergency_contact'] = driver?['emergency_contact'];
      return Booking.fromJson(flat);
    }).toList();
  }

  /// Returns bookings on rides driven by the current user.
  /// Fetches the driver's ride IDs first, then queries bookings for those rides.
  Future<List<Booking>> getBookingsForMyRides({int limit = 100}) async {
    final uid = _client.auth.currentUser!.id;

    // Step 1: get all ride IDs owned by this driver
    final rideRows =
        await _client.from('rides').select('id').eq('driver_id', uid);

    if (rideRows.isEmpty) return [];

    final rideIds = rideRows.map((r) => r['id'] as String).toList();

    // Step 2: fetch bookings for those rides
    final rows = await _client
        .from('bookings')
        .select('''
          *,
          rides!ride_id(origin_commune, departure_at,
            driver_id,
            universities!university_id(name),
            campuses!campus_id(name)
          ),
          users_profile!passenger_id(
            full_name,
            rating_avg,
            profile_photo_url,
            vehicle_plate,
            vehicle_model
          )
        ''')
        .inFilter('ride_id', rideIds)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows.map((row) {
      final flat = Map<String, dynamic>.from(row);
      final ride = row['rides'] as Map?;
      flat['ride_origin_commune'] = ride?['origin_commune'];
      flat['ride_departure_at'] = ride?['departure_at'];
      flat['driver_id'] = ride?['driver_id'];
      flat['university_name'] = (ride?['universities'] as Map?)?['name'];
      flat['campus_name'] = (ride?['campuses'] as Map?)?['name'];
      final passenger = row['users_profile'] as Map?;
      flat['passenger_name'] = passenger?['full_name'];
      flat['passenger_rating'] = passenger?['rating_avg'];
      flat['passenger_photo_url'] = passenger?['profile_photo_url'];
      flat['passenger_vehicle_plate'] = passenger?['vehicle_plate'];
      flat['passenger_vehicle_model'] = passenger?['vehicle_model'];
      return Booking.fromJson(flat);
    }).toList();
  }
}
