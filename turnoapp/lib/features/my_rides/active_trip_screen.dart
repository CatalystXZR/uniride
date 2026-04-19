import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/error_mapper.dart';
import '../../models/booking.dart';
import '../../models/enums.dart';
import '../../providers/my_rides_provider.dart';
import '../../shared/widgets/app_snackbar.dart';

class ActiveTripScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const ActiveTripScreen({super.key, required this.bookingId});

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  Booking? _bookingFromState() {
    final state = ref.watch(myRidesProvider);
    try {
      return state.bookings.firstWhere((b) => b.id == widget.bookingId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    try {
      await ref.read(myRidesProvider.notifier).load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        AppErrorMapper.toMessage(
          e,
          fallback: 'No pudimos actualizar el estado del viaje.',
        ),
        isError: true,
      );
    }
  }

  Future<void> _confirmBoarding(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar abordaje'),
        content: const Text(
          'Confirma solo cuando estes dentro del auto. Esto habilita el inicio del viaje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar abordaje'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(myRidesProvider.notifier).confirmBoarding(booking.id);
      if (!mounted) return;
      AppSnackbar.show(context, 'Abordaje confirmado.');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        AppErrorMapper.toMessage(
          e,
          fallback: 'No pudimos confirmar tu abordaje.',
        ),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _bookingFromState();
    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Viaje activo')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No encontramos este viaje.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _refresh,
                child: const Text('Actualizar'),
              ),
            ],
          ),
        ),
      );
    }

    const flowOrder = <BookingDispatchStatus>[
      BookingDispatchStatus.reserved,
      BookingDispatchStatus.accepted,
      BookingDispatchStatus.driverArriving,
      BookingDispatchStatus.driverArrived,
      BookingDispatchStatus.passengerBoarded,
      BookingDispatchStatus.inProgress,
      BookingDispatchStatus.completed,
    ];
    final currentFlowIndex = flowOrder.indexOf(booking.dispatchStatus);
    bool reached(BookingDispatchStatus status) {
      final target = flowOrder.indexOf(status);
      if (target < 0 || currentFlowIndex < 0) return false;
      return currentFlowIndex >= target;
    }

    final statusItems = <_StatusStep>[
      _StatusStep(
        label: 'Reserva creada',
        done: true,
      ),
      _StatusStep(
        label: 'Conductor acepto',
        done: reached(BookingDispatchStatus.accepted),
      ),
      _StatusStep(
        label: 'Conductor en camino',
        done: reached(BookingDispatchStatus.driverArriving),
      ),
      _StatusStep(
        label: 'Conductor llego',
        done: reached(BookingDispatchStatus.driverArrived),
      ),
      _StatusStep(
        label: 'Abordaje confirmado',
        done: reached(BookingDispatchStatus.passengerBoarded),
      ),
      _StatusStep(
        label: 'Viaje en curso',
        done: reached(BookingDispatchStatus.inProgress),
      ),
      _StatusStep(
        label: 'Viaje finalizado',
        done: reached(BookingDispatchStatus.completed),
      ),
    ];

    final canConfirmBoarding = booking.canPassengerConfirmBoarding;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Viaje activo'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            if (booking.dispatchStatus == BookingDispatchStatus.cancelled ||
                booking.dispatchStatus == BookingDispatchStatus.noShow) ...[
              Card(
                color: const Color(0xFFFFF3F6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    booking.dispatchStatus == BookingDispatchStatus.cancelled
                        ? 'Este viaje fue cancelado.'
                        : 'Este viaje fue marcado como no-show.',
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.dispatchLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${booking.rideOriginCommune ?? '-'} · ${booking.campusName ?? '-'}',
                      style: const TextStyle(color: AppTheme.subtle),
                    ),
                    if (booking.driverName != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Conductor: ${booking.driverName}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (booking.driverVehicleModel != null ||
                        booking.driverVehiclePlate != null)
                      Text(
                        'Auto ${booking.driverVehicleModel ?? '-'} · Patente ${booking.driverVehiclePlate ?? '-'}',
                        style: const TextStyle(color: AppTheme.subtle),
                      ),
                    if (booking.driverEmergencyContact != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Contacto conductor: ${booking.driverEmergencyContact}',
                        style: const TextStyle(color: AppTheme.subtle),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progreso del viaje',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    ...statusItems.map(
                      (step) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              step.done
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: step.done
                                  ? const Color(0xFF178E68)
                                  : const Color(0xFF9AA8B5),
                            ),
                            const SizedBox(width: 8),
                            Text(step.label),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFFFF3F6),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seguridad',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Si hay emergencia, llama al ${AppConstants.emergencyPhoneCL} de inmediato.',
                      style: const TextStyle(color: AppTheme.danger),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canConfirmBoarding)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmBoarding(booking),
                  icon: const Icon(Icons.directions_car),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF178E68),
                  ),
                  label: const Text('ME SUBI AL AUTO'),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  AppSnackbar.show(
                    context,
                    'Emergencia: llama al ${AppConstants.emergencyPhoneCL}',
                    isError: true,
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: const BorderSide(color: AppTheme.danger),
                ),
                icon: const Icon(Icons.emergency_outlined),
                label: const Text('Boton de emergencia'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusStep {
  final String label;
  final bool done;

  const _StatusStep({required this.label, required this.done});
}
