import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';

class InAppNotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;

  const InAppNotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
  });

  InAppNotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
  }) {
    return InAppNotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class InAppNotificationNotifier extends StateNotifier<InAppNotificationState> {
  InAppNotificationNotifier() : super(const InAppNotificationState());

  void add({
    required String title,
    required String body,
    String? bookingId,
    String? rideId,
    int? notifId,
  }) {
    final id = (notifId ?? Random().nextInt(0x7FFFFFFF)).toString();
    final notification = AppNotification(
      id: id,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      bookingId: bookingId,
      rideId: rideId,
    );

    final updated = [notification, ...state.notifications];
    if (updated.length > 100) {
      updated.removeRange(100, updated.length);
    }

    state = state.copyWith(
      notifications: updated,
      unreadCount: state.unreadCount + 1,
    );
  }

  void markAsRead(String id) {
    final updated = state.notifications.map((n) {
      if (n.id == id && !n.isRead) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    final unread = updated.where((n) => !n.isRead).length;
    state = state.copyWith(notifications: updated, unreadCount: unread);
  }

  void markAllAsRead() {
    final updated =
        state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updated, unreadCount: 0);
  }

  void clear() {
    state = const InAppNotificationState();
  }
}

final inAppNotificationProvider =
    StateNotifierProvider<InAppNotificationNotifier, InAppNotificationState>(
  (ref) => InAppNotificationNotifier(),
);
