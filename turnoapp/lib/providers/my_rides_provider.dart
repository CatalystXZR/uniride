import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking.dart';
import '../services/booking_notification_service.dart';
import 'in_app_notification_provider.dart';
import 'service_providers.dart';

class MyRidesState {
  final List<Booking> bookings;
  final bool loading;

  const MyRidesState({this.bookings = const [], this.loading = true});

  MyRidesState copyWith({List<Booking>? bookings, bool? loading}) {
    return MyRidesState(
      bookings: bookings ?? this.bookings,
      loading: loading ?? this.loading,
    );
  }
}

class MyRidesNotifier extends StateNotifier<MyRidesState> {
  MyRidesNotifier(this._ref) : super(const MyRidesState()) {
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
    state = state.copyWith(loading: true);
    try {
      final service = _ref.read(bookingServiceProvider);
      final rows = await service.getMyBookings();
      await BookingNotificationService.instance.syncPassengerBookings(rows);
      if (!mounted) return;
      state = state.copyWith(bookings: rows, loading: false);
    } finally {
      _loading = false;
    }
  }

  Future<void> _poll() async {
    if (_loading) return;
    _loading = true;
    try {
      final service = _ref.read(bookingServiceProvider);
      final rows = await service.getMyBookings();
      await BookingNotificationService.instance.syncPassengerBookings(rows);
      if (!mounted) return;
      state = state.copyWith(bookings: rows, loading: false);
    } catch (_) {
      // silent on poll errors
      if (!mounted) return;
      state = state.copyWith(loading: false);
    } finally {
      _loading = false;
    }
  }

  Future<void> confirmBoarding(String bookingId) async {
    final service = _ref.read(bookingServiceProvider);
    await service.confirmBoarding(bookingId);
    await load();
  }

  Future<void> driverAcceptBooking(String bookingId) async {
    final service = _ref.read(bookingServiceProvider);
    await service.driverAcceptBooking(bookingId);
    await load();
  }

  Future<void> driverMarkArriving(String bookingId) async {
    final service = _ref.read(bookingServiceProvider);
    await service.driverMarkArriving(bookingId);
    await load();
  }

  Future<void> driverMarkArrived(String bookingId) async {
    final service = _ref.read(bookingServiceProvider);
    await service.driverMarkArrived(bookingId);
    await load();
  }

  Future<void> driverStartTrip(String bookingId) async {
    final service = _ref.read(bookingServiceProvider);
    await service.driverStartTrip(bookingId);
    await load();
  }

  Future<void> driverCompleteTrip(String bookingId) async {
    final service = _ref.read(bookingServiceProvider);
    await service.driverCompleteTrip(bookingId);
    await load();
  }

  Future<void> cancelBooking(String bookingId) async {
    final service = _ref.read(bookingServiceProvider);
    await service.cancelBooking(bookingId);
    await load();
  }

  Future<void> reportNoShow(String bookingId, {String? notes}) async {
    final service = _ref.read(bookingServiceProvider);
    await service.reportDriverNoShow(bookingId, notes: notes);
    await load();
  }
}

final myRidesProvider = StateNotifierProvider<MyRidesNotifier, MyRidesState>(
  (ref) => MyRidesNotifier(ref),
);
