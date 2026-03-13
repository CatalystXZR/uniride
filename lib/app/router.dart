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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/profile_switch/home_screen.dart';
import '../features/rides_publish/publish_ride_screen.dart';
import '../features/rides_search/search_rides_screen.dart';
import '../features/booking/booking_screen.dart';
import '../features/wallet/wallet_screen.dart';
import '../features/my_rides/my_rides_screen.dart';
import '../features/my_rides/driver_rides_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  redirect: (BuildContext context, GoRouterState state) {
    final session = SupabaseConfig.client.auth.currentSession;
    final isAuth = session != null;
    final isOnAuth = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    if (!isAuth && !isOnAuth) return '/login';
    if (isAuth && isOnAuth) return '/home';
    return null;
  },
  refreshListenable: GoRouterRefreshStream(
    SupabaseConfig.client.auth.onAuthStateChange,
  ),
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(
      path: '/publish',
      builder: (_, __) => const PublishRideScreen(),
    ),
    GoRoute(
      path: '/search',
      builder: (_, __) => const SearchRidesScreen(),
    ),
    GoRoute(
      path: '/booking/:rideId',
      builder: (_, state) =>
          BookingScreen(rideId: state.pathParameters['rideId']!),
    ),
    GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
    GoRoute(path: '/my-rides', builder: (_, __) => const MyRidesScreen()),
    GoRoute(path: '/driver-rides', builder: (_, __) => const DriverRidesScreen()),
  ],
);

/// Converts a Supabase auth stream to a [Listenable] for GoRouter.
/// Properly cancels the subscription on dispose to prevent memory leaks.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
