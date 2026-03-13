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

/// App-wide constants for TurnoApp MVP.
class AppConstants {
  AppConstants._();

  // Pricing
  static const int seatPriceCLP = 2000;
  static const int minWithdrawalCLP = 20000;

  // Allowed communes
  static const List<String> allowedCommunes = [
    'Chicureo',
    'Lo Barnechea',
    'Providencia',
    'Vitacura',
    'La Reina',
    'Buin',
  ];

  // Universities
  static const List<Map<String, String>> universities = [
    {'code': 'UDD', 'name': 'Universidad del Desarrollo'},
    {'code': 'UANDES', 'name': 'Universidad de los Andes'},
    {'code': 'PUC', 'name': 'Pontificia Universidad Católica'},
    {'code': 'UAI', 'name': 'Universidad Adolfo Ibáñez'},
    {'code': 'UNAB', 'name': 'Universidad Andrés Bello'},
  ];

  // Platform fee (configurable, 0 for MVP)
  static const int platformFeeCLP = 0;
}
