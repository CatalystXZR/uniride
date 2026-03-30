import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error_mapper.dart';
import '../models/enums.dart';
import '../models/user_profile.dart';
import '../models/wallet.dart';
import 'service_providers.dart';

class HomeState {
  final UserProfile? profile;
  final Wallet? wallet;
  final bool loading;
  final bool switchingRole;
  final String? errorMessage;

  const HomeState({
    this.profile,
    this.wallet,
    this.loading = true,
    this.switchingRole = false,
    this.errorMessage,
  });

  HomeState copyWith({
    UserProfile? profile,
    Wallet? wallet,
    bool? loading,
    bool? switchingRole,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HomeState(
      profile: profile ?? this.profile,
      wallet: wallet ?? this.wallet,
      loading: loading ?? this.loading,
      switchingRole: switchingRole ?? this.switchingRole,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier(this._ref) : super(const HomeState()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    final profileService = _ref.read(profileServiceProvider);
    final walletService = _ref.read(walletServiceProvider);
    try {
      final results = await Future.wait([
        profileService.getProfile(),
        walletService.getWallet(),
      ]);
      state = state.copyWith(
        profile: results[0] as UserProfile?,
        wallet: results[1] as Wallet?,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: AppErrorMapper.toMessage(
          e,
          fallback: 'No pudimos cargar tu inicio. Intenta nuevamente.',
        ),
      );
    }
  }

  Future<void> refresh() => load();

  Future<void> setRoleMode(RoleMode mode) async {
    state = state.copyWith(switchingRole: true);
    try {
      final profileService = _ref.read(profileServiceProvider);
      final updated = await profileService.setRoleMode(mode);
      state = state.copyWith(profile: updated, switchingRole: false);
    } catch (_) {
      state = state.copyWith(switchingRole: false);
      rethrow;
    }
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>(
  (ref) => HomeNotifier(ref),
);
