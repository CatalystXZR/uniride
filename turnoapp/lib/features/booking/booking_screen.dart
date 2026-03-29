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
import '../../core/constants.dart';
import '../../core/error_mapper.dart';
import '../../models/enums.dart';
import '../../models/ride.dart';
import '../../models/user_profile.dart';
import '../../services/ride_service.dart';
import '../../services/booking_service.dart';
import '../../services/profile_service.dart';
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
  final _profileService = ProfileService();

  Ride? _ride;
  Wallet? _wallet;
  UserProfile? _driverProfile;
  bool _loading = true;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _rideService.getRideById(widget.rideId),
        _walletService.getWallet(),
      ]);
      final ride = results[0] as Ride?;
      UserProfile? driverProfile;
      if (ride != null) {
        driverProfile = await _profileService.getProfileById(ride.driverId);
      }
      if (mounted) {
        setState(() {
          _ride = ride;
          _wallet = results[1] as Wallet?;
          _driverProfile = driverProfile;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackbar.show(
          context,
          AppErrorMapper.toMessage(
            e,
            fallback: 'No pudimos cargar el detalle del turno.',
          ),
          isError: true,
        );
      }
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
        AppSnackbar.show(
          context,
          AppErrorMapper.toMessage(
            e,
            fallback: 'No pudimos completar tu reserva. Intenta nuevamente.',
          ),
          isError: true,
        );
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

    final canBook = (_ride?.isActive ?? false) && !(_ride?.isFull ?? true);

    return LoadingOverlay(
      isLoading: _booking,
      message: 'Procesando reserva...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Detalle del turno')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _ride == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_car_outlined,
                            size: 52,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Este turno ya no esta disponible.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => context.pop(),
                            child: const Text('Volver'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    children: [
                      _InfoSection(ride: _ride!),
                      const SizedBox(height: 12),
                      if (_driverProfile != null)
                        _DriverProfileSection(profile: _driverProfile!),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resumen de pago',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              _PriceRow(label: 'Precio por asiento', value: priceFmt),
                              const Divider(),
                              _PriceRow(
                                label: 'Comision plataforma',
                                value: NumberFormat.currency(
                                  locale: 'es_CL',
                                  symbol: '\$',
                                  decimalDigits: 0,
                                ).format(_ride?.platformFee ?? 0),
                              ),
                              _PriceRow(
                                label: 'Neto conductor',
                                value: NumberFormat.currency(
                                  locale: 'es_CL',
                                  symbol: '\$',
                                  decimalDigits: 0,
                                ).format(_ride?.driverNetAmount ?? price),
                              ),
                              _PriceRow(
                                label: 'Total a retener',
                                value: priceFmt,
                                bold: true,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (_wallet?.balanceAvailable ?? 0) >= price
                                      ? const Color(0xFFE9F6EE)
                                      : const Color(0xFFFCEDEF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Tu saldo actual: $balanceFmt',
                                  style: TextStyle(
                                    color: (_wallet?.balanceAvailable ?? 0) >= price
                                        ? const Color(0xFF1B734D)
                                        : const Color(0xFF8A2F43),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'El pago se libera al conductor cuando presiones "ME SUBI AL AUTO".',
                                style: TextStyle(fontSize: 12, color: Color(0xFF5F6E7C)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tiempo de espera recomendado: ${AppConstants.waitTimeMinutesNoShow} minutos en el punto de encuentro.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF5F6E7C),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'TurnoApp actua como intermediario. Usa boton de panico y llama al 133 ante emergencias.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8A2F43),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        bottomNavigationBar: _ride == null
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: canBook ? _confirmBooking : null,
                      child: const Text('Reservar asiento'),
                    ),
                    if (_ride!.isFull)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Turno sin cupos disponibles',
                          style: TextStyle(color: Color(0xFF8A2F43), fontSize: 12),
                        ),
                      ),
                  ],
                ),
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F0F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isTo ? Icons.school_outlined : Icons.home_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
            if (ride.meetingPoint != null && ride.meetingPoint!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.pin_drop_outlined,
                label: 'Punto de encuentro: ${ride.meetingPoint}',
              ),
            ],
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

class _DriverProfileSection extends StatelessWidget {
  final UserProfile profile;

  const _DriverProfileSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Perfil del conductor',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFE7F0F6),
                  backgroundImage: (profile.profilePhotoUrl != null &&
                          profile.profilePhotoUrl!.isNotEmpty)
                      ? NetworkImage(profile.profilePhotoUrl!)
                      : null,
                  child: (profile.profilePhotoUrl == null ||
                          profile.profilePhotoUrl!.isEmpty)
                      ? const Icon(Icons.person_outline)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName ?? 'Conductor',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Rating ${profile.ratingAvg.toStringAsFixed(2)} (${profile.ratingCount})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6A7783),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (profile.vehiclePlate != null || profile.vehicleModel != null) ...[
              const SizedBox(height: 10),
              Text(
                'Auto: ${(profile.vehicleModel ?? '-')} · Patente: ${(profile.vehiclePlate ?? '-')}',
                style: const TextStyle(fontSize: 13),
              ),
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
        Icon(icon, size: 16, color: const Color(0xFF6B7884)),
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
