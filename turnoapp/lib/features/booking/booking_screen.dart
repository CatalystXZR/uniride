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
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/enums.dart';
import '../../models/ride.dart';
import '../../services/ride_service.dart';
import '../../services/booking_service.dart';
import '../../services/wallet_service.dart';
import '../../models/wallet.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/loading_overlay.dart';

class BookingScreen extends StatefulWidget {
  final String rideId;
  const BookingScreen({super.key, required this.rideId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _rideService = RideService();
  final _bookingService = BookingService();
  final _walletService = WalletService();

  Ride? _ride;
  Wallet? _wallet;
  bool _loading = true;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _rideService.getRideById(widget.rideId),
      _walletService.getWallet(),
    ]);
    if (mounted) {
      setState(() {
        _ride = results[0] as Ride?;
        _wallet = results[1] as Wallet?;
        _loading = false;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_ride == null) return;
    final balance = _wallet?.balanceAvailable ?? 0;
    final price = _ride!.seatPrice;

    if (balance < price) {
      AppSnackbar.show(
        context,
        'Saldo insuficiente. Recarga tu billetera.',
        isError: true,
      );
      return;
    }

    final priceFmt = NumberFormat.currency(
      locale: 'es_CL', symbol: '\$', decimalDigits: 0,
    ).format(price);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar reserva'),
        content: Text(
          'Se descontarán $priceFmt de tu saldo y quedarán retenidos hasta que confirmes el abordaje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reservar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _booking = true);
    try {
      await _bookingService.createBooking(widget.rideId);
      if (mounted) {
        AppSnackbar.show(context, 'Reserva confirmada');
        context.go('/my-rides');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _ride?.seatPrice ?? 0;
    final priceFmt = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    ).format(price);

    final balanceFmt = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    ).format(_wallet?.balanceAvailable ?? 0);

    return LoadingOverlay(
      isLoading: _booking,
      message: 'Procesando reserva...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Detalle del turno')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _ride == null
                ? const Center(child: Text('Turno no encontrado'))
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _InfoSection(ride: _ride!),
                      const SizedBox(height: 20),

                      // Payment summary
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Resumen de pago',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                              const SizedBox(height: 12),
                              _PriceRow(
                                label: 'Precio por asiento',
                                value: priceFmt,
                              ),
                              const Divider(),
                              _PriceRow(
                                label: 'Total a retener',
                                value: priceFmt,
                                bold: true,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tu saldo actual: $balanceFmt',
                                style: TextStyle(
                                  color: (_wallet?.balanceAvailable ?? 0) >= price
                                      ? Colors.green
                                      : Colors.redAccent,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'El pago se libera al conductor cuando presiones "ME SUBÍ AL AUTO".',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      ElevatedButton(
                        onPressed: _ride!.isActive && !_ride!.isFull
                            ? _confirmBooking
                            : null,
                        child: const Text('Reservar asiento'),
                      ),

                      if (_ride!.isFull)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Turno sin cupos disponibles',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final Ride ride;
  const _InfoSection({required this.ride});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEEE d \'de\' MMMM, HH:mm', 'es')
        .format(ride.departureAt);
    final isTo = ride.direction == RideDirection.toCampus;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isTo ? Icons.school_outlined : Icons.home_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  ride.directionLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: isTo
                  ? '${ride.originCommune} → ${ride.campusName ?? ''}'
                  : '${ride.campusName ?? ''} → ${ride.originCommune}',
            ),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.access_time, label: dateFmt),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.event_seat_outlined,
              label:
                  '${ride.seatsAvailable} de ${ride.seatsTotal} cupos libres',
            ),
            if (ride.driverName != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                  icon: Icons.person_outline, label: ride.driverName!),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _PriceRow(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      fontSize: bold ? 15 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
