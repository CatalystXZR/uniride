class UserReview {
  final String id;
  final String bookingId;
  final String rideId;
  final int stars;
  final String? comment;
  final DateTime createdAt;
  final String reviewerId;
  final String reviewerRole;
  final String? reviewerName;
  final String? reviewerPhotoUrl;
  final double reviewerRatingAvg;
  final int reviewerRatingCount;

  const UserReview({
    required this.id,
    required this.bookingId,
    required this.rideId,
    required this.stars,
    this.comment,
    required this.createdAt,
    required this.reviewerId,
    required this.reviewerRole,
    this.reviewerName,
    this.reviewerPhotoUrl,
    required this.reviewerRatingAvg,
    required this.reviewerRatingCount,
  });

  factory UserReview.fromJson(Map<String, dynamic> json) {
    return UserReview(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      rideId: json['ride_id'] as String,
      stars: (json['stars'] as num?)?.toInt() ?? 5,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      reviewerId: json['reviewer_id'] as String,
      reviewerRole: (json['reviewer_role'] as String?) ?? 'passenger',
      reviewerName: json['reviewer_name'] as String?,
      reviewerPhotoUrl: json['reviewer_photo_url'] as String?,
      reviewerRatingAvg: (json['reviewer_rating_avg'] as num?)?.toDouble() ?? 5,
      reviewerRatingCount:
          (json['reviewer_rating_count'] as num?)?.toInt() ?? 0,
    );
  }
}
