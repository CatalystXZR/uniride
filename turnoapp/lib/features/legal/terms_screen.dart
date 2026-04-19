import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../shared/widgets/decorative_background.dart';
import '../../services/legal_service.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const service = LegalService();
    final terms = service.currentTerms;

    return Scaffold(
      appBar: AppBar(title: const Text('Terminos y condiciones')),
      body: DecorativeBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      terms.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version ${terms.version}',
                      style: const TextStyle(color: AppTheme.subtle),
                    ),
                    const SizedBox(height: 14),
                    ...terms.bullets.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Escudo legal y seguridad',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'TurnoApp actua como intermediario tecnologico. Los usuarios son responsables de la coordinacion presencial, estado del vehiculo y cumplimiento de la normativa vial chilena.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Boton de panico: llama al 133 de Carabineros de Chile en emergencias.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacidad y soporte',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.push('/privacy'),
                          icon: const Icon(Icons.privacy_tip_outlined),
                          label: const Text('Politica de privacidad'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/support'),
                          icon: const Icon(Icons.support_agent_outlined),
                          label: const Text('Centro de soporte'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver'),
            ),
            const SizedBox(height: 8),
            Text(
              'Telefono de emergencia: ${AppConstants.emergencyPhoneCL}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
