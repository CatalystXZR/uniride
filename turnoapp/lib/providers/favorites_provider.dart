import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/favorite_user.dart';
import 'service_providers.dart';

class FavoritesState {
  final List<FavoriteUser> favorites;
  final bool loading;

  const FavoritesState({
    this.favorites = const [],
    this.loading = true,
  });

  FavoritesState copyWith({
    List<FavoriteUser>? favorites,
    bool? loading,
  }) {
    return FavoritesState(
      favorites: favorites ?? this.favorites,
      loading: loading ?? this.loading,
    );
  }
}

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  FavoritesNotifier(this._ref) : super(const FavoritesState()) {
    load();
  }

  final Ref _ref;

  Future<void> load({RoleMode? roleFilter}) async {
    state = state.copyWith(loading: true);
    final service = _ref.read(favoritesServiceProvider);
    final items = await service.getMyFavorites(roleFilter: roleFilter);
    state = state.copyWith(favorites: items, loading: false);
  }

  Future<bool> toggleFavorite(String targetUserId) async {
    final service = _ref.read(favoritesServiceProvider);
    final isFav = await service.toggleFavorite(targetUserId);
    await load();
    return isFav;
  }

  Future<bool> isFavorite(String targetUserId) {
    final service = _ref.read(favoritesServiceProvider);
    return service.isFavorite(targetUserId);
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>(
  (ref) => FavoritesNotifier(ref),
);
