import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../models/wallet.dart';
import 'service_providers.dart';

class WalletState {
  final Wallet? wallet;
  final List<Transaction> transactions;
  final bool loading;
  final bool topupLoading;

  const WalletState({
    this.wallet,
    this.transactions = const [],
    this.loading = true,
    this.topupLoading = false,
  });

  WalletState copyWith({
    Wallet? wallet,
    List<Transaction>? transactions,
    bool? loading,
    bool? topupLoading,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
      loading: loading ?? this.loading,
      topupLoading: topupLoading ?? this.topupLoading,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier(this._ref) : super(const WalletState()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true);
    final walletService = _ref.read(walletServiceProvider);
    final results = await Future.wait([
      walletService.getWallet(),
      walletService.getTransactions(),
    ]);
    state = state.copyWith(
      wallet: results[0] as Wallet?,
      transactions: results[1] as List<Transaction>,
      loading: false,
    );
  }

  Future<String> createTopupIntent(int amount) async {
    state = state.copyWith(topupLoading: true);
    try {
      final walletService = _ref.read(walletServiceProvider);
      return await walletService.createTopupIntent(amount);
    } finally {
      state = state.copyWith(topupLoading: false);
    }
  }

  Future<void> requestWithdrawal(int amount) async {
    final withdrawalService = _ref.read(withdrawalServiceProvider);
    await withdrawalService.requestWithdrawal(amount);
    await load();
  }

  /// Sandbox topup - adds balance directly without external payment.
  Future<void> sandboxTopup(int amount) async {
    state = state.copyWith(topupLoading: true);
    try {
      final walletService = _ref.read(walletServiceProvider);
      await walletService.sandboxTopup(amount);
      await load();
    } finally {
      state = state.copyWith(topupLoading: false);
    }
  }

  /// Sandbox withdrawal - requests payout directly without external provider.
  Future<void> sandboxWithdraw(int amount) async {
    state = state.copyWith(topupLoading: true);
    try {
      final walletService = _ref.read(walletServiceProvider);
      await walletService.sandboxWithdraw(amount);
      await load();
    } finally {
      state = state.copyWith(topupLoading: false);
    }
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((
  ref,
) {
  return WalletNotifier(ref);
});
