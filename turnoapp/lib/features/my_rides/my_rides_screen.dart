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
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/error_mapper.dart';
import '../../models/booking.dart';
import '../../models/enums.dart';
import '../../providers/my_rides_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/decorative_background.dart';

class MyRidesScreen extends ConsumerStatefulWidget {
  const MyRidesScreen({super.key});

  @override
  ConsumerState<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends ConsumerState<MyRidesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => ref.read(myRidesProvider.notifier).load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await ref.read(myRidesProvider.notifier).load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        AppErrorMapper.toMessage(e,
            fallback: 'No pudimos cargar tus reservas.'),
        isError: true,
      );
    }
  }

  Future<void> _confirmBoarding(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar abordaje'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              booking.dispatchStatus == BookingDispatchStatus.driverArrived
                  ? 'El conductor marco llegada. Confirma solo si realmente abordaste.'
                  : 'Confirma abordaje solo cuando subas al auto. Esto habilita inicio de viaje.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Monto retenido: \$${booking.amountTotal}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF178E68),
              foregroundColor: Colors.white,
            ),
            child: const Text('ME SUBI AL AUTO'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(myRidesProvider.notifier).confirmBoarding(booking.id);
      if (!mounted) return;
      AppSnackbar.show(
          context, 'Abordaje confirmado. El conductor puede iniciar viaje.');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        AppErrorMapper.toMessage(e,
            fallback: 'No pudimos confirmar el abordaje.'),
        isError: true,
      );
    }
  }

  Future<void> _cancelBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se cancelara tu reserva y los fondos seran devueltos a tu billetera.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Se devolveran \$${booking.amountTotal} a tu saldo.',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(myRidesProvider.notifier).cancelBooking(booking.id);
      if (!mounted) return;
      AppSnackbar.show(context, 'Reserva cancelada. Fondos devueltos.');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        AppErrorMapper.toMessage(e,
            fallback: 'No pudimos cancelar la reserva.'),
        isError: true,
      );
    }
  }

  Future<void> _reportNoShow(Booking booking) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reportar conductor no-show'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debes esperar al menos ${AppConstants.waitTimeMinutesNoShow} minutos en el punto de encuentro antes de reportar.',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Ej: espere en el punto acordado y no llego',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reportar no-show'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      notesController.dispose();
      return;
    }

    try {
      await ref.read(myRidesProvider.notifier).reportNoShow(
            booking.id,
            notes: notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
          );
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Reporte enviado. Se aplico reembolso y evaluacion de strike.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        AppErrorMapper.toMessage(
          e,
          fallback: 'No pudimos reportar no-show en este momento.',
        ),
        isError: true,
      );
    } finally {
      notesController.dispose();
    }
  }

  void _openActiveTrip(Booking booking) {
    context.push('/active-trip/${booking.id}');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myRidesProvider);
    final active = state.bookings.where((b) => b.isReserved).toList();
    final history = state.bookings.where((b) => !b.isReserved).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis reservas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Activas'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: DecorativeBackground(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    active.isEmpty
                        ? const _EmptyState(
                            message: 'No tienes reservas activas',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: active.length,
                            itemBuilder: (ctx, i) => _BookingCard(
                              booking: active[i],
                              onConfirmBoarding: _confirmBoarding,
                              onCancelBooking: _cancelBooking,
                              onReportNoShow: _reportNoShow,
                              onOpenActiveTrip: _openActiveTrip,
                            ),
                          ),
                    history.isEmpty
                        ? const _EmptyState(message: 'Sin historial aun')
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: history.length,
                            itemBuilder: (ctx, i) => _BookingCard(
                              booking: history[i],
                              onConfirmBoarding: null,
                              onOpenActiveTrip: null,
                            ),
                          ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final void Function(Booking)? onConfirmBoarding;
  final void Function(Booking)? onCancelBooking;
  final void Function(Booking)? onReportNoShow;
  final void Function(Booking)? onOpenActiveTrip;

  const _BookingCard({
    required this.booking,
    this.onConfirmBoarding,
    this.onCancelBooking,
    this.onReportNoShow,
    this.onOpenActiveTrip,
  });

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
        statusColor = AppTheme.primary;
        statusLabel = 'Reservado';
        break;
      case BookingStatus.completed:
        statusColor = const Color(0xFF178E68);
        statusLabel = 'Completado';
        break;
      case BookingStatus.cancelled:
        statusColor = AppTheme.danger;
        statusLabel = 'Cancelado';
        break;
      case BookingStatus.noShow:
        statusColor = AppTheme.warning;
        statusLabel = 'No show';
        break;
    }

    final dispatchLabel = booking.dispatchLabel;
    final dispatchColor = switch (booking.dispatchStatus) {
      BookingDispatchStatus.reserved => AppTheme.subtle,
      BookingDispatchStatus.accepted => AppTheme.primary,
      BookingDispatchStatus.driverArriving => AppTheme.primary,
      BookingDispatchStatus.driverArrived => const Color(0xFF178E68),
      BookingDispatchStatus.passengerBoarded => const Color(0xFF178E68),
      BookingDispatchStatus.inProgress => const Color(0xFF178E68),
      BookingDispatchStatus.completed => const Color(0xFF1760A3),
      BookingDispatchStatus.cancelled => AppTheme.danger,
      BookingDispatchStatus.noShow => AppTheme.warning,
    };

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
                    booking.rideOriginCommune != null
                        ? '${booking.rideOriginCommune} · ${booking.campusName ?? ''}'
                        : 'Turno',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(dateFmt,
                style: const TextStyle(color: AppTheme.subtle, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              dispatchLabel,
              style: TextStyle(
                fontSize: 12,
                color: dispatchColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (booking.driverName != null ||
                booking.driverVehiclePlate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Conductor: ${booking.driverName ?? '-'} · Auto ${booking.driverVehicleModel ?? '-'} · Patente ${booking.driverVehiclePlate ?? '-'}',
                style: const TextStyle(fontSize: 12, color: AppTheme.subtle),
              ),
            ],
            if (booking.isReserved && onOpenActiveTrip != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onOpenActiveTrip!(booking),
                  icon: const Icon(Icons.local_taxi_outlined),
                  label: const Text('Abrir viaje activo'),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text('Monto retenido: $priceFmt',
                style: const TextStyle(fontSize: 13)),
            if (booking.canPassengerConfirmBoarding &&
                onConfirmBoarding != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => onConfirmBoarding!(booking),
                  icon: const Icon(Icons.directions_car),
                  label: const Text(
                    'ME SUBI AL AUTO',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF178E68),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
            if (booking.isReserved &&
                booking.dispatchStatus != BookingDispatchStatus.inProgress &&
                booking.dispatchStatus !=
                    BookingDispatchStatus.passengerBoarded &&
                onCancelBooking != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  onPressed: () => onCancelBooking!(booking),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger),
                  ),
                  child: const Text('Cancelar reserva'),
                ),
              ),
            ],
            if (booking.isReserved &&
                (booking.dispatchStatus == BookingDispatchStatus.accepted ||
                    booking.dispatchStatus ==
                        BookingDispatchStatus.driverArriving ||
                    booking.dispatchStatus ==
                        BookingDispatchStatus.driverArrived) &&
                onReportNoShow != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: () => onReportNoShow!(booking),
                  icon: const Icon(Icons.warning_amber_outlined),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.warning,
                    side: const BorderSide(color: AppTheme.warning),
                  ),
                  label: const Text('Conductor no llego (no-show)'),
                ),
              ),
            ],
          ],
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
          Icon(Icons.confirmation_num_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppTheme.subtle)),
        ],
      ),
    );
  }
}
