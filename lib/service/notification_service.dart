// lib/service/notification_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  Timer? _notificationTimer;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  // Get Supabase client
  final supabase = Supabase.instance.client;

  // Create a notification
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
  }) async {
    try {
      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error creating notification: $e');
      rethrow;
    }
  }

  // Get user notifications
  Future<List<NotificationModel>> getUserNotifications(String userId) async {
    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (response != null && response is List) {
        return response
            .map((json) => NotificationModel.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId);
    } catch (e) {
      print('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  // Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      print('Error deleting notification: $e');
      rethrow;
    }
  }

  // Listen for notifications using polling instead of real-time subscriptions
  void startNotificationPolling(
    String userId,
    void Function(NotificationModel) onNotification,
    {Duration interval = const Duration(seconds: 10)}
  ) {
    DateTime lastChecked = DateTime.now();
    
    _notificationTimer = Timer.periodic(interval, (_) async {
      try {
        final response = await supabase
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .eq('is_read', false)
            .gt('created_at', lastChecked.toIso8601String())
            .order('created_at', ascending: false);
        
        lastChecked = DateTime.now();
        
        if (response != null && response is List && response.isNotEmpty) {
          for (final item in response) {
            try {
              final notification = NotificationModel.fromJson(item);
              onNotification(notification);
            } catch (e) {
              print('Error processing notification: $e');
            }
          }
        }
      } catch (e) {
        print('Error polling for notifications: $e');
      }
    });
  }

  void stopNotificationPolling() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
  }
  
  // Note: Keeping the original method (commented out) for reference
  /*
  // Listen for real-time notifications
  RealtimeChannel subscribeToUserNotifications(
    String userId,
    void Function(NotificationModel) onNotification,
  ) {
    final channel = supabase
        .channel('public:notifications:user_id=eq.$userId')
        .on(
          RealtimeListenTypes.postgresChanges,
          ChannelFilter(
            event: 'INSERT',
            schema: 'public',
            table: 'notifications',
            filter: 'user_id=eq.$userId',
          ),
          (payload, [ref]) {
            final notification = NotificationModel.fromJson(payload['new']);
            onNotification(notification);
          },
        )
        .subscribe();

    return channel;
  }
  */
  
  // Get unread notification count
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await supabase
          .from('notifications')
          .count()
          .eq('user_id', userId)
          .eq('is_read', false);
      
  if (response != null) {
  if (response is List) {
    // Create a local variable of type List to ensure type safety
    final listResponse = response as List;
    if (listResponse.isNotEmpty) {
      return listResponse[0]['count'] ?? 0;
    }
  } else if (response is int) {
    // If response is already an integer (in newer Supabase versions)
    return response;
  }
}
      return 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }
  
  // Create case update notification
  Future<void> createCaseUpdateNotification({
    required String userId,
    required String incidentType,
    required String status,
    required String incidentId,
  }) async {
    try {
      await createNotification(
        userId: userId,
        title: 'Case Status Updated',
        message: 'Your case "$incidentType" has been updated to: $status. Tap to view details.',
      );
    } catch (e) {
      print('Error creating case update notification: $e');
      rethrow;
    }
  }
  
  // Create action notification
  Future<void> createActionNotification({
    required String userId,
    required String incidentType,
    required String action,
    required String incidentId,
  }) async {
    try {
      await createNotification(
        userId: userId,
        title: 'Action Taken on Your Case',
        message: 'Admin action "$action" has been taken on your case: "$incidentType". Tap to view details.',
      );
    } catch (e) {
      print('Error creating action notification: $e');
      rethrow;
    }
  }
}