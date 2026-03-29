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
import '../../core/constants.dart';
import '../../core/error_mapper.dart';
import '../../models/enums.dart';
import '../../models/ride.dart';
import '../../services/reference_data_service.dart';
import '../../services/ride_service.dart';
import '../../shared/widgets/turno_card.dart';
import '../../shared/widgets/app_snackbar.dart';

class SearchRidesScreen extends StatefulWidget {
  const SearchRidesScreen({super.key});

  @override
  State<SearchRidesScreen> createState() => _SearchRidesScreenState();
}

class _SearchRidesScreenState extends State<SearchRidesScreen> {
  final _rideService = RideService();
  final _referenceDataService = ReferenceDataService();

  String? _selectedCommune;
  String? _selectedDirection;
  String? _selectedCampusId;
  DateTime? _selectedDate;

  List<Map<String, dynamic>> _campuses = [];
  String? _campusesError;
  bool _loadingCampuses = true;
  List<Ride> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _loadCampuses();
  }

  Future<void> _loadCampuses() async {
    if (mounted) {
      setState(() {
        _loadingCampuses = true;
        _campusesError = null;
      });
    }

    try {
      final rows = await _referenceDataService.getCampusesWithUniversity();
      if (mounted) {
        setState(() {
          _campuses = rows;
          _campusesError = _referenceDataService.lastCallUsedFallback
              ? 'No se pudo cargar desde Supabase. Se usan datos de referencia locales.'
              : null;
          _loadingCampuses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCampuses = false;
          _campusesError =
              AppErrorMapper.toMessage(e, fallback: 'No se pudo cargar la lista de campus');
        });
      }
    }
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      _results = await _rideService.searchRides(
        campusId: _selectedCampusId,
        originCommune: _selectedCommune,
        direction: _selectedDirection,
        date: _selectedDate,
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          AppErrorMapper.toMessage(
            e,
            fallback: 'No pudimos buscar turnos ahora. Intenta nuevamente.',
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _search();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedCommune = null;
      _selectedDirection = null;
      _selectedCampusId = null;
      _selectedDate = null;
      _results = [];
      _searched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyFilter = _selectedCommune != null ||
        _selectedDirection != null ||
        _selectedCampusId != null ||
        _selectedDate != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar turnos'),
        actions: [
          if (_searched || hasAnyFilter)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Limpiar'),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD8E2EA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtros rapidos',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChipDropdown<String>(
                      label: 'Comuna',
                      value: _selectedCommune,
                      items: AppConstants.allowedCommunes
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _selectedCommune = v);
                        _search();
                      },
                    ),
                    _FilterChipDropdown<String>(
                      label: 'Direccion',
                      value: _selectedDirection,
                      items: const [
                        DropdownMenuItem(value: 'to_campus', child: Text('Hacia campus')),
                        DropdownMenuItem(value: 'from_campus', child: Text('Desde campus')),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedDirection = v);
                        _search();
                      },
                    ),
                    _campusesError != null
                        ? ActionChip(
                            avatar: const Icon(
                              Icons.error_outline,
                              size: 16,
                              color: Color(0xFF8A2F43),
                            ),
                            label: const Text('Reintentar campus'),
                            onPressed: _loadCampuses,
                          )
                        : _FilterChipDropdown<String>(
                            label: _loadingCampuses ? 'Cargando campus...' : 'Campus',
                            value: _selectedCampusId,
                            items: _campuses
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c['id'] as String,
                                    child: Text(
                                      '${c['name']} · ${(c['universities'] as Map?)?['name'] ?? ''}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _loadingCampuses
                                ? (_) {}
                                : (v) {
                                    setState(() => _selectedCampusId = v);
                                    _search();
                                  },
                          ),
                    ActionChip(
                      label: Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}'
                            : 'Fecha',
                      ),
                      avatar: const Icon(Icons.calendar_today, size: 16),
                      onPressed: _pickDate,
                      backgroundColor: _selectedDate != null
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : !_searched
                    ? _EmptyState(onSearch: _search)
                    : _results.isEmpty
                        ? const _NoResults()
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 2, bottom: 90),
                            itemCount: _results.length,
                            itemBuilder: (context, i) {
                              final ride = _results[i];
                              return TurnoCard(
                                originCommune: ride.originCommune,
                                universityName: ride.universityName ?? '',
                                universityCode: ride.universityCode,
                                campusName: ride.campusName ?? '',
                                meetingPoint: ride.meetingPoint,
                                departureAt: ride.departureAt,
                                direction: ride.direction == RideDirection.toCampus
                                    ? 'to_campus'
                                    : 'from_campus',
                                seatsAvailable: ride.seatsAvailable,
                                seatPrice: ride.seatPrice,
                                platformFee: ride.platformFee,
                                driverNetAmount: ride.driverNetAmount,
                                isRadial: ride.isRadial,
                                onTap: () => context.push('/booking/${ride.id}'),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: !_searched
          ? FloatingActionButton.extended(
              onPressed: _search,
              icon: const Icon(Icons.search),
              label: const Text('Buscar ahora'),
            )
          : null,
    );
  }
}

class _FilterChipDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterChipDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  /// Returns the display text for the currently selected value,
  /// or the placeholder [label] if nothing is selected.
  String get _displayLabel {
    if (value == null) return label;
    final match = items.where((i) => i.value == value).firstOrNull;
    if (match == null) return label;
    final child = match.child;
    if (child is Text) return child.data ?? label;
    return label;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      onSelected: (v) => onChanged(v),
      itemBuilder: (_) => items
          .map((item) => PopupMenuItem(
                value: item.value,
                child: item.child,
              ))
          .toList(),
      child: Chip(
        label: Text(_displayLabel),
        avatar: value != null
            ? const Icon(Icons.check_circle, size: 16, color: Color(0xFF1E5B7A))
            : null,
        backgroundColor: value != null
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onSearch;
  const _EmptyState({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'Filtra o presiona buscar\npara ver turnos disponibles',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6A7783)),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.search),
            label: const Text('Buscar turnos'),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_car_outlined,
            size: 64,
            color: Color(0xFF6A7783),
          ),
          const SizedBox(height: 12),
          const Text(
            'No hay turnos disponibles\ncon estos filtros',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6A7783)),
          ),
        ],
      ),
    );
  }
}
