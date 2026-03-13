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
import '../../core/supabase_client.dart';
import '../../models/ride.dart';
import '../../models/enums.dart';
import '../../services/ride_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/loading_overlay.dart';
import 'package:intl/intl.dart';

class PublishRideScreen extends StatefulWidget {
  const PublishRideScreen({super.key});

  @override
  State<PublishRideScreen> createState() => _PublishRideScreenState();
}

class _PublishRideScreenState extends State<PublishRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rideService = RideService();

  String? _selectedCommune;
  String? _selectedUniversityId;
  String? _selectedCampusId;
  RideDirection _direction = RideDirection.toCampus;
  DateTime? _departureAt;
  int _seats = 3;
  bool _loading = false;

  // Fetched from DB
  List<Map<String, dynamic>> _universities = [];
  List<Map<String, dynamic>> _campuses = [];

  @override
  void initState() {
    super.initState();
    _loadUniversities();
  }

  Future<void> _loadUniversities() async {
    final rows = await SupabaseConfig.client
        .from('universities')
        .select()
        .order('name');
    if (mounted) setState(() => _universities = List<Map<String, dynamic>>.from(rows));
  }

  Future<void> _loadCampuses(String universityId) async {
    final rows = await SupabaseConfig.client
        .from('campuses')
        .select()
        .eq('university_id', universityId)
        .order('name');
    if (mounted) {
      setState(() {
        _campuses = List<Map<String, dynamic>>.from(rows);
        _selectedCampusId = null;
      });
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;

    setState(() {
      _departureAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_departureAt == null) {
      AppSnackbar.show(context, 'Selecciona fecha y hora', isError: true);
      return;
    }
    if (_selectedCampusId == null || _selectedUniversityId == null) {
      AppSnackbar.show(context, 'Selecciona universidad y campus', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = SupabaseConfig.client.auth.currentUser!.id;
      final ride = Ride(
        id: '',
        driverId: uid,
        universityId: _selectedUniversityId!,
        campusId: _selectedCampusId!,
        originCommune: _selectedCommune!,
        direction: _direction,
        departureAt: _departureAt!,
        seatPrice: AppConstants.seatPriceCLP,
        seatsTotal: _seats,
        seatsAvailable: _seats,
        status: 'active',
        createdAt: DateTime.now(),
      );
      await _rideService.createRide(ride);
      if (mounted) {
        AppSnackbar.show(context, 'Turno publicado correctamente');
        context.pop();
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departureFmt = _departureAt != null
        ? DateFormat('EEE d MMM, HH:mm', 'es').format(_departureAt!)
        : 'Seleccionar';

    return LoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Publicar turno')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Direction toggle
              const Text('Dirección del viaje',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<RideDirection>(
                segments: const [
                  ButtonSegment(
                    value: RideDirection.toCampus,
                    label: Text('Hacia campus'),
                    icon: Icon(Icons.school_outlined),
                  ),
                  ButtonSegment(
                    value: RideDirection.fromCampus,
                    label: Text('Desde campus'),
                    icon: Icon(Icons.home_outlined),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (s) =>
                    setState(() => _direction = s.first),
              ),
              const SizedBox(height: 20),

              // Commune
              DropdownButtonFormField<String>(
                value: _selectedCommune,
                decoration: const InputDecoration(
                  labelText: 'Comuna de origen',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                items: AppConstants.allowedCommunes
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCommune = v),
                validator: (v) => v != null ? null : 'Requerido',
              ),
              const SizedBox(height: 16),

              // University
              DropdownButtonFormField<String>(
                value: _selectedUniversityId,
                decoration: const InputDecoration(
                  labelText: 'Universidad',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                items: _universities
                    .map((u) => DropdownMenuItem(
                          value: u['id'] as String,
                          child: Text(u['name'] as String),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedUniversityId = v;
                    _selectedCampusId = null;
                  });
                  if (v != null) _loadCampuses(v);
                },
                validator: (v) => v != null ? null : 'Requerido',
              ),
              const SizedBox(height: 16),

              // Campus
              DropdownButtonFormField<String>(
                value: _selectedCampusId,
                decoration: const InputDecoration(
                  labelText: 'Campus',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                items: _campuses
                    .map((c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text(c['name'] as String),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCampusId = v),
                validator: (v) => v != null ? null : 'Requerido',
              ),
              const SizedBox(height: 16),

              // Date & Time
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('Fecha y hora de salida'),
                subtitle: Text(departureFmt),
                trailing: TextButton(
                  onPressed: _pickDateTime,
                  child: const Text('Cambiar'),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFDADCE0)),
                ),
                tileColor: Colors.white,
              ),
              const SizedBox(height: 16),

              // Seats
              Row(
                children: [
                  const Text('Cupos disponibles',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    onPressed:
                        _seats > 1 ? () => setState(() => _seats--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_seats',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                  IconButton(
                    onPressed:
                        _seats < 6 ? () => setState(() => _seats++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Precio por asiento: \$${AppConstants.seatPriceCLP}',
                style:
                    const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Publicar turno'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
