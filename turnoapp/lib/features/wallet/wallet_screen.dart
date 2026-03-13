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
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../models/wallet.dart';
import '../../models/transaction.dart';
import '../../services/wallet_service.dart';
import '../../services/withdrawal_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/loading_overlay.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _walletService = WalletService();
  final _withdrawalService = WithdrawalService();

  Wallet? _wallet;
  List<Transaction> _transactions = [];
  bool _loading = true;
  bool _topupLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _walletService.getWallet(),
      _walletService.getTransactions(),
    ]);
    if (mounted) {
      setState(() {
        _wallet = results[0] as Wallet?;
        _transactions = results[1] as List<Transaction>;
        _loading = false;
      });
    }
  }

  Future<void> _startTopup() async {
    final amounts = [2000, 4000, 6000, 10000, 20000];
    int? selected = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Selecciona monto a recargar',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: amounts.map((a) {
                final fmt = NumberFormat.currency(
                  locale: 'es_CL',
                  symbol: '\$',
                  decimalDigits: 0,
                ).format(a);
                return ActionChip(
                  label: Text(fmt,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () => Navigator.pop(ctx, a),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    setState(() => _topupLoading = true);
    try {
      final initPoint = await _walletService.createTopupIntent(selected);
      final uri = Uri.parse(initPoint);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) AppSnackbar.show(context, 'No se pudo abrir el pago', isError: true);
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _topupLoading = false);
    }
  }

  Future<void> _requestWithdrawal() async {
    final balance = _wallet?.balanceAvailable ?? 0;
    if (balance < AppConstants.minWithdrawalCLP) {
      AppSnackbar.show(
        context,
        'Necesitas al menos \$${AppConstants.minWithdrawalCLP} para retirar',
        isError: true,
      );
      return;
    }

    // Show a dialog with an amount input
    final amountController = TextEditingController(
      text: balance.toString(),
    );
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Solicitar retiro'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresa el monto a retirar (mín. \$${AppConstants.minWithdrawalCLP}, máx. \$$balance).',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto (CLP)',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null) return 'Ingresa un número válido';
                  if (n < AppConstants.minWithdrawalCLP) {
                    return 'Mínimo \$${AppConstants.minWithdrawalCLP}';
                  }
                  if (n > balance) return 'Supera tu saldo disponible';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Los retiros se procesan quincenalmente.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Solicitar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final amount = int.tryParse(amountController.text.trim()) ?? 0;
    amountController.dispose();

    try {
      await _withdrawalService.requestWithdrawal(amount);
      if (mounted) {
        AppSnackbar.show(context, 'Solicitud de retiro enviada');
        _load();
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceFmt = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    ).format(_wallet?.balanceAvailable ?? 0);

    final heldFmt = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    ).format(_wallet?.balanceHeld ?? 0);

    return LoadingOverlay(
      isLoading: _topupLoading,
      message: 'Abriendo Mercado Pago...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Billetera'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
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
                    // Balance card
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Saldo disponible',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text(
                              balanceFmt,
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800),
                            ),
                            if ((_wallet?.balanceHeld ?? 0) > 0) ...[
                              const SizedBox(height: 4),
                              Text('$heldFmt en reservas activas',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54)),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _startTopup,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Recargar'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _requestWithdrawal,
                                    icon: const Icon(Icons.arrow_downward),
                                    label: const Text('Retirar'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_transactions.isNotEmpty) ...[
                      const Text('Historial',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 8),
                      ..._transactions
                          .map((tx) => _TransactionTile(tx: tx))
                          .toList(),
                    ] else
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Sin movimientos aún',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final amtFmt = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    ).format(tx.amount.abs());
    final dateFmt =
        DateFormat('d MMM, HH:mm', 'es').format(tx.createdAt.toLocal());
    final isCredit = tx.amount > 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            isCredit ? Colors.green.shade50 : Colors.red.shade50,
        child: Icon(
          isCredit ? Icons.arrow_downward : Icons.arrow_upward,
          color: isCredit ? Colors.green : Colors.redAccent,
          size: 18,
        ),
      ),
      title: Text(tx.typeLabel,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(dateFmt,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Text(
        '${isCredit ? '+' : '-'}$amtFmt',
        style: TextStyle(
          color: isCredit ? Colors.green : Colors.redAccent,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}
