import 'enums.dart';

class FavoriteUser {
  final String userId;
  final String? fullName;
  final RoleMode roleMode;
  final double ratingAvg;
  final int ratingCount;
  final String? profilePhotoUrl;
  final String? vehicleModel;
  final String? vehiclePlate;
  final DateTime createdAt;

  const FavoriteUser({
    required this.userId,
    this.fullName,
    required this.roleMode,
    required this.ratingAvg,
    required this.ratingCount,
    this.profilePhotoUrl,
    this.vehicleModel,
    this.vehiclePlate,
    required this.createdAt,
  });

  factory FavoriteUser.fromJson(Map<String, dynamic> json) {
    final mode = (json['role_mode'] as String?) == 'driver'
        ? RoleMode.driver
        : RoleMode.passenger;
    return FavoriteUser(
      userId: json['favorite_user_id'] as String,
      fullName: json['full_name'] as String?,
      roleMode: mode,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 5,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
