class AppErrorMapper {
  AppErrorMapper._();

  static String toMessage(
    Object error, {
    String fallback = 'No pudimos completar la operacion. Intenta nuevamente.',
  }) {
    final raw = error.toString();
    final text = raw.toLowerCase();

    if (text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('connection closed') ||
        text.contains('timed out')) {
      return 'No hay conexion a internet. Revisa tu red e intentalo otra vez.';
    }

    if (text.contains('invalid login credentials') ||
        text.contains('invalid_credentials')) {
      return 'Correo o contrasena incorrectos.';
    }

    if (text.contains('user already registered') ||
        text.contains('already registered')) {
      return 'Este correo ya tiene una cuenta. Inicia sesion.';
    }

    if (text.contains('email not confirmed')) {
      return 'Debes confirmar tu correo antes de ingresar.';
    }

    if (text.contains('supabase_not_configured') ||
        text.contains('your_project.supabase.co') ||
        text.contains('your_anon_key')) {
      return 'Falta configurar SUPABASE_URL y SUPABASE_ANON_KEY en la app.';
    }

    if (text.contains('signup is disabled')) {
      return 'El registro esta deshabilitado en Supabase. Activalo en Auth > Providers > Email.';
    }

    if (text.contains('database error saving new user')) {
      return 'No se pudo crear el usuario por una configuracion de base de datos (trigger/policies).';
    }

    if (text.contains('permission denied') ||
        text.contains('row-level security')) {
      return 'Tu proyecto de Supabase no permite leer referencias publicas (universidades/campus). Ejecuta migraciones 06 y 07.';
    }

    if (text.contains('user not allowed')) {
      return 'No tienes permitido registrarte con este correo.';
    }

    if (text.contains('p0001') || text.contains('unauthorized')) {
      return 'Tu sesion expiro. Vuelve a iniciar sesion.';
    }

    if (text.contains('p0002') || text.contains('ride unavailable')) {
      return 'Este turno ya no esta disponible.';
    }

    if (text.contains('p0003') || text.contains('already booked')) {
      return 'Ya tienes una reserva en este turno.';
    }

    if (text.contains('p0004') || text.contains('insufficient balance')) {
      return 'Saldo insuficiente. Recarga tu billetera para continuar.';
    }

    if (text.contains('p0005') || text.contains('already processed')) {
      return 'La reserva ya fue procesada.';
    }

    if (text.contains('p0006') || text.contains('forbidden')) {
      return 'No tienes permisos para realizar esta accion.';
    }

    if (text.contains('p0008') || text.contains('wait_time_not_elapsed')) {
      return 'Aun no pasan los 10 minutos de espera. Intenta reportar mas tarde.';
    }

    if (text.contains('terms_not_accepted')) {
      return 'Debes aceptar terminos y condiciones para continuar.';
    }

    if (text.contains('driver_license_required')) {
      return 'Debes declarar licencia vigente para activar acciones de conductor.';
    }

    if (text.contains('users_profile_driver_vehicle_required_ck')) {
      return 'Para ser conductor debes ingresar marca, modelo, version, puertas, carroceria y patente.';
    }

    if (text.contains('minimum amount')) {
      return 'El monto minimo permitido es de \$2.000 CLP.';
    }

    if (text.contains('maximum amount')) {
      return 'El monto maximo por recarga es de \$200.000 CLP.';
    }

    if (text.contains('payment provider error')) {
      return 'El proveedor de pagos no respondio. Intenta nuevamente.';
    }

    return fallback;
  }
}
