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
import '../../core/error_mapper.dart';
import '../../models/enums.dart';
import '../../models/user_profile.dart';
import '../../models/wallet.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/wallet_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../../core/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _profileService = ProfileService();
  final _walletService = WalletService();
  final _auth = AuthService();

  UserProfile? _profile;
  Wallet? _wallet;
  bool _loading = true;
  bool _switchingRole = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _profileService.getProfile(),
        _walletService.getWallet(),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as UserProfile?;
          _wallet = results[1] as Wallet?;
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
            fallback: 'No pudimos cargar tu inicio. Intenta nuevamente.',
          ),
          isError: true,
        );
      }
    }
  }

  Future<void> _toggleRole() async {
    if (_profile == null || _switchingRole) return;

    final newMode = _profile!.roleMode == RoleMode.driver
        ? RoleMode.passenger
        : RoleMode.driver;

    if (newMode == RoleMode.driver) {
      if (!(_profile?.acceptedTerms ?? false)) {
        if (mounted) {
          AppSnackbar.show(
            context,
            'Debes aceptar terminos para activar modo conductor.',
            isError: true,
          );
        }
        return;
      }
      if (!(_profile?.hasValidLicense ?? false)) {
        if (mounted) {
          AppSnackbar.show(
            context,
            'Debes declarar licencia vigente para activar modo conductor.',
            isError: true,
          );
        }
        return;
      }
      final hasVehicleData =
          (_profile?.vehicleBrand?.trim().isNotEmpty ?? false) &&
              (_profile?.vehicleModel?.trim().isNotEmpty ?? false) &&
              (_profile?.vehicleVersion?.trim().isNotEmpty ?? false) &&
              ((_profile?.vehicleDoors ?? 0) >= 2) &&
              ((_profile?.vehicleDoors ?? 0) <= 6) &&
              (_profile?.vehicleBodyType?.trim().isNotEmpty ?? false) &&
              (_profile?.vehiclePlate?.trim().isNotEmpty ?? false);

      if (!hasVehicleData) {
        final completed = await _promptDriverVehicleRequirements();
        if (!completed) return;

        await _load();
        if (!mounted || _profile == null) return;

        final readyNow = (_profile?.hasValidLicense ?? false) &&
            _hasCompleteDriverVehicleData(_profile!);
        if (!readyNow) {
          if (mounted) {
            AppSnackbar.show(
              context,
              'Debes completar todos los datos del vehiculo para activar modo conductor.',
              isError: true,
            );
          }
          return;
        }
      }
      if ((_profile?.suspendedUntil?.isAfter(DateTime.now()) ?? false)) {
        final until =
            DateFormat('d MMM y', 'es').format(_profile!.suspendedUntil!);
        if (mounted) {
          AppSnackbar.show(
            context,
            'Tu perfil conductor esta suspendido hasta $until por strikes.',
            isError: true,
          );
        }
        return;
      }
    }

    setState(() => _switchingRole = true);

    try {
      final updated = await _profileService.setRoleMode(newMode);
      if (mounted) {
        setState(() => _profile = updated);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          AppErrorMapper.toMessage(
            e,
            fallback: 'No pudimos cambiar tu modo ahora.',
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _switchingRole = false);
    }
  }

  bool _hasCompleteDriverVehicleData(UserProfile profile) {
    return (profile.vehicleBrand?.trim().isNotEmpty ?? false) &&
        (profile.vehicleModel?.trim().isNotEmpty ?? false) &&
        (profile.vehicleVersion?.trim().isNotEmpty ?? false) &&
        ((profile.vehicleDoors ?? 0) >= 2) &&
        ((profile.vehicleDoors ?? 0) <= 6) &&
        (profile.vehicleBodyType?.trim().isNotEmpty ?? false) &&
        (profile.vehiclePlate?.trim().isNotEmpty ?? false);
  }

  Future<bool> _promptDriverVehicleRequirements() async {
    final fullNameController =
        TextEditingController(text: _profile?.fullName ?? '');
    final brandController =
        TextEditingController(text: _profile?.vehicleBrand ?? '');
    final modelController =
        TextEditingController(text: _profile?.vehicleModel ?? '');
    final versionController =
        TextEditingController(text: _profile?.vehicleVersion ?? '');
    final doorsController = TextEditingController(
      text: _profile?.vehicleDoors != null ? '${_profile?.vehicleDoors}' : '',
    );
    final bodyController =
        TextEditingController(text: _profile?.vehicleBodyType ?? '');
    final plateController =
        TextEditingController(text: _profile?.vehiclePlate ?? '');
    var hasLicense = _profile?.hasValidLicense ?? false;
    final formKey = GlobalKey<FormState>();
    var saving = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Completa datos para modo conductor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Estos datos son obligatorios para activar el modo conductor.',
                        style: TextStyle(color: Color(0xFF6A7783)),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: fullNameController,
                        decoration:
                            const InputDecoration(labelText: 'Nombre completo'),
                        validator: (v) => (v?.trim().length ?? 0) >= 3
                            ? null
                            : 'Nombre requerido',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: brandController,
                        decoration: const InputDecoration(labelText: 'Marca'),
                        validator: (v) => (v?.trim().isNotEmpty ?? false)
                            ? null
                            : 'Marca requerida',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: modelController,
                        decoration: const InputDecoration(labelText: 'Modelo'),
                        validator: (v) => (v?.trim().isNotEmpty ?? false)
                            ? null
                            : 'Modelo requerido',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: versionController,
                        decoration: const InputDecoration(labelText: 'Version'),
                        validator: (v) => (v?.trim().isNotEmpty ?? false)
                            ? null
                            : 'Version requerida',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: doorsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Cantidad de puertas'),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null) return 'Puertas requeridas';
                          if (n < 2 || n > 6) return 'Entre 2 y 6 puertas';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: bodyController,
                        decoration:
                            const InputDecoration(labelText: 'Carroceria'),
                        validator: (v) => (v?.trim().isNotEmpty ?? false)
                            ? null
                            : 'Carroceria requerida',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: plateController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Patente'),
                        validator: (v) => (v?.trim().isNotEmpty ?? false)
                            ? null
                            : 'Patente requerida',
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: hasLicense,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Licencia de conducir vigente'),
                        subtitle: const Text(
                            'Obligatorio para conducir en TurnoApp.'),
                        onChanged: (v) => setModalState(() => hasLicense = v),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                if (!hasLicense) {
                                  AppSnackbar.show(
                                    context,
                                    'Debes declarar licencia vigente.',
                                    isError: true,
                                  );
                                  return;
                                }

                                setModalState(() => saving = true);
                                try {
                                  await _profileService.updateProfileDetails(
                                    fullName: fullNameController.text.trim(),
                                    profilePhotoUrl: _profile?.profilePhotoUrl,
                                    vehicleBrand: brandController.text.trim(),
                                    vehicleModel: modelController.text.trim(),
                                    vehicleVersion:
                                        versionController.text.trim(),
                                    vehicleDoors:
                                        int.parse(doorsController.text.trim()),
                                    vehicleBodyType: bodyController.text.trim(),
                                    vehiclePlate: plateController.text
                                        .trim()
                                        .toUpperCase()
                                        .replaceAll(' ', ''),
                                    vehicleColor: _profile?.vehicleColor,
                                    emergencyContact:
                                        _profile?.emergencyContact,
                                    safetyNotes: _profile?.safetyNotes,
                                    hasValidLicense: hasLicense,
                                  );

                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop(true);
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    AppSnackbar.show(
                                      context,
                                      AppErrorMapper.toMessage(
                                        e,
                                        fallback:
                                            'No pudimos guardar los datos del vehiculo.',
                                      ),
                                      isError: true,
                                    );
                                  }
                                  setModalState(() => saving = false);
                                }
                              },
                        child: Text(
                            saving ? 'Guardando...' : 'Guardar y continuar'),
                      ),
                      TextButton(
                        onPressed:
                            saving ? null : () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    fullNameController.dispose();
    brandController.dispose();
    modelController.dispose();
    versionController.dispose();
    doorsController.dispose();
    bodyController.dispose();
    plateController.dispose();

    return result == true;
  }

  bool get _isDriver => _profile?.roleMode == RoleMode.driver;

  @override
  Widget build(BuildContext context) {
    final balanceStr = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    ).format(_wallet?.balanceAvailable ?? 0);

    return LoadingOverlay(
      isLoading: _switchingRole,
      message: 'Actualizando modo...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TurnoApp'),
          actions: [
            IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              onPressed: () => context.push('/wallet'),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await _auth.signOut();
              },
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _RoleSwitchCard(
                      isDriver: _isDriver,
                      name: _profile?.fullName ?? 'Usuario',
                      photoUrl: _profile?.profilePhotoUrl,
                      onToggle: _toggleRole,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final changed = await context.push('/profile/edit');
                        if (changed == true) {
                          _load();
                        }
                      },
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Editar mi perfil y auto'),
                    ),
                    const SizedBox(height: 12),
                    _BalanceCard(
                      balance: balanceStr,
                      held: _wallet?.balanceHeld ?? 0,
                      onTopup: () => context.push('/wallet'),
                    ),
                    if ((_profile?.strikesCount ?? 0) > 0 ||
                        (_profile?.suspendedUntil != null)) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Estado de seguridad',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text('Strikes: ${_profile?.strikesCount ?? 0}/2'),
                              if (_profile?.suspendedUntil != null)
                                Text(
                                  'Suspendido hasta: ${DateFormat('d MMM y', 'es').format(_profile!.suspendedUntil!)}',
                                  style: const TextStyle(
                                    color: Color(0xFF8A2F43),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      'Acciones principales',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    if (_isDriver) ...[
                      _ActionButton(
                        icon: Icons.add_circle_outline,
                        label: 'Publicar turno',
                        subtitle: 'Comparte tu ruta y define cupos',
                        color: const Color(0xFF1E5B7A),
                        onTap: () => context.push('/publish'),
                      ),
                      const SizedBox(height: 10),
                      _ActionButton(
                        icon: Icons.directions_car_outlined,
                        label: 'Mis turnos publicados',
                        subtitle: 'Revisa pasajeros y estado de viajes',
                        color: const Color(0xFF365D74),
                        onTap: () => context.push('/driver-rides'),
                      ),
                    ] else ...[
                      _ActionButton(
                        icon: Icons.search,
                        label: 'Buscar turno',
                        subtitle: 'Encuentra viajes por comuna y campus',
                        color: const Color(0xFF1E5B7A),
                        onTap: () => context.push('/search'),
                      ),
                      const SizedBox(height: 10),
                      _ActionButton(
                        icon: Icons.confirmation_num_outlined,
                        label: 'Mis reservas',
                        subtitle: 'Confirma abordaje o revisa historial',
                        color: const Color(0xFF365D74),
                        onTap: () => context.push('/my-rides'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/terms'),
                      icon: const Icon(Icons.gavel_outlined),
                      label: const Text('Terminos y seguridad'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        AppSnackbar.show(
                          context,
                          'En emergencia llama al ${AppConstants.emergencyPhoneCL}.',
                          isError: true,
                        );
                      },
                      icon: const Icon(Icons.emergency_outlined),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8A2F43),
                        side: const BorderSide(color: Color(0xFF8A2F43)),
                      ),
                      label: const Text('Boton de panico'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _RoleSwitchCard extends StatelessWidget {
  final bool isDriver;
  final String name;
  final String? photoUrl;
  final VoidCallback onToggle;

  const _RoleSwitchCard({
    required this.isDriver,
    required this.name,
    this.photoUrl,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                      ? NetworkImage(photoUrl!)
                      : null,
                  child: (photoUrl == null || photoUrl!.isEmpty)
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDriver ? 'Modo Conductor' : 'Modo Pasajero',
                        style: TextStyle(
                          color: isDriver
                              ? const Color(0xFFC4871F)
                              : const Color(0xFF1E5B7A),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isDriver)
                        const Text(
                          'Requiere licencia vigente y terminos aceptados',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6A7783),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (photoUrl == null || photoUrl!.isEmpty)
              const Text(
                'Tip: agrega foto de perfil en editar perfil para generar mas confianza.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6A7783),
                ),
              ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8FB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD8E2EA)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_walk,
                    size: 18,
                    color: !isDriver
                        ? const Color(0xFF1E5B7A)
                        : const Color(0xFF8D99A6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDriver ? 'Conductor' : 'Pasajero',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Switch(
                    value: isDriver,
                    onChanged: (_) => onToggle(),
                    activeColor: const Color(0xFFC4871F),
                  ),
                  Icon(
                    Icons.drive_eta,
                    size: 18,
                    color: isDriver
                        ? const Color(0xFFC4871F)
                        : const Color(0xFF8D99A6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String balance;
  final int held;
  final VoidCallback onTopup;

  const _BalanceCard({
    required this.balance,
    required this.held,
    required this.onTopup,
  });

  @override
  Widget build(BuildContext context) {
    final heldStr = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    ).format(held);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E5B7A), Color(0xFF2A6C8E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo disponible',
            style: TextStyle(fontSize: 13, color: Color(0xFFD7E8F2)),
          ),
          const SizedBox(height: 2),
          Text(
            balance,
            style: const TextStyle(
              fontSize: 30,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (held > 0)
            Text(
              '$heldStr en reservas activas',
              style: const TextStyle(fontSize: 12, color: Color(0xFFD7E8F2)),
            ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onTopup,
            icon: const Icon(Icons.add),
            label: const Text('Recargar billetera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1E5B7A),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.88)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFE2EDF3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
