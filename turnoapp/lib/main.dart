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
import 'package:intl/date_symbol_data_local.dart';
import 'core/supabase_client.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Spanish locale data for DateFormat('...', 'es') calls throughout the app.
  await initializeDateFormatting('es', null);

  await SupabaseConfig.initialize();
  runApp(const TurnoApp());
}
