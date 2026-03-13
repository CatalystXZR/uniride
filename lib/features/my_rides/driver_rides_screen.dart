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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/booking.dart';
import '../../models/ride.dart';
import '../../models/enums.dart';
import '../../services/ride_service.dart';
import '../../services/booking_service.dart';
import '../../shared/widgets/app_snackbar.dart';

class DriverRidesScreen extends StatefulWidget {
  const DriverRidesScreen({super.key});

  @override
  State<DriverRidesScreen> createState() => _DriverRidesScreenState();
}

class _DriverRidesScreenState extends State<DriverRidesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _rideService = RideService();
  final _bookingService = BookingService();

  List<Ride> _rides = [];
  List<Booking> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _rideService.getMyRides(),
        _bookingService.getBookingsForMyRides(),
      ]);
      if (mounted) {
        setState(() {
          _rides    = results[0] as List<Ride>;
          _bookings = results[1] as List<Booking>;
        });
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Ride> get _activeRides =>
      _rides.where((r) => r.isActive).toList();

  List<Ride> get _pastRides =>
      _rides.where((r) => !r.isActive).toList();

  @override
  Widget build(BuildContext context) {
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: rides published by this driver
                  _activeRides.isEmpty && _pastRides.isEmpty
                      ? const _EmptyState(message: 'No has publicado turnos aún')
                      : ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            if (_activeRides.isNotEmpty) ...[
                              const _SectionHeader(title: 'Activos'),
                              ..._activeRides.map((r) => _RideCard(ride: r)),
                            ],
                            if (_pastRides.isNotEmpty) ...[
                              const _SectionHeader(title: 'Historial'),
                              ..._pastRides.map((r) => _RideCard(ride: r)),
                            ],
                          ],
                        ),

                  // Tab 2: passengers booked on this driver's rides
                  _bookings.isEmpty
                      ? const _EmptyState(message: 'Sin pasajeros registrados')
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _bookings.length,
                          itemBuilder: (ctx, i) =>
                              _PassengerBookingCard(booking: _bookings[i]),
                        ),
                ],
              ),
            ),
    );
  }
}

// ── Ride card (driver perspective) ─────────────────────────────────────────

class _RideCard extends StatelessWidget {
  final Ride ride;
  const _RideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE d MMM, HH:mm', 'es').format(ride.departureAt);
    final priceFmt = NumberFormat.currency(
      locale: 'es_CL', symbol: '\$', decimalDigits: 0,
    ).format(ride.seatPrice);

    Color statusColor;
    String statusLabel;
    switch (ride.status) {
      case 'active':
        statusColor = Colors.green;
        statusLabel = 'Activo';
        break;
      case 'completed':
        statusColor = Colors.blueGrey;
        statusLabel = 'Completado';
        break;
      default:
        statusColor = Colors.redAccent;
        statusLabel = 'Cancelado';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ride.direction == RideDirection.toCampus
                        ? '${ride.originCommune} → Campus'
                        : 'Campus → ${ride.originCommune}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                _StatusBadge(label: statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 6),
            Text(dateFmt,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
          ],
        ),
      ),
    );
  }
}

// ── Passenger booking card (driver perspective) ─────────────────────────────

class _PassengerBookingCard extends StatelessWidget {
  final Booking booking;
  const _PassengerBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final priceFmt = NumberFormat.currency(
      locale: 'es_CL', symbol: '\$', decimalDigits: 0,
    ).format(booking.amountTotal);

    final dateFmt = booking.rideDepartureAt != null
        ? DateFormat('EEE d MMM, HH:mm', 'es').format(booking.rideDepartureAt!)
        : '--';

    Color statusColor;
    String statusLabel;
    switch (booking.status) {
      case BookingStatus.reserved:
        statusColor = Colors.blue;
        statusLabel = 'Reservado';
        break;
      case BookingStatus.completed:
        statusColor = Colors.green;
        statusLabel = 'Completado';
        break;
      case BookingStatus.cancelled:
        statusColor = Colors.redAccent;
        statusLabel = 'Cancelado';
        break;
      case BookingStatus.noShow:
        statusColor = Colors.orange;
        statusLabel = 'No show';
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(Icons.person_outline, color: statusColor, size: 20),
        ),
        title: Text(
          booking.rideOriginCommune ?? 'Turno',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(dateFmt,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(priceFmt,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            _StatusBadge(label: statusLabel, color: statusColor),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ───────────────────────────────────────────────────────────

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
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
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
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
