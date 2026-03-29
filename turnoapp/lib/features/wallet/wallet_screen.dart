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
import '../../core/error_mapper.dart';
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
    try {
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
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackbar.show(
          context,
          AppErrorMapper.toMessage(
            e,
            fallback: 'No pudimos cargar tu billetera.',
          ),
          isError: true,
        );
      }
    }
  }

  Future<void> _startTopup() async {
    int? selected = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Selecciona monto a recargar',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Recarga segura con Mercado Pago.',
              style: TextStyle(color: Color(0xFF5F6E7C), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AppConstants.quickTopupAmountsCLP.map((a) {
                final fmt = NumberFormat.currency(
                  locale: 'es_CL',
                  symbol: '\$',
                  decimalDigits: 0,
                ).format(a);
                return ActionChip(
                  side: const BorderSide(color: Color(0xFFD6E1EA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  label: Text(
                    fmt,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
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
        if (mounted) {
          AppSnackbar.show(context, 'No se pudo abrir el pago', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          AppErrorMapper.toMessage(
            e,
            fallback: 'No pudimos iniciar la recarga. Intenta nuevamente.',
          ),
          isError: true,
        );
      }
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
                    return 'Minimo \$${AppConstants.minWithdrawalCLP}';
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
      if (mounted) {
        AppSnackbar.show(
          context,
          AppErrorMapper.toMessage(
            e,
            fallback: 'No pudimos enviar la solicitud de retiro.',
          ),
          isError: true,
        );
      }
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    Container(
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
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFD7E8F2),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            balanceFmt,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if ((_wallet?.balanceHeld ?? 0) > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              '$heldFmt en reservas activas',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFD7E8F2),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _startTopup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF1E5B7A),
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Recargar'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _requestWithdrawal,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Color(0xFFD5E7F3),
                                    ),
                                  ),
                                  icon: const Icon(Icons.arrow_downward),
                                  label: const Text('Retirar'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    if (_transactions.isNotEmpty) ...[
                      Text(
                        'Historial',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ..._transactions
                          .map((tx) => _TransactionTile(tx: tx))
                          .toList(),
                    ] else
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Sin movimientos aun',
                            style: TextStyle(color: Color(0xFF6A7783)),
                          ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: CircleAvatar(
          backgroundColor:
              isCredit ? const Color(0xFFE9F6EE) : const Color(0xFFFCEDEF),
          child: Icon(
            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: isCredit ? const Color(0xFF1B734D) : const Color(0xFF8A2F43),
            size: 18,
          ),
        ),
        title: Text(tx.typeLabel,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(dateFmt,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6A7783))),
        trailing: Text(
          '${isCredit ? '+' : '-'}$amtFmt',
          style: TextStyle(
            color: isCredit ? const Color(0xFF1B734D) : const Color(0xFF8A2F43),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
