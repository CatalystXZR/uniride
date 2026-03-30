import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/booking_service.dart';
import '../services/profile_service.dart';
import '../services/reference_data_service.dart';
import '../services/ride_service.dart';
import '../services/wallet_service.dart';
import '../services/withdrawal_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(),
);
final walletServiceProvider = Provider<WalletService>((ref) => WalletService());
final withdrawalServiceProvider = Provider<WithdrawalService>(
  (ref) => WithdrawalService(),
);
final rideServiceProvider = Provider<RideService>((ref) => RideService());
final bookingServiceProvider = Provider<BookingService>(
  (ref) => BookingService(),
);
final referenceDataServiceProvider = Provider<ReferenceDataService>(
  (ref) => ReferenceDataService(),
);
