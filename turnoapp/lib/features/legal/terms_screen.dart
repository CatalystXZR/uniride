import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/legal_service.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const service = LegalService();
    final terms = service.currentTerms;

    return Scaffold(
      appBar: AppBar(title: const Text('Terminos y condiciones')),
      body: ListView(
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
                    style: const TextStyle(color: Color(0xFF6A7783)),
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
                              color: Color(0xFF1E5B7A),
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
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver'),
          ),
          const SizedBox(height: 8),
          Text(
            'Telefono de emergencia: ${AppConstants.emergencyPhoneCL}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8A2F43),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
