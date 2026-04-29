import '../models/booking.dart';
import '../models/enums.dart';
import 'notification_service.dart';

class BookingNotificationService {
  BookingNotificationService._();

  static final BookingNotificationService instance =
      BookingNotificationService._();

  final Map<String, String> _passengerSnapshot = {};
  final Map<String, String> _driverSnapshot = {};
  bool _passengerHydrated = false;
  bool _driverHydrated = false;

  void clearSnapshots() {
    _passengerSnapshot.clear();
    _driverSnapshot.clear();
    _passengerHydrated = false;
    _driverHydrated = false;
  }

  Future<void> syncPassengerBookings(List<Booking> bookings) async {
    final activeIds = <String>{};
    final shouldNotify = _passengerHydrated;

    for (final booking in bookings) {
      activeIds.add(booking.id);
      final key = '${booking.status.name}|${booking.dispatchStatus.name}';
      final prev = _passengerSnapshot[booking.id];
      _passengerSnapshot[booking.id] = key;

      if (!shouldNotify || prev == null || prev == key) continue;

      final message = _passengerTransitionMessage(booking);
      if (message == null) continue;

      await NotificationService.instance.show(
        id: _notifId(booking.id, key),
        title: 'Actualizacion de tu reserva',
        body: message,
      );
    }

    _passengerSnapshot.removeWhere((id, _) => !activeIds.contains(id));
    _passengerHydrated = true;
  }

  Future<void> syncDriverBookings(List<Booking> bookings) async {
    final activeIds = <String>{};
    final shouldNotify = _driverHydrated;

    for (final booking in bookings) {
      activeIds.add(booking.id);
      final key = '${booking.status.name}|${booking.dispatchStatus.name}';
      final prev = _driverSnapshot[booking.id];
      _driverSnapshot[booking.id] = key;

      if (prev == null) {
        if (booking.status == BookingStatus.reserved &&
            booking.dispatchStatus == BookingDispatchStatus.reserved) {
          await NotificationService.instance.show(
            id: _notifId(booking.id, 'new_request'),
            title: 'Nueva solicitud de viaje',
            body:
                '${booking.passengerName ?? 'Un pasajero'} quiere reservar tu turno.',
          );
        }
        continue;
      }

      if (prev == key) continue;

      if (!shouldNotify) continue;

      if (booking.dispatchStatus == BookingDispatchStatus.passengerBoarded) {
        await NotificationService.instance.show(
          id: _notifId(booking.id, key),
          title: 'Pasajero a bordo',
          body:
              '${booking.passengerName ?? 'El pasajero'} confirmo abordaje. Ya puedes iniciar viaje.',
        );
      }
    }

    _driverSnapshot.removeWhere((id, _) => !activeIds.contains(id));
    _driverHydrated = true;
  }

  String? _passengerTransitionMessage(Booking booking) {
    switch (booking.dispatchStatus) {
      case BookingDispatchStatus.accepted:
        return 'Tu reserva fue aceptada por ${booking.driverName ?? 'el conductor'}.';
      case BookingDispatchStatus.driverArriving:
        return '${booking.driverName ?? 'Tu conductor'} va en camino al punto de encuentro.';
      case BookingDispatchStatus.driverArrived:
        return '${booking.driverName ?? 'Tu conductor'} ya llego al punto de encuentro.';
      case BookingDispatchStatus.inProgress:
        return 'Tu viaje ya comenzo.';
      case BookingDispatchStatus.completed:
        return 'Tu viaje finalizo. Puedes dejar una resena.';
      case BookingDispatchStatus.cancelled:
        return 'Tu reserva fue cancelada.';
      case BookingDispatchStatus.noShow:
        return 'El viaje se cerro como no-show.';
      case BookingDispatchStatus.reserved:
      case BookingDispatchStatus.passengerBoarded:
        return null;
    }
  }

  int _notifId(String bookingId, String seed) {
    return (bookingId.hashCode ^ seed.hashCode).abs() & 0x7fffffff;
  }
}
