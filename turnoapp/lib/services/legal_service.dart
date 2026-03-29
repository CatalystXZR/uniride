import '../core/constants.dart';
import '../models/legal_terms.dart';

class LegalService {
  const LegalService();

  LegalTerms get currentTerms => LegalTerms(
        version: AppConstants.termsVersion,
        title: 'Terminos y condiciones TurnoApp',
        bullets: const [
          'TurnoApp es una plataforma intermediaria entre conductores y pasajeros.',
          'Tolerancia cero para conductas de riesgo o violencia.',
          'Debes esperar al menos 10 minutos en el punto de encuentro antes de reportar no-show.',
          'Cancelar a ultima hora o no llegar puede generar strikes y suspension.',
          'Con 2 strikes, el conductor y su vehiculo quedan suspendidos por 2 meses.',
          'En emergencia, usa el boton de panico y contacta al 133.',
        ],
      );
}
