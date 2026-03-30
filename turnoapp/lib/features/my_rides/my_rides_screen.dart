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

import '../../core/constants.dart';
import '../../core/error_mapper.dart';
import '../../models/booking.dart';
import '../../models/enums.dart';
import '../../providers/my_rides_provider.dart';
import '../../shared/widgets/app_snackbar.dart';

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
            const Text(
              'Al presionar "ME SUBI AL AUTO" liberas el pago al conductor.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Se liberaran \$${booking.amountTotal} al conductor.',
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
                backgroundColor: const Color(0xFF2F7D67)),
            child: const Text('ME SUBI AL AUTO'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(myRidesProvider.notifier).confirmBoarding(booking.id);
      if (!mounted) return;
      AppSnackbar.show(context, 'Pago liberado al conductor. Buen viaje!');
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
                backgroundColor: const Color(0xFF8A2F43)),
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
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: TabBarView(
                controller: _tabController,
                children: [
                  active.isEmpty
                      ? const _EmptyState(message: 'No tienes reservas activas')
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: active.length,
                          itemBuilder: (ctx, i) => _BookingCard(
                            booking: active[i],
                            onConfirmBoarding: _confirmBoarding,
                            onCancelBooking: _cancelBooking,
                            onReportNoShow: _reportNoShow,
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
                          ),
                        ),
                ],
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

  const _BookingCard({
    required this.booking,
    this.onConfirmBoarding,
    this.onCancelBooking,
    this.onReportNoShow,
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
                style: const TextStyle(color: Color(0xFF6A7783), fontSize: 13)),
            const SizedBox(height: 6),
            Text('Monto retenido: $priceFmt',
                style: const TextStyle(fontSize: 13)),
            if (booking.isReserved && onConfirmBoarding != null) ...[
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
                      backgroundColor: const Color(0xFF2F7D67)),
                ),
              ),
            ],
            if (booking.isReserved && onCancelBooking != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  onPressed: () => onCancelBooking!(booking),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8A2F43),
                    side: const BorderSide(color: Color(0xFF8A2F43)),
                  ),
                  child: const Text('Cancelar reserva'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: onReportNoShow == null
                      ? null
                      : () => onReportNoShow!(booking),
                  icon: const Icon(Icons.warning_amber_outlined),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC4871F),
                    side: const BorderSide(color: Color(0xFFC4871F)),
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
          Text(message, style: const TextStyle(color: Color(0xFF6A7783))),
        ],
      ),
    );
  }
}
