/**
 *
 * Project: TurnoApp
 *
 * Original Concept: Agustin Puelma, Cristobal Cordova, Carlos Ibarra
 *
 * Software Architecture & Code: Matias Toledo (catalystxzr)
 *
 * Description: Production-grade implementation for UDD carpooling system.
 *
 * Copyright (c) 2026. All rights reserved.
 *
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/error_mapper.dart';
import '../../models/booking.dart';
import '../../models/enums.dart';
import '../../models/ride.dart';
import '../../providers/driver_rides_provider.dart';
import '../../shared/widgets/app_snackbar.dart';

class DriverRidesScreen extends ConsumerStatefulWidget {
  const DriverRidesScreen({super.key});

  @override
  ConsumerState<DriverRidesScreen> createState() => _DriverRidesScreenState();
}

class _DriverRidesScreenState extends ConsumerState<DriverRidesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => ref.read(driverRidesProvider.notifier).load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await ref.read(driverRidesProvider.notifier).load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        AppErrorMapper.toMessage(
          e,
          fallback: 'No pudimos cargar tus turnos publicados.',
        ),
        isError: true,
      );
    }
  }

  Future<void> _cancelRide(Ride ride) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar turno publicado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se reembolsara a los pasajeros reservados y podrias recibir strike por cancelacion.',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                hintText: 'Ej: emergencia mecanica',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8A2F43)),
            child: const Text('Cancelar turno'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }

    try {
      await ref.read(driverRidesProvider.notifier).cancelRide(
            ride.id,
            reason: reasonController.text.trim().isEmpty
                ? 'cancelled_by_driver'
                : reasonController.text.trim(),
          );
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Turno cancelado. Reembolsos aplicados y strike evaluado.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        AppErrorMapper.toMessage(
          e,
          fallback: 'No pudimos cancelar el turno en este momento.',
        ),
        isError: true,
      );
    } finally {
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverRidesProvider);
    final activeRides = state.rides.where((r) => r.isActive).toList();
    final pastRides = state.rides.where((r) => !r.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis turnos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Activos'),
            Tab(text: 'Pasajeros'),
          ],
        ),
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: TabBarView(
                controller: _tabController,
                children: [
                  activeRides.isEmpty && pastRides.isEmpty
                      ? const _EmptyState(
                          message: 'No has publicado turnos aun')
                      : ListView(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          children: [
                            if (activeRides.isNotEmpty) ...[
                              const _SectionHeader(title: 'Activos'),
                              ...activeRides.map(
                                (r) => _RideCard(
                                  ride: r,
                                  onCancel: () => _cancelRide(r),
                                ),
                              ),
                            ],
                            if (pastRides.isNotEmpty) ...[
                              const _SectionHeader(title: 'Historial'),
                              ...pastRides.map((r) => _RideCard(ride: r)),
                            ],
                          ],
                        ),
                  state.bookings.isEmpty
                      ? const _EmptyState(message: 'Sin pasajeros registrados')
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: state.bookings.length,
                          itemBuilder: (ctx, i) =>
                              _PassengerBookingCard(booking: state.bookings[i]),
                        ),
                ],
              ),
            ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final Ride ride;
  final VoidCallback? onCancel;

  const _RideCard({required this.ride, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final dateFmt =
        DateFormat('EEE d MMM, HH:mm', 'es').format(ride.departureAt);
    final priceFmt = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    ).format(ride.seatPrice);

    Color statusColor;
    String statusLabel;
    switch (ride.status) {
      case 'active':
        statusColor = const Color(0xFF2F7D67);
        statusLabel = 'Activo';
        break;
      case 'completed':
        statusColor = const Color(0xFF365D74);
        statusLabel = 'Completado';
        break;
      default:
        statusColor = const Color(0xFF8A2F43);
        statusLabel = 'Cancelado';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ride.direction == RideDirection.toCampus
                        ? '${ride.originCommune} -> Campus'
                        : 'Campus -> ${ride.originCommune}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                _StatusBadge(label: statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 6),
            Text(dateFmt,
                style: const TextStyle(color: Color(0xFF6A7783), fontSize: 13)),
            if (ride.meetingPoint != null && ride.meetingPoint!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Punto: ${ride.meetingPoint}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6A7783)),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.event_seat_outlined,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${ride.seatsAvailable} / ${ride.seatsTotal} cupos libres',
                  style: const TextStyle(fontSize: 13),
                ),
                const Spacer(),
                Text(
                  '$priceFmt / asiento',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (ride.isActive && onCancel != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8A2F43),
                    side: const BorderSide(color: Color(0xFF8A2F43)),
                  ),
                  label: const Text('Cancelar turno'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PassengerBookingCard extends StatelessWidget {
  final Booking booking;

  const _PassengerBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final priceFmt = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    ).format(booking.amountTotal);

    final dateFmt = booking.rideDepartureAt != null
        ? DateFormat('EEE d MMM, HH:mm', 'es').format(booking.rideDepartureAt!)
        : '--';

    Color statusColor;
    String statusLabel;
    switch (booking.status) {
      case BookingStatus.reserved:
        statusColor = const Color(0xFF1E5B7A);
        statusLabel = 'Reservado';
        break;
      case BookingStatus.completed:
        statusColor = const Color(0xFF2F7D67);
        statusLabel = 'Completado';
        break;
      case BookingStatus.cancelled:
        statusColor = const Color(0xFF8A2F43);
        statusLabel = 'Cancelado';
        break;
      case BookingStatus.noShow:
        statusColor = const Color(0xFFC4871F);
        statusLabel = 'No show';
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(Icons.person_outline, color: statusColor, size: 20),
        ),
        title: Text(
          booking.passengerName ?? booking.rideOriginCommune ?? 'Turno',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        isThreeLine: true,
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateFmt,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6A7783))),
            if (booking.passengerVehiclePlate != null ||
                booking.passengerVehicleModel != null)
              Text(
                'Auto ${booking.passengerVehicleModel ?? '-'} · Patente ${booking.passengerVehiclePlate ?? '-'}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6A7783)),
              ),
            if (booking.passengerRating != null)
              Text(
                'Rating ${booking.passengerRating!.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6A7783)),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(priceFmt,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            _StatusBadge(label: statusLabel, color: statusColor),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6A7783),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.drive_eta, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Color(0xFF6A7783))),
        ],
      ),
    );
  }
}
