import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking.dart';
import '../models/ride.dart';
import '../services/booking_notification_service.dart';
import 'in_app_notification_provider.dart';
import 'service_providers.dart';

class DriverRidesState {
  final List<Ride> rides;
  final List<Booking> bookings;
  final bool loading;
  final String? errorMessage;

  const DriverRidesState({
    this.rides = const [],
    this.bookings = const [],
    this.loading = true,
    this.errorMessage,
  });

  DriverRidesState copyWith({
    List<Ride>? rides,
    List<Booking>? bookings,
    bool? loading,
    String? errorMessage,
  }) {
    return DriverRidesState(
      rides: rides ?? this.rides,
      bookings: bookings ?? this.bookings,
      loading: loading ?? this.loading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class DriverRidesNotifier extends StateNotifier<DriverRidesState> {
  DriverRidesNotifier(this._ref) : super(const DriverRidesState()) {
    BookingNotificationService.instance.setInAppNotifyCallback((notif) {
      _ref.read(inAppNotificationProvider.notifier).add(
            title: notif.title,
            body: notif.body,
            bookingId: notif.bookingId,
            rideId: notif.rideId,
            notifId: notif.id.hashCode,
          );
    });
    load();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  final Ref _ref;
  Timer? _pollTimer;

  static const _pollInterval = Duration(seconds: 5);

  bool _loading = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      await _fetch().timeout(const Duration(seconds: 15));
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: e.toString(),
      );
    } finally {
      _loading = false;
    }
  }

  Future<void> _poll() async {
    if (_loading) return;
    _loading = true;
    try {
      await _fetch();
    } catch (e) {
      // ignore: avoid_print
      print('DriverRidesNotifier._poll error silenciado: $e');
    } finally {
      _loading = false;
    }
  }

  Future<void> _fetch() async {
    final rideService = _ref.read(rideServiceProvider);
    final bookingService = _ref.read(bookingServiceProvider);
    final results = await Future.wait([
      rideService.getMyRides(),
      bookingService.getBookingsForMyRides(),
    ]);
    if (!mounted) return;
    state = state.copyWith(
      rides: results[0] as List<Ride>,
      bookings: results[1] as List<Booking>,
      loading: false,
      errorMessage: null,
    );
    await BookingNotificationService.instance
        .syncDriverBookings(results[1] as List<Booking>);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<void> cancelRide(String rideId, {required String reason}) async {
    final rideService = _ref.read(rideServiceProvider);
    await rideService.cancelRide(rideId, reason: reason);
    await load();
  }

  Future<void> acceptBooking(String bookingId) async {
    final bookingService = _ref.read(bookingServiceProvider);
    await bookingService.driverAcceptBooking(bookingId);
    await load();
  }

  Future<void> rejectBooking(String bookingId, {String? reason}) async {
    final bookingService = _ref.read(bookingServiceProvider);
    await bookingService.driverRejectBooking(bookingId, reason: reason);
    await load();
  }

  Future<void> markArriving(String bookingId) async {
    final bookingService = _ref.read(bookingServiceProvider);
    await bookingService.driverMarkArriving(bookingId);
    await load();
  }

  Future<void> markArrived(String bookingId) async {
    final bookingService = _ref.read(bookingServiceProvider);
    await bookingService.driverMarkArrived(bookingId);
    await load();
  }

  Future<void> startTrip(String bookingId) async {
    final bookingService = _ref.read(bookingServiceProvider);
    await bookingService.driverStartTrip(bookingId);
    await load();
  }

  Future<void> completeTrip(String bookingId) async {
    final bookingService = _ref.read(bookingServiceProvider);
    await bookingService.driverCompleteTrip(bookingId);
    await load();
  }

  Future<void> completeRide(String rideId) async {
    final bookingService = _ref.read(bookingServiceProvider);
    await bookingService.driverCompleteRide(rideId);
    await load();
  }
}

final driverRidesProvider =
    StateNotifierProvider<DriverRidesNotifier, DriverRidesState>(
  (ref) => DriverRidesNotifier(ref),
);
