// lib/service/notification_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  Timer? _notificationTimer;
  DateTime? _lastCheckedTime;
  final Map<String, bool> _processedIncidents = {};
  Timer? _incidentTimer;
  
  // Stream controller for real-time notifications
  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal() {
    // Initialize the last checked time when service is created
    _lastCheckedTime = DateTime.now().subtract(const Duration(minutes: 5)); // Check last 5 minutes initially
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
      debugPrint('Creating notification for user $userId: $title');
      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'is_read': false,
        'priority': priority ?? 'Medium',
        'incident_id': incidentId,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('Notification created successfully');
    } catch (e) {
      debugPrint('Error creating notification: $e');
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
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  Future<void> loadProcessedIncidentsState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final processed = prefs.getString('processed_incidents');
      if (processed != null) {
        _processedIncidents.clear();
        final decoded = jsonDecode(processed) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          _processedIncidents[key] = value as bool;
        });
        debugPrint('Loaded ${_processedIncidents.length} processed incidents.');
      }
    } catch (e) {
      debugPrint('Error loading processed incidents state: $e');
      _processedIncidents.clear();
    }
  }

  Future<void> saveProcessedIncidentsState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('processed_incidents', jsonEncode(_processedIncidents));
    } catch (e) {
      debugPrint('Error saving processed incidents state: $e');
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
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  // Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      rethrow;
    }
  }

Future<List<Map<String, dynamic>>> checkForNewIncidents({String? stationId}) async {
  try {
    final last24h = DateTime.now().subtract(const Duration(hours: 24));
    
    debugPrint('Checking for ALL incidents in the last 24 hours');
    
    // Create query
    var query = supabase
        .from('incidents')
        .select('*')
        .gt('created_at', last24h.toIso8601String());
    
    // For non-central admins, filter by their station
    if (stationId != null) {
      debugPrint('Filtering by police_station_id: $stationId');
      query = query.eq('police_station_id', stationId);
    }
    
    // Execute query
    final response = await query.order('created_at', ascending: false);
    
    if (response != null && response is List) {
      final allIncidents = response.cast<Map<String, dynamic>>();
      
      debugPrint('Found ${allIncidents.length} total incidents in the last 24h');
      
      // Filter out already processed incidents
      final unprocessedIncidents = allIncidents.where((incident) {
        final id = incident['id'].toString();
        return !_processedIncidents.containsKey(id);
      }).toList();
      
      if (unprocessedIncidents.isNotEmpty) {
        debugPrint('${unprocessedIncidents.length} incidents are new and unprocessed');
      } else {
        debugPrint('All incidents have already been processed');
      }
      
      return unprocessedIncidents;
    }
    
    return [];
  } catch (e) {
    debugPrint('Error checking for new incidents: $e');
    return [];
  }
}

void forceResetTracking() {
  _processedIncidents.clear();
  _lastCheckedTime = DateTime.now().subtract(const Duration(days: 30)); // Check last 30 days
  saveProcessedIncidentsState();
  debugPrint('Notification tracking completely reset! Checking incidents from last 30 days.');
}

  // Start monitoring for new incidents periodically
  void startIncidentMonitoring({
    required Duration interval,
    required Function(List<Map<String, dynamic>>) onNewIncidents,
    String? stationId,
  }) {
    // Cancel any existing timer
    stopIncidentMonitoring();
    
    debugPrint('Starting incident monitoring with interval: ${interval.inSeconds}s');
    if (stationId != null) {
      debugPrint('Filtering by police station ID: $stationId');
    }
    
    // Start periodic timer
    _incidentTimer = Timer.periodic(interval, (timer) async {
      try {
        // Check for new incidents
        final newIncidents = await checkForNewIncidents(stationId: stationId);
        
        if (newIncidents.isNotEmpty) {
          debugPrint('Found ${newIncidents.length} new incidents to process');
          
          // Mark all as processed to avoid duplicates
          for (final incident in newIncidents) {
            _processedIncidents[incident['id'].toString()] = true;
          }
          await saveProcessedIncidentsState();
          
          // Call callback with new incidents
          onNewIncidents(newIncidents);
        }
      } catch (e) {
        debugPrint('Error in incident monitoring timer: $e');
      }
    });
  }
  
  void stopIncidentMonitoring() {
    if (_incidentTimer != null) {
      _incidentTimer!.cancel();
      _incidentTimer = null;
      debugPrint('Incident monitoring stopped');
    }
  }
  
  bool isIncidentProcessed(String incidentId) {
    return _processedIncidents.containsKey(incidentId) && _processedIncidents[incidentId] == true;
  }
  
  void markIncidentAsProcessed(String incidentId) {
    _processedIncidents[incidentId] = true;
    saveProcessedIncidentsState();
  }
  
  // Reset tracking for an incident (useful for testing)
  void resetIncidentTracking(String incidentId) {
    _processedIncidents.remove(incidentId);
    saveProcessedIncidentsState();
  }
  
  // Reset all incident tracking
  void resetAllIncidentTracking() {
    _processedIncidents.clear();
    _lastCheckedTime = DateTime.now().subtract(const Duration(minutes: 5));
    saveProcessedIncidentsState();
    debugPrint('All incident tracking reset');
  }
  
  // Get unread notification count
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      
      return response != null && response is List ? response.length : 0;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }
  
Future<void> processNewIncident(Map<String, dynamic> incident) async {
  try {
    final String incidentId = incident['id'].toString();
    
    // Skip if already processed
    if (isIncidentProcessed(incidentId)) {
      debugPrint('Incident $incidentId already processed, skipping notification');
      return;
    }

    final String incidentType = incident['incident_type'] ?? 'Unknown Incident';
    final String district = incident['district'] ?? 'Unknown Location';
    final String priority = getIncidentPriority(incidentType);
    final String? policeStationId = incident['police_station_id']?.toString();
    
    debugPrint('Processing new incident: $incidentId ($incidentType) for station: $policeStationId');
    
    // Get all admin users with their station assignments
    final adminsResponse = await supabase
        .from('admins')
        .select('''
          user_id,
          admin_station_assignments (
            station_id,
            police_stations!inner(name)
          )
        ''')
        .eq('role', 'admin');

    if (adminsResponse == null || adminsResponse.isEmpty) {
      debugPrint('No admin users found for notification');
      return;
    }

    // Create notifications for relevant admins
    int notificationCount = 0;
    for (final admin in adminsResponse) {
      final userId = admin['user_id'].toString();
      final stationAssignments = admin['admin_station_assignments'] as List?;
      
      // Check if this admin is a central admin (Kabale Central Police Station)
      bool isCentralAdmin = stationAssignments?.any((assignment) {
        final station = assignment['police_stations'];
        return station != null && station['name'] == 'Kabale Central Police Station';
      }) ?? false;

      // Get the admin's station ID (if not central admin)
      String? adminStationId;
      if (!isCentralAdmin && stationAssignments != null && stationAssignments.isNotEmpty) {
        adminStationId = stationAssignments[0]['station_id']?.toString();
      }

      // Only send notification if:
      // 1. Admin is central admin, OR
      // 2. Incident is assigned to admin's station
      if (isCentralAdmin || adminStationId == policeStationId) {
        await createNotification(
          userId: userId,
          title: 'New ${priority == 'High' ? '⚠️ ' : ''}$incidentType',
          message: 'Reported in $district\nStatus: ${incident['status'] ?? 'Pending'}',
          priority: priority,
          incidentId: incidentId,
        );
        notificationCount++;
      }
    }

    // Mark incident as processed
    markIncidentAsProcessed(incidentId);
    debugPrint('Successfully created $notificationCount notifications for incident $incidentId');
  } catch (e) {
    debugPrint('Error processing incident for notification: $e');
  }
}

  // Add this to your NotificationService class
Future<void> forceNotificationForIncident(String incidentId) async {
  try {
    // Get the incident details from the database
    final supabase = Supabase.instance.client;
    final incident = await supabase
        .from('incidents')
        .select()
        .eq('id', incidentId)
        .single();
    
    if (incident == null) {
      debugPrint('Incident $incidentId not found');
      return;
    }
    
    // First, remove from processed incidents to ensure it shows as new
    _processedIncidents.remove(incidentId);
    await saveProcessedIncidentsState();
    
    // Process it directly
    await processNewIncident(incident);
    
    debugPrint('Force-created notification for incident $incidentId');
  } catch (e) {
    debugPrint('Error force-creating notification: $e');
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
    debugPrint('NotificationService disposed');
  }
}