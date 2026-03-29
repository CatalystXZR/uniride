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

class Booking {
  final String id;
  final String rideId;
  final String passengerId;
  final String? passengerName;
  final double? passengerRating;
  final String? passengerPhotoUrl;
  final String? passengerVehiclePlate;
  final String? passengerVehicleModel;
  final int amountTotal;
  final BookingStatus status;
  final DateTime? confirmedAt;
  final DateTime? reportedNoShowAt;
  final String? noShowNotes;
  final DateTime createdAt;

  // Optional joined fields
  final String? rideOriginCommune;
  final DateTime? rideDepartureAt;
  final String? universityName;
  final String? campusName;

  const Booking({
    required this.id,
    required this.rideId,
    required this.passengerId,
    this.passengerName,
    this.passengerRating,
    this.passengerPhotoUrl,
    this.passengerVehiclePlate,
    this.passengerVehicleModel,
    required this.amountTotal,
    required this.status,
    this.confirmedAt,
    this.reportedNoShowAt,
    this.noShowNotes,
    required this.createdAt,
    this.rideOriginCommune,
    this.rideDepartureAt,
    this.universityName,
    this.campusName,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    BookingStatus parseStatus(String s) {
      switch (s) {
        case 'cancelled':
          return BookingStatus.cancelled;
        case 'completed':
          return BookingStatus.completed;
        case 'no_show':
          return BookingStatus.noShow;
        default:
          return BookingStatus.reserved;
      }
    }

    return Booking(
      id: json['id'] as String,
      rideId: json['ride_id'] as String,
      passengerId: json['passenger_id'] as String,
      passengerName: json['passenger_name'] as String?,
      passengerRating: (json['passenger_rating'] as num?)?.toDouble(),
      passengerPhotoUrl: json['passenger_photo_url'] as String?,
      passengerVehiclePlate: json['passenger_vehicle_plate'] as String?,
      passengerVehicleModel: json['passenger_vehicle_model'] as String?,
      amountTotal: (json['amount_total'] as int?) ?? 2000,
      status: parseStatus((json['status'] as String?) ?? 'reserved'),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'] as String)
          : null,
      reportedNoShowAt: json['reported_no_show_at'] != null
          ? DateTime.parse(json['reported_no_show_at'] as String)
          : null,
      noShowNotes: json['no_show_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      rideOriginCommune: json['ride_origin_commune'] as String?,
      rideDepartureAt: json['ride_departure_at'] != null
          ? DateTime.parse(json['ride_departure_at'] as String)
          : null,
      universityName: json['university_name'] as String?,
      campusName: json['campus_name'] as String?,
    );
  }

  bool get isReserved => status == BookingStatus.reserved;
  bool get isCompleted => status == BookingStatus.completed;
}
