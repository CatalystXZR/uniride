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
import '../../models/enums.dart';
import '../../models/user_profile.dart';
import '../../models/wallet.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/wallet_service.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
  }

  Future<void> _toggleRole() async {
    if (_profile == null) return;
    final newMode = _profile!.roleMode == RoleMode.driver
        ? RoleMode.passenger
        : RoleMode.driver;
    final updated = await _profileService.setRoleMode(newMode);
    if (mounted) setState(() => _profile = updated);
  }

  bool get _isDriver => _profile?.roleMode == RoleMode.driver;

  @override
  Widget build(BuildContext context) {
    final balanceStr = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    ).format(_wallet?.balanceAvailable ?? 0);

    return Scaffold(
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
                padding: const EdgeInsets.all(20),
                children: [
                  // Role switch card
                  _RoleSwitchCard(
                    isDriver: _isDriver,
                    name: _profile?.fullName ?? 'Usuario',
                    onToggle: _toggleRole,
                  ),
                  const SizedBox(height: 16),

                  // Balance card
                  _BalanceCard(
                    balance: balanceStr,
                    held: _wallet?.balanceHeld ?? 0,
                    onTopup: () => context.push('/wallet'),
                  ),
                  const SizedBox(height: 24),

                  // Main actions
                  if (_isDriver) ...[
                    _ActionButton(
                      icon: Icons.add_circle_outline,
                      label: 'Publicar turno',
                      color: Theme.of(context).colorScheme.primary,
                      onTap: () => context.push('/publish'),
                    ),
                    const SizedBox(height: 12),
                    _ActionButton(
                      icon: Icons.directions_car_outlined,
                      label: 'Mis turnos publicados',
                      color: Colors.blueGrey,
                      onTap: () => context.push('/driver-rides'),
                    ),
                  ] else ...[
                    _ActionButton(
                      icon: Icons.search,
                      label: 'Buscar turno',
                      color: Theme.of(context).colorScheme.primary,
                      onTap: () => context.push('/search'),
                    ),
                    const SizedBox(height: 12),
                    _ActionButton(
                      icon: Icons.confirmation_num_outlined,
                      label: 'Mis reservas',
                      color: Colors.blueGrey,
                      onTap: () => context.push('/my-rides'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _RoleSwitchCard extends StatelessWidget {
  final bool isDriver;
  final String name;
  final VoidCallback onToggle;

  const _RoleSwitchCard({
    required this.isDriver,
    required this.name,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(
                    isDriver ? 'Modo Conductor' : 'Modo Pasajero',
                    style: TextStyle(
                        color: isDriver ? Colors.orange : Colors.blue,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.directions_walk,
                  size: 18,
                  color: !isDriver ? Colors.blue : Colors.grey,
                ),
                Switch(
                  value: isDriver,
                  onChanged: (_) => onToggle(),
                  activeColor: Colors.orange,
                ),
                Icon(
                  Icons.drive_eta,
                  size: 18,
                  color: isDriver ? Colors.orange : Colors.grey,
                ),
              ],
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

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Saldo disponible',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
              balance,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800),
            ),
            if (held > 0)
              Text('$heldStr en reservas activas',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTopup,
                icon: const Icon(Icons.add),
                label: const Text('Recargar billetera'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}
