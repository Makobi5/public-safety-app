// lib/service/notification_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Add this import

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  Timer? _notificationTimer;
  DateTime? _lastCheckedTime;
  final Map<String, bool> _processedIncidents = {};

  // Stream controller for real-time notifications
  final _notificationStreamController = StreamController<NotificationModel>.broadcast();
  Stream<NotificationModel> get notificationStream => _notificationStreamController.stream;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal() {
    // Initialize the last checked time when service is created
    _lastCheckedTime = DateTime.now();
      loadProcessedIncidentsState();
  }

  // Get Supabase client
  final supabase = Supabase.instance.client;

  // Create a notification
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    String? priority,
    String? incidentId,
  }) async {
    try {
      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'is_read': false,
        'priority': priority ?? 'Medium',
        'incident_id': incidentId,
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
  Future<void> loadProcessedIncidentsState() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? storedData = prefs.getString('processed_incidents');
    if (storedData != null) {
      final Map<String, dynamic> decoded = jsonDecode(storedData);
      _processedIncidents.clear();
      decoded.forEach((key, value) {
        _processedIncidents[key] = value;
      });
      print('Loaded ${_processedIncidents.length} processed incidents from storage');
    }
  } catch (e) {
    print('Error loading processed incidents state: $e');
  }
}

Future<void> saveProcessedIncidentsState() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    // Convert _processedIncidents to a simple Map<String, dynamic> for storage
    final Map<String, dynamic> storableMap = {};
    _processedIncidents.forEach((key, value) {
      storableMap[key] = value;
    });
    await prefs.setString('processed_incidents', jsonEncode(storableMap));
    print('Saved ${_processedIncidents.length} processed incidents to storage');
  } catch (e) {
    print('Error saving processed incidents state: $e');
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
Future<void> processNewIncident(Map<String, dynamic> incident) async {
  try {
    final String incidentId = incident['id'].toString();
    if (isIncidentProcessed(incidentId)) {
      debugPrint('Incident $incidentId already processed');
      return;
    }

    final String incidentType = incident['incident_type']?.toString() ?? 'Unknown Incident';
    final String district = incident['district']?.toString() ?? 'Unknown Location';
    final String priority = getIncidentPriority(incidentType);
    final String? status = incident['status']?.toString();

    // Validate required fields
    if (incidentId.isEmpty) {
      throw Exception('Invalid incident ID');
    }

    // Get all admin users (with error handling)
    final adminsResponse = await supabase
        .from('user_profiles')
        .select('user_id')
        .eq('role', 'admin');

    if (adminsResponse == null || adminsResponse.isEmpty) {
      debugPrint('No admin users found');
      return;
    }

    // Create notifications for all admins
    final notifications = adminsResponse.map<Future>((admin) async {
      final String userId = admin['user_id'].toString();
      if (userId.isEmpty) return;
      
      await createNotification(
        userId: userId,
        title: 'New ${priority == 'High' ? '⚠️ ' : ''}$incidentType',
        message: 'Reported in $district\nStatus: ${status ?? 'Pending'}',
        priority: priority,
        incidentId: incidentId,
      );
    }).toList();

    // Process all notifications in parallel
    await Future.wait(notifications);

    // Mark incident as processed after successful notification
    markIncidentAsProcessed(incidentId);
    await saveProcessedIncidentsState();

    debugPrint('Successfully processed incident $incidentId');
  } catch (e, stackTrace) {
    debugPrint('Error processing incident: $e');
    debugPrint('Stack trace: $stackTrace');
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

  // Check for new incidents
Future<List<Map<String, dynamic>>> checkForNewIncidents() async {
  try {
    // Initialize last checked time if not set (check last 5 minutes)
    _lastCheckedTime ??= DateTime.now().subtract(const Duration(minutes: 5));
    
    // Query for reports created after the last check time
    final response = await supabase
        .from('incidents')
        .select('''
          id,
          incident_type,
          district,
          created_at,
          status,
          description
        ''')
        .gt('created_at', _lastCheckedTime!.toIso8601String())
        .order('created_at', ascending: false)
        .limit(50); // Limit to prevent overload

    // Update last checked time immediately after successful query
    _lastCheckedTime = DateTime.now();
    
    if (response != null && response is List) {
      final newReports = response.cast<Map<String, dynamic>>();
      
      // Filter out processed incidents and mark new ones
      final newIncidents = <Map<String, dynamic>>[];
      
      for (final report in newReports) {
        final reportId = report['id'].toString();
        if (!_processedIncidents.containsKey(reportId)) {
          // Add priority classification
          report['priority'] = getIncidentPriority(report['incident_type']);
          newIncidents.add(report);
          _processedIncidents[reportId] = true;
        }
      }

      // Save state if we found new incidents
      if (newIncidents.isNotEmpty) {
        await saveProcessedIncidentsState();
      }
      
      return newIncidents;
    }
    
    return [];
  } catch (e) {
    // Log error but don't crash - we'll try again next check
    debugPrint('Error checking for new incidents: $e');
    // Reset last checked time to try again next time
    _lastCheckedTime = DateTime.now().subtract(const Duration(minutes: 1));
    return [];
  }
}

  // Start real-time incident monitoring
  void startIncidentMonitoring({
    Duration interval = const Duration(seconds: 15),
    required Function(List<Map<String, dynamic>>) onNewIncidents,
  }) {
    // Initialize last checked time if not already set
    _lastCheckedTime ??= DateTime.now();
    
    _notificationTimer = Timer.periodic(interval, (_) async {
      try {
        final newIncidents = await checkForNewIncidents();
        if (newIncidents.isNotEmpty) {
          onNewIncidents(newIncidents);
        }
      } catch (e) {
        print('Error monitoring for incidents: $e');
      }
    });
  }

  void stopIncidentMonitoring() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
  }
  
  // Check if an incident has been processed
  bool isIncidentProcessed(String incidentId) {
    return _processedIncidents.containsKey(incidentId) && _processedIncidents[incidentId] == true;
  }
  
// Manually mark an incident as processed
void markIncidentAsProcessed(String incidentId) {
  _processedIncidents[incidentId] = true;
  saveProcessedIncidentsState(); // Save after updating
}
  
  // Reset tracking for an incident (useful for testing)
void resetIncidentTracking(String incidentId) {
  _processedIncidents.remove(incidentId);
  saveProcessedIncidentsState();
}
  
  // Reset all incident tracking
 void resetAllIncidentTracking() {
  _processedIncidents.clear();
  _lastCheckedTime = DateTime.now();
  saveProcessedIncidentsState();
}
  
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
          final listResponse = response as List;
          if (listResponse.isNotEmpty) {
            return listResponse[0]['count'] ?? 0;
          }
        } else if (response is int) {
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
        priority: 'Medium',
        incidentId: incidentId,
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
        priority: 'High',
        incidentId: incidentId,
      );
    } catch (e) {
      print('Error creating action notification: $e');
      rethrow;
    }
  }
  
  // Method to determine incident priority based on type
  String getIncidentPriority(String? incidentType) {
    if (incidentType == null) return 'Low';
    
    // Critical incidents (High priority)
    final highPriorityIncidents = [
      'Fire outbreak',
      'Accident',
      'Murder',
      'Kidnap',
      'Rape',
      'Defilement',
      'Robbery',
    ];
    
    // Medium priority incidents
    final mediumPriorityIncidents = [
      'Theft',
      'Sexual Assault',
      'Domestic Violence',
      'Drug Abuse',
      'Fraud and financial crimes',
      'Cyber Crime',
    ];
    
    if (highPriorityIncidents.contains(incidentType)) {
      return 'High';
    } else if (mediumPriorityIncidents.contains(incidentType)) {
      return 'Medium';
    } else {
      return 'Low';
    }
  }
  
  // Cleanup resources
  void dispose() {
    stopIncidentMonitoring();
    _notificationStreamController.close();
  }
}