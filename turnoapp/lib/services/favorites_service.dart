import '../core/supabase_client.dart';
import '../models/favorite_user.dart';
import '../models/enums.dart';

class FavoritesService {
  final _client = SupabaseConfig.client;

  Future<bool> toggleFavorite(String targetUserId) async {
    final result = await _client.rpc('toggle_favorite_user', params: {
      'p_target_user_id': targetUserId,
    });
    return result == true;
  }

  Future<List<FavoriteUser>> getMyFavorites({
    RoleMode? roleFilter,
    int limit = 100,
  }) async {
    final result = await _client.rpc('list_my_favorites', params: {
      'p_role_filter': roleFilter == null
          ? null
          : (roleFilter == RoleMode.driver ? 'driver' : 'passenger'),
      'p_limit': limit,
    });
    if (result is! List) return const [];
    return result
        .map((e) => FavoriteUser.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<bool> isFavorite(String targetUserId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await _client
        .from('user_favorites')
        .select('favorite_user_id')
        .eq('user_id', uid)
        .eq('favorite_user_id', targetUserId)
        .maybeSingle();
    return row != null;
  }
}
