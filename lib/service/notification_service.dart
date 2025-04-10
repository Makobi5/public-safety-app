// lib/service/notification_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  Timer? _notificationTimer;
  DateTime? _lastCheckedTime;
  final Map<String, bool> _processedIncidents = {};
  Timer? _incidentTimer;
  
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

  // Get notifications for a specific station
  Future<List<Map<String, dynamic>>> getNotificationsForStation(String stationId) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user != null) {
        final response = await supabase
            .from('notifications')
            .select('*, incidents!inner(*)')
            .eq('user_id', user.id)
            .eq('incidents.police_station_id', stationId)
            .order('created_at', ascending: false);
        
        if (response != null && response is List) {
          return response.cast<Map<String, dynamic>>();
        }
      }
      
      return [];
    } catch (e) {
      print('Error getting notifications for station: $e');
      return [];
    }
  }

// Corrected getUserNotifications method with proper type handling

Future<List<NotificationModel>> getUserNotifications({
  required String userId,
  String? stationId,
  bool unreadOnly = false
}) async {
  try {
    // Start with the basic query builder
    final queryBuilder = supabase
        .from('notifications')
        .select('*, incidents!left(*)');
    
    // Apply filters directly to the initial builder
    final filteredQuery = queryBuilder
        .eq('user_id', userId);
    
    // Apply read status filter if needed
    final readStatusQuery = unreadOnly 
        ? filteredQuery.eq('is_read', false) 
        : filteredQuery;
    
    // Apply ordering - don't try to reassign the variable
    final orderedQuery = readStatusQuery.order('created_at', ascending: false);
    
    // Execute the query - note we don't try to reassign to the original variable
    final response = await orderedQuery;
    
    // Process results and handle station filtering
    List<Map<String, dynamic>> filteredResponse = [];
    if (response != null && response is List) {
      if (stationId != null) {
        // Filter in memory after the query
        filteredResponse = response.where((item) {
          // Check if incidents data exists and has the right station ID
          final incidents = item['incidents'];
          if (incidents == null) return false;
          return incidents['police_station_id'] == stationId;
        }).toList();
      } else {
        filteredResponse = List<Map<String, dynamic>>.from(response);
      }
      
      // Convert to model objects
      return filteredResponse
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    }
    return [];
  } catch (e) {
    debugPrint('Error fetching notifications: $e');
    return [];
  }
}

  // Load processed incidents from SharedPreferences
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

  // Save processed incidents to SharedPreferences
  Future<void> saveProcessedIncidentsState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('processed_incidents', jsonEncode(_processedIncidents));
    } catch (e) {
      debugPrint('Error saving processed incidents state: $e');
    }
  }

  // Mark notification as read with optimistic UI update
  Future<void> markAsRead(String notificationId) async {
    try {
      // Update in database
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
          
      // Emit update to any listeners
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        // Trigger any UI updates
        final updated = await getUserNotifications(userId: currentUser.id);
        // Broadcast update if needed
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
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
      debugPrint('Error marking all notifications as read: $e');
      rethrow;
    }
  }
Future<int> getUnreadCount(String userId, {String? stationId}) async {
  try {
    // Build a query that selects just the IDs we need
    var query = supabase
        .from('notifications')
        .select(stationId != null ? 'id, incidents!left(police_station_id)' : 'id')
        .eq('user_id', userId)
        .eq('is_read', false);
    
    // Execute the query
    final response = await query;
    
    // Handle empty results
    if (response == null || !(response is List)) {
      return 0;
    }
    
    // If we need to filter by station ID, do it in memory
    if (stationId != null) {
      return response.where((item) {
        if (item['incidents'] == null) return false;
        return item['incidents']['police_station_id'] == stationId;
      }).length;
    } else {
      // Otherwise just return the count of items
      return response.length;
    }
  } catch (e) {
    debugPrint('Error getting unread count: $e');
    return 0;
  }
}
void startIncidentMonitoring({
  required Duration interval,
  required Function(List<Map<String, dynamic>>) onNewIncidents,
  String? stationId,
}) {
  // Cancel any existing timer
  stopIncidentMonitoring();
  
  // Store the last check time
  DateTime lastCheckTime = DateTime.now();
  
  // Start periodic timer
  _incidentTimer = Timer.periodic(interval, (timer) async {
    try {
      debugPrint('Checking for new incidents since ${lastCheckTime.toIso8601String()}');
      
      // Create a base query
      var query = supabase
          .from('incidents')
          .select('*')
          .gt('created_at', lastCheckTime.toIso8601String());
      
      // Add station filter if provided
      if (stationId != null) {
        debugPrint('Filtering incidents by station ID: $stationId');
        query = query.eq('police_station_id', stationId);
      }
      
      // Execute the query
      final response = await query.order('created_at', ascending: false);
      
      // Update last check time
      lastCheckTime = DateTime.now();
      
      if (response != null && response is List && response.isNotEmpty) {
        final newIncidents = response.cast<Map<String, dynamic>>();
        debugPrint('Found ${newIncidents.length} new incidents');
        
        // Call the callback with new incidents
        onNewIncidents(newIncidents);
      } else {
        debugPrint('No new incidents found');
      }
    } catch (e) {
      debugPrint('Error monitoring for new incidents: $e');
    }
  });
}
  
  // Stop incident monitoring
  void stopIncidentMonitoring() {
    _incidentTimer?.cancel();
    _incidentTimer = null;
  }

  // Process a new incident and create notifications for all relevant admins
  Future<void> processNewIncident(Map<String, dynamic> incident) async {
    try {
      final String incidentId = incident['id'].toString();
      
      // Skip if already processed
      if (_processedIncidents[incidentId] == true) {
        return;
      }

      final String incidentType = incident['incident_type'] ?? 'Unknown Incident';
      final String district = incident['district'] ?? 'Unknown Location';
      final String priority = getIncidentPriority(incidentType);
      final String? policeStationId = incident['police_station_id']?.toString();
      
      // Get all relevant admin users
      var adminsQuery = supabase.from('admins')
          .select('id, user_id, admin_station_assignments!inner(station_id)');
          
      // If there's a station ID, filter admins by station assignment or central admin
      if (policeStationId != null) {
        // Find admins assigned to this station OR central admins
        adminsQuery = adminsQuery.or('admin_station_assignments.station_id.eq.$policeStationId,admin_station_assignments.station_id.eq.${getCentralPoliceStationId()}');
      }
      
      final adminsResponse = await adminsQuery;
      
      if (adminsResponse == null || adminsResponse.isEmpty) {
        debugPrint('No admin users found for incident notification');
        return;
      }

      // Create notifications for all relevant admins
      for (final admin in adminsResponse) {
        final userId = admin['user_id'].toString();
        
        await createNotification(
          userId: userId,
          title: 'New ${priority == 'High' ? '⚠️ ' : ''}$incidentType',
          message: 'Reported in $district\nStatus: ${incident['status'] ?? 'Pending'}',
          priority: priority,
          incidentId: incidentId,
        );
      }

      // Mark incident as processed after successful notification
      _processedIncidents[incidentId] = true;
      await saveProcessedIncidentsState();
      
      debugPrint('Successfully processed incident $incidentId');
    } catch (e) {
      debugPrint('Error processing incident: $e');
    }
  }
  
  // Helper to get central police station ID
  String getCentralPoliceStationId() {
    // Replace with actual ID from your database
    return 'central-police-station-id';
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
  
  // Show a notification dialog
  void showNotificationDialog(BuildContext context, List<Map<String, dynamic>> notifications, Function onNotificationTapped) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications, color: Color(0xFF003366)),
            const SizedBox(width: 8),
            const Text('Notifications'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: notifications.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('No notifications'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: notification['read'] == true
                            ? Colors.grey.shade200
                            : _getPriorityColor(notification['priority'] ?? 'Low'),
                        child: Icon(
                          Icons.notification_important,
                          color: notification['read'] == true
                              ? Colors.grey
                              : _getPriorityTextColor(notification['priority'] ?? 'Low'),
                        ),
                      ),
                      title: Text(
                        notification['title'],
                        style: TextStyle(
                          fontWeight: notification['read'] == true ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(notification['message']),
                      trailing: Text(notification['time']),
                      onTap: () {
                        Navigator.of(context).pop();
                        onNotificationTapped(notification, index);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Mark all as read and close dialog - implementation in parent widget
              Navigator.of(context).pop('markAllRead');
            },
            child: const Text('Mark All Read'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003366),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  // Show a toast notification
  void showToastNotification(BuildContext context, Map<String, dynamic> notification) {
    final priority = notification['priority'] ?? 'Low';
    
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(Icons.notification_important, color: Colors.white),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              notification['title'],
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      backgroundColor: priority == 'High' ? Colors.red : 
                     priority == 'Medium' ? Colors.orange : Colors.green,
      duration: Duration(seconds: 5),
      action: SnackBarAction(
        label: 'VIEW',
        textColor: Colors.white,
        onPressed: () {
          // Navigate to incident details
          // Implementation in parent widget
        },
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
  
  // Helper method to get color for notification priority
  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade100;
      case 'medium':
        return Colors.orange.shade100;
      case 'low':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  // Helper method to get text color for notification priority
  Color _getPriorityTextColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
  
  // Cleanup resources
  void dispose() {
    stopIncidentMonitoring();
    _notificationStreamController.close();
  }
}