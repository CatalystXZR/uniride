import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../models/enums.dart';
import '../../providers/favorites_provider.dart';
import '../../shared/widgets/decorative_background.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  RoleMode? _filter;

  Future<void> _reload() {
    return ref.read(favoritesProvider.notifier).load(roleFilter: _filter);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
      ),
      body: DecorativeBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Todos'),
                      selected: _filter == null,
                      onSelected: (_) {
                        setState(() => _filter = null);
                        _reload();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Conductores'),
                      selected: _filter == RoleMode.driver,
                      onSelected: (_) {
                        setState(() => _filter = RoleMode.driver);
                        _reload();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Pasajeros'),
                      selected: _filter == RoleMode.passenger,
                      onSelected: (_) {
                        setState(() => _filter = RoleMode.passenger);
                        _reload();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : state.favorites.isEmpty
                      ? const _EmptyState()
                      : RefreshIndicator(
                          onRefresh: _reload,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                            itemCount: state.favorites.length,
                            itemBuilder: (context, index) {
                              final item = state.favorites[index];
                              final isDriver = item.roleMode == RoleMode.driver;
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    backgroundImage: (item.profilePhotoUrl !=
                                                null &&
                                            item.profilePhotoUrl!.isNotEmpty)
                                        ? NetworkImage(item.profilePhotoUrl!)
                                        : null,
                                    child: (item.profilePhotoUrl == null ||
                                            item.profilePhotoUrl!.isEmpty)
                                        ? Text(
                                            _initial(item.fullName),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    item.fullName ?? 'Usuario',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isDriver ? 'Conductor' : 'Pasajero',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.subtle,
                                        ),
                                      ),
                                      Text(
                                        'Rating ${item.ratingAvg.toStringAsFixed(2)} (${item.ratingCount})',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.subtle,
                                        ),
                                      ),
                                      if ((item.vehicleModel ?? '')
                                              .isNotEmpty ||
                                          (item.vehiclePlate ?? '').isNotEmpty)
                                        Text(
                                          'Auto ${item.vehicleModel ?? '-'} · Patente ${item.vehiclePlate ?? '-'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.subtle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: const Icon(
                                    Icons.favorite,
                                    color: Color(0xFFFF5A7A),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

String _initial(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return '?';
  return raw.substring(0, 1).toUpperCase();
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          'Aun no agregas usuarios a favoritos.\nDesde detalle de turno o reservas puedes guardarlos.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.subtle),
        ),
      ),
    );
  }
}
