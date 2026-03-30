import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking.dart';
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
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true);
    final service = _ref.read(bookingServiceProvider);
    final rows = await service.getMyBookings();
    state = state.copyWith(bookings: rows, loading: false);
  }

  Future<void> confirmBoarding(String bookingId) async {
    final service = _ref.read(bookingServiceProvider);
    await service.confirmBoarding(bookingId);
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
