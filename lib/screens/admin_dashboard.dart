// lib/screens/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../service/auth_service.dart';
import 'case_detail_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
//import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'home_page.dart';
import 'user_management_screen.dart'; 
import '../service/notification_service.dart';
import '../models/notification_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';


class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  static String routeName = 'AdminDashboard';
  static String routePath = '/admin-dashboard';

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _searchController = TextEditingController();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  // Add this field in your _AdminDashboardState class
  bool _isCentralAdmin = false;
  String? _currentUserStationId;
  String? _currentPoliceStationName;
final NotificationService _notificationService = NotificationService();

  
  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;
  bool _showAddAdminForm = false;
  String? _currentUserName;
  bool _isRefreshing = false;
Map<String, bool> processedIncidents = {}; // Track processed incidents
List<Map<String, dynamic>> notifications = [];
int unreadNotifications = 0;
DateTime? lastFetchTime;


  // Dashboard data from database
  int activeCase = 0;
  int criticalCases = 0;
  int newReports = 0;
  String emergencyLevel = 'Low';
  int responseRateValue = 92; // Default fallback value
  // Add right after your existing variables in _AdminDashboardState class
// Notification related variables

  
  List<Map<String, dynamic>> recentReports = [];
  List<Map<String, dynamic>> recentActivities = [];
  List<Map<String, dynamic>> filteredReports = [];
  String? _selectedStationId;
  List<Map<String, dynamic>> _policeStations = [];
  
// In initState, make sure we're setting up listeners correctly
@override
void initState() {
  super.initState();
  _initializeNotifications();
  
  // Get current user first, then initialize other components
  _getCurrentUser().then((_) {
    // After getting user info, fetch dashboard data
    _fetchPoliceStations();
    _fetchDashboardData();
    
    // Load stored notifications
    _loadNotificationsState();
    
    // Debugging
    print('Setting up notification monitoring. isCentralAdmin: $_isCentralAdmin, stationId: $_currentUserStationId');
    
    // Set up notification listener with station filtering
    _notificationService.startIncidentMonitoring(
      interval: const Duration(seconds: 15),
      onNewIncidents: (newIncidents) {
        if (newIncidents.isNotEmpty) {
          print('Received ${newIncidents.length} new incidents to process');
          _processNewIncidents(newIncidents);
        }
      },
      stationId: _isCentralAdmin ? null : _currentUserStationId, // Only filter by station for non-central admins
    );
    _setupNotificationListener();
  });
}

Future<void> _initializeNotifications() async {
  try {
    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization with a simpler approach
    final IOSInitializationSettings initializationSettingsIOS =
        IOSInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        if (payload != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleNotificationPayload(payload);
          });
        }
      },
    );
    
    // macOS initialization (optional)
    final MacOSInitializationSettings initializationSettingsMacOS =
        MacOSInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    // Combined settings
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      macOS: initializationSettingsMacOS,
    );
    
    // Initialize with proper callback handling
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onSelectNotification: (String? payload) {
        if (payload != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleNotificationPayload(payload);
          });
        }
      },
    );
    
    // Request permissions for each platform
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isMacOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      // Android 13+ permission handling
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    }
  } catch (e) {
    debugPrint('Notification initialization error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to initialize notifications'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _handleNotificationPayload(String payload) async {
  if (!mounted) return;

  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final incidentId = data['incidentId']?.toString();

    if (incidentId == null || incidentId.isEmpty) {
      debugPrint('Invalid incident ID in payload');
      return;
    }

    // Delay slightly to ensure navigation context is ready
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CaseDetailScreen(
          incidentId: incidentId,
        ),
      ),
    );

    // Refresh data when returning from detail screen
    if (mounted) {
      _markIncidentAsRead(incidentId);
      _fetchDashboardData();
    }
  } catch (e) {
    debugPrint('Error handling notification payload: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to open incident details'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}




Future<void> _getCurrentUser() async {
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    if (user != null) {
      // First, get the admin details including their assigned station
      final adminResponse = await supabase
          .from('admins')
          .select('id, role')
          .eq('user_id', user.id)
          .single();
          
      if (adminResponse != null) {
        final adminId = adminResponse['id'];
        
        // Get the admin's station assignment
        final stationAssignmentResponse = await supabase
          .from('admin_station_assignments')
          .select('station_id, police_stations!inner(id, name, district_id)')
          .eq('admin_id', adminId)
          .single();
        
        // Then get user profile data
        final userProfileResponse = await supabase
            .from('user_profiles')  // Assuming this table exists for user details
            .select('first_name, last_name')
            .eq('user_id', user.id)
            .single();
        
        if (userProfileResponse != null && stationAssignmentResponse != null) {
          final firstName = userProfileResponse['first_name'] as String? ?? '';
          final lastName = userProfileResponse['last_name'] as String? ?? '';
          
          // Get the station details
          final stationId = stationAssignmentResponse['station_id'] as String?;
          final policeStationName = stationAssignmentResponse['police_stations']['name'] as String?;
          
          // Check if this is a central admin (Kabale Central Police Station)
          final isCentralAdmin = policeStationName == 'Kabale Central Police Station';
          
          setState(() {
            _currentUserName = '$firstName $lastName';
            _currentUserStationId = stationId;
            _currentPoliceStationName = policeStationName;
            _isCentralAdmin = isCentralAdmin;
          });
        }
      }
    }
  } catch (e) {
    print('Error getting current user: $e');
  }
}
  // Add after _getCurrentUser method

// Fix for the Dart type issue in _fetchPoliceStations method

Future<void> _fetchPoliceStations() async {
  try {
    final supabase = Supabase.instance.client;
    
    // If central admin, fetch all police stations
    if (_isCentralAdmin) {
      final response = await supabase
          .from('police_stations')
          .select('id, name, district_id')
          .order('name');
          
      if (response != null && response is List) {
        setState(() {
          _policeStations = response.cast<Map<String, dynamic>>();
          
          // Debug output
          print('Fetched ${_policeStations.length} police stations');
          for (var station in _policeStations) {
            print('Station: ${station['name']}, ID: ${station['id']}');
          }
        });
      }
    } else {
      // For non-central admins, only their assigned station is available
      if (_currentUserStationId != null) {
        // Fix: Cast the _currentUserStationId to dynamic or explicitly handle as UUID
        final response = await supabase
            .from('police_stations')
            .select('id, name, district_id')
            .eq('id', _currentUserStationId as dynamic)  // Cast to dynamic to satisfy the type requirement
            .limit(1);
            
        if (response != null && response is List && response.isNotEmpty) {
          setState(() {
            _policeStations = response.cast<Map<String, dynamic>>();
            // Pre-select the only available station
            _selectedStationId = _currentUserStationId;
            
            // Debug output
            print('Fetched station: ${_policeStations[0]['name']}, ID: ${_policeStations[0]['id']}');
          });
        }
      }
    }
  } catch (e) {
    print('Error fetching police stations: $e');
  }
}

  
// Show notifications dialog
void _showQuickAlertDialog() {
  final messageController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Emergency Alert',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Send emergency alert to all officers and nearby districts?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: messageController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Alert Message (Optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              hintText: 'Describe the emergency situation...',
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final message = messageController.text.trim();
                Navigator.pop(context);
                
                try {
                  // Implement your actual alert sending logic here
                  final supabase = Supabase.instance.client;
                  await supabase.from('emergency_alerts').insert({
                    'message': message.isNotEmpty ? message : 'General emergency alert',
                    'created_by': _currentUserName ?? 'Admin',
                    'station_id': _currentUserStationId,
                    'created_at': DateTime.now().toIso8601String(),
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Emergency alert sent successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to send alert: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.warning_amber, color: Colors.white),
              label: const Text(
                'SEND EMERGENCY ALERT',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}
// Save notifications state to persistent storage
Future<void> _saveNotificationsState() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Convert to a list of maps to ensure jsonEncode works properly
    final List<Map<String, dynamic>> notificationsToSave = notifications.map((notification) {
      // Create a new map to avoid modifying the original
      final map = Map<String, dynamic>.from(notification);
      
      // Make sure all values are JSON-serializable
      // Convert any non-serializable types if needed
      return map;
    }).toList();
    
    // Save notifications list
    await prefs.setString('notifications', jsonEncode(notificationsToSave));
    
    // Save unread count
    await prefs.setInt('unread_notifications', unreadNotifications);
  } catch (e) {
    print('Error saving notifications state: $e');
  }
}
// Load notifications state from persistent storage
Future<void> _loadNotificationsState() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? storedNotifications = prefs.getString('notifications');
    
    if (storedNotifications != null && storedNotifications.isNotEmpty) {
      try {
        final List<dynamic> decodedList = jsonDecode(storedNotifications);
        
        setState(() {
          notifications = decodedList.map((item) => Map<String, dynamic>.from(item)).toList();
          unreadNotifications = prefs.getInt('unread_notifications') ?? 0;
        });
      } catch (decodeError) {
        print('Error decoding stored notifications: $decodeError');
        // Reset if there's a decode error
        setState(() {
          notifications = [];
          unreadNotifications = 0;
        });
      }
    }
    
    // Also load processed incidents
    await _loadProcessedIncidents();
  } catch (e) {
    print('Error loading notifications state: $e');
  }
}

// Modify _setupNotificationListener to filter by station
void _setupNotificationListener() {
  _notificationService.startIncidentMonitoring(
    interval: const Duration(seconds: 15),
    onNewIncidents: (newIncidents) {
      if (newIncidents.isNotEmpty) {
        _processNewIncidents(newIncidents);
      }
    },
    stationId: _isCentralAdmin ? null : _currentUserStationId,
  );
}
// Check if there are pending critical cases that need attention
bool _hasPendingCriticalCases() {
  // Check if there are critical cases with 'Pending' status
  return recentReports.any((report) => 
    report['priority'] == 'High' && report['status'] == 'Pending');
}

// Check if there are new reports that haven't been viewed
// Helper method to check for unread reports
bool _hasNewUnreadReports() {
  // Check for reports that haven't been processed
  return recentReports.any((report) => 
    !processedIncidents.containsKey(report['id'].toString()));
}
// Calculate actual response rate based on pending vs total cases
String _calculateResponseRate() {
  // Count total incidents and non-pending incidents
  final totalIncidents = recentReports.length;
  if (totalIncidents == 0) return "0%";
  
  final respondedIncidents = recentReports.where((report) => 
    report['status'] != null && report['status'] != 'Pending'
  ).length;
  
  // Calculate the rate
  int rate = (respondedIncidents / totalIncidents * 100).round();
  
  // Hard cap at 99% if there are ANY pending cases to prevent showing 100%
  if (rate == 100 && recentReports.any((report) => 
    report['status'] == null || report['status'] == 'Pending')) {
    rate = 99;
  }
  
  return '$rate%';
}
// Add this helper method to your AdminDashboard class
bool isPending(Map<String, dynamic>? incident) {
  if (incident == null) return false;
  
  // Check for null, empty, or "Pending" status
  final status = incident['status'];
  return status == null || status == '' || status == 'Pending';
}

// Get color for response rate based on value
Color _getResponseRateColor() {
  // Parse percentage from the response rate string
  final rateString = _calculateResponseRate();
  final rate = int.parse(rateString.replaceAll('%', ''));
  
  if (rate >= 90) {
    return Colors.green;
  } else if (rate >= 70) {
    return Colors.orange;
  } else {
    return Colors.red;
  }
}
Future<void> _saveProcessedIncidents() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('processed_incidents', jsonEncode(processedIncidents));
  } catch (e) {
    print('Error saving processed incidents: $e');
  }
}
Widget _buildReportItem(Map<String, dynamic> report) {
  final bool isUnread = !processedIncidents.containsKey(report['id'].toString());
  final priority = report['priority'] ?? 'Low';
  final priorityColor = _getPriorityColor(priority);
  final textColor = _getPriorityTextColor(priority);

  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 0,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        // Mark as read immediately for better UX
        if (isUnread) {
          setState(() {
            processedIncidents[report['id'].toString()] = true;
          });
          await _saveProcessedIncidents();
        }

        // Navigate to case detail
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CaseDetailScreen(
              incidentId: report['id'],
            ),
          ),
        );

        // Refresh data when returning
        _fetchDashboardData();
        
        // Update notification state if needed
        final notificationIndex = notifications.indexWhere((n) => n['id'] == report['id']);
        if (notificationIndex >= 0) {
          setState(() {
            notifications[notificationIndex]['read'] = true;
            unreadNotifications = notifications.where((n) => n['read'] == false).length;
          });
          await _saveNotificationsState();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isUnread ? Colors.blue : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 12),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report['title'],
                    style: TextStyle(
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${report['district']} • ${report['time']}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$priority Priority',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
bool _isHigherPriority(String newPriority, String currentPriority) {
  const priorityOrder = {'High': 3, 'Medium': 2, 'Low': 1};
  final newValue = priorityOrder[newPriority] ?? 0;
  final currentValue = priorityOrder[currentPriority] ?? 0;
  return newValue > currentValue;
}

void _showNewIncidentNotification(Map<String, dynamic> incident) {
  final incidentType = incident['incident_type'] ?? 'Unknown Incident';
  final district = incident['district'] ?? 'Unknown Location';
  final priority = incident['priority'] ?? 'Low';
  
  final snackBar = SnackBar(
    content: Row(
      children: [
        Icon(Icons.notification_important, color: Colors.white),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'New $incidentType in $district',
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CaseDetailScreen(
              incidentId: incident['id'].toString(),
            ),
          ),
        ).then((_) {
          // Mark as read when returning
          _markIncidentAsRead(incident['id'].toString());
        });
      },
    ),
  );

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}


void _processNewIncidents(List<Map<String, dynamic>> newIncidents) async {
  if (newIncidents.isEmpty || !mounted) return;

  try {
    bool shouldShowNotification = false;
    Map<String, dynamic>? highestPriorityIncident;
    final now = DateTime.now();

    // Process incidents in batches to avoid UI jank
    for (var incident in newIncidents) {
      if (!mounted) return; // Check if widget is still in the tree

      final String reportId = incident['id']?.toString() ?? '';
      if (reportId.isEmpty) continue;

      // Skip if already processed (thread-safe check)
      if (processedIncidents.containsKey(reportId)) continue;

      // Station filtering logic
      if (!_isCentralAdmin && _currentUserStationId != null) {
        final incidentStationId = incident['police_station_id']?.toString();
        if (incidentStationId != _currentUserStationId) {
          debugPrint('Skipping incident $reportId - wrong station');
          continue;
        }
      }

      // Process incident
      final priority = _notificationService.getIncidentPriority(
          incident['incident_type'] ?? '');
      
      final timeString = incident['created_at'] != null
          ? DateFormat('HH:mm').format(DateTime.parse(incident['created_at']))
          : DateFormat('HH:mm').format(now);

      // Update state once per batch instead of per incident
      setState(() {
        processedIncidents[reportId] = true;
        
        notifications.insert(0, {
          'id': reportId,
          'title': '${priority == 'High' ? '⚠️ ' : ''}${incident['incident_type'] ?? 'Incident'}',
          'message': '${incident['district'] ?? 'Unknown'} • Status: ${incident['status'] ?? 'Pending'}',
          'time': timeString,
          'read': false,
          'priority': priority,
        });

        unreadNotifications++;
      });

      // Track highest priority incident
      if (highestPriorityIncident == null || 
          _isHigherPriority(priority, highestPriorityIncident!['priority'])) {
        highestPriorityIncident = {
          ...incident,
          'priority': priority,
          'time': timeString
        };
        shouldShowNotification = true;
      }
    }

    // Show mobile-optimized notification
    if (shouldShowNotification && highestPriorityIncident != null && mounted) {
      _showMobileNotification(highestPriorityIncident!);
    }

    // Throttle saves to prevent excessive I/O
    await Future.wait([
      _saveNotificationsState(),
      _saveProcessedIncidents(),
    ]);

    // Debounce dashboard refresh
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchDashboardData();
      });
    }

  } catch (e) {
    debugPrint('Error processing incidents: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update incidents'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Mobile-optimized notification
void _showMobileNotification(Map<String, dynamic> incident) {
  final priorityColor = _getPriorityColor(incident['priority']);
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${incident['incident_type']}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getPriorityTextColor(incident['priority']),
            ),
          ),
          Text(
            '${incident['district']} • ${incident['time']}',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      backgroundColor: priorityColor.withOpacity(0.9),
      duration: Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      action: SnackBarAction(
        label: 'VIEW',
        textColor: Colors.white,
        onPressed: () => _navigateToIncident(incident['id']),
      ),
    ),
  );
}

void _navigateToIncident(String incidentId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CaseDetailScreen(incidentId: incidentId),
    ),
  ).then((_) {
    if (mounted) {
      _markIncidentAsRead(incidentId);
      _fetchDashboardData();
    }
  });
}

void _forceNotifyMostRecent() async {
  try {
    final supabase = Supabase.instance.client;
    
    // Show message that we're checking
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Searching for most recent incident...'))
    );
    
    // Query with no time constraints
    final response = await supabase
        .from('incidents')
        .select()
        .order('created_at', ascending: false)
        .limit(1);
    
    // Debug output    
    debugPrint('Recent incident query response: $response');
    
    if (response != null && response is List && response.isNotEmpty) {
      final recentIncident = response[0];
      final id = recentIncident['id'].toString();
      final createdAt = recentIncident['created_at'];
      
      debugPrint('Found incident $id created at $createdAt');
      
      // Clear processed incidents completely
      _notificationService.resetAllIncidentTracking();
      
      // Directly create notification
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('notifications').insert({
          'user_id': user.id,
          'title': 'New ${recentIncident['incident_type']}',
          'message': 'Reported in ${recentIncident['district']}',
          'is_read': false,
          'priority': _notificationService.getIncidentPriority(recentIncident['incident_type']),
          'incident_id': id,
          'created_at': DateTime.now().toIso8601String(),
        });
        
        debugPrint('Directly inserted notification for incident $id');
        
        // Force refresh notifications
        await _loadNotificationsState();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification created for incident $id'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No incidents found in database'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    debugPrint('Error in force notify: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

void _forceCheckNotifications() async {
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    if (user != null) {
      // Force reset the notification check time to get recent incidents
      _notificationService.resetAllIncidentTracking();
      
      // Manual check for new incidents
      final incidents = await _notificationService.checkForNewIncidents(
        stationId: _isCentralAdmin ? null : _currentUserStationId
      );
      
      if (incidents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No new incidents found'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${incidents.length} incidents, processing...'),
            backgroundColor: Colors.blue,
          ),
        );
        
        // Process these incidents
        _processNewIncidents(incidents);
      }
    }
  } catch (e) {
    debugPrint('Error in force check: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error checking notifications: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}


// Mark a specific incident as read
Future<void> _markIncidentAsRead(String incidentId) async {
  setState(() {
    // Find and mark as read in our local notifications list
    final index = notifications.indexWhere((n) => n['id'] == incidentId);
    if (index >= 0 && notifications[index]['read'] != true) {
      notifications[index]['read'] = true;
      unreadNotifications = notifications.where((n) => n['read'] == false).length;
    }
  });
  
  // Save updated notification state
  await _saveNotificationsState();
  
  // Mark as read in database if needed
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    if (user != null) {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('incident_id', incidentId);
    }
  } catch (e) {
    print('Error marking notification as read: $e');
  }
}

// Load processed incidents from persistent storage
Future<void> _loadProcessedIncidents() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString('processed_incidents');
    
    if (stored != null && stored.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(stored);
        setState(() {
          processedIncidents.clear();
          decoded.forEach((key, value) {
            processedIncidents[key] = value as bool;
          });
        });
      } catch (e) {
        print('Error decoding processed incidents: $e');
        processedIncidents.clear();
      }
    }
  } catch (e) {
    print('Error loading processed incidents: $e');
  }
}

@override
void dispose() {
  // Stop the notification monitoring when widget is disposed
  _notificationService.stopIncidentMonitoring();
  super.dispose();
}

Future<void> _fetchDashboardData() async {
  setState(() {
    _isLoading = true;
  });
  
  // Load processed incidents first
  final prefs = await SharedPreferences.getInstance();
  final processed = prefs.getString('processed_incidents');
  if (processed != null) {
    processedIncidents = Map<String, bool>.from(jsonDecode(processed));
  }

  try {
    final supabase = Supabase.instance.client;
    
    // If not central admin, filter incidents by station
    var incidentQuery = supabase.from('incidents').select();

    if (!_isCentralAdmin && _currentUserStationId != null) {
      // Use police_station_id instead of reported_station_id
      incidentQuery = incidentQuery.eq('police_station_id', _currentUserStationId as Object);
      
      // Debug print
      print('Current station ID (UUID): $_currentUserStationId');
    }

    // Order by creation date - don't reassign, create a new variable
    final orderedIncidentQuery = incidentQuery.order('created_at', ascending: false);
    
    // Get responded incidents count (with status not 'Pending')
    var respondedQuery = supabase.from('incidents').select('id');
    
    if (!_isCentralAdmin && _currentUserStationId != null) {
      // Only count incidents for this admin's police station
      respondedQuery = respondedQuery.eq('police_station_id', _currentUserStationId as Object);
    }
    
    // Apply the 'not' filter and don't reassign
    final filteredRespondedQuery = respondedQuery.not('status', 'eq', 'Pending');
    
    final responses = await Future.wait([
      orderedIncidentQuery,
      filteredRespondedQuery,
    ]);

    if (responses[0] != null && responses[0] is List) {
      final incidents = responses[0].cast<Map<String, dynamic>>();
      final respondedIncidents = responses[1]?.cast<Map<String, dynamic>>() ?? [];
      
      // Debug print
      print('Incidents found: ${incidents.length}');
      incidents.forEach((incident) {
        print('Incident ${incident['id']} - police_station_id: ${incident['police_station_id']}');
      });
      
      // Process for dashboard metrics
      activeCase = incidents.length;
      
      criticalCases = incidents.where((incident) => 
        _notificationService.getIncidentPriority(incident['incident_type']) == 'High' ||
        incident['incident_type'] == 'Fire outbreak' || 
        incident['incident_type'] == 'Accident'
      ).length;
      
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      newReports = incidents.where((incident) {
        final createdAt = incident['created_at'] as String;
        return createdAt.startsWith(todayString);
      }).length;
      
      final criticalPercentage = activeCase > 0 ? (criticalCases / activeCase) * 100 : 0;
      emergencyLevel = criticalPercentage >= 20 ? 'High' : 
                      criticalPercentage >= 10 ? 'Medium' : 'Low';
      
      // Make sure status is explicitly set for all reports
      recentReports = incidents.take(10).map((incident) {
        final DateTime createdAt = DateTime.parse(incident['created_at']);
        return {
          'id': incident['id'],
          'title': incident['incident_type'] ?? 'Unknown Incident',
          'district': incident['district'] ?? 'Unknown Location',
          'time': '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
          'priority': _notificationService.getIncidentPriority(incident['incident_type']),
          'status': incident['status'] ?? 'Pending', // Explicitly set to 'Pending' if null
          'station_id': incident['police_station_id'], // Updated to match correct column name
        };
      }).toList();
      
      // Count pending cases directly here to double-check
      final pendingCases = recentReports.where((report) => 
        report['status'] == null || report['status'] == '' || report['status'] == 'Pending').length;
      
      // Calculate correct response rate
      int responseRate;
      if (recentReports.isEmpty) {
        responseRate = 0;
      } else {
        responseRate = ((recentReports.length - pendingCases) / recentReports.length * 100).round();
        // Hard cap at 99% if pending cases exist
        if (pendingCases > 0 && responseRate == 100) {
          responseRate = 99;
        }
      }
      
      // Debug output
      debugPrint('RESPONSE RATE CALCULATION:');
      debugPrint('Total reports: ${recentReports.length}');
      debugPrint('Pending reports: $pendingCases');
      debugPrint('Calculated rate: $responseRate%');
      
      filteredReports = List.from(recentReports);
      responseRateValue = responseRate; // Store the calculated response rate
    }
    
    await _fetchRecentActivity();
    
  } catch (e) {
    debugPrint('Error fetching dashboard data: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading dashboard data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }
}
Future<void> _refreshDashboard() async {
  setState(() {
    _isRefreshing = true;
  });
  await _fetchDashboardData();
}
  
Future<void> _fetchRecentActivity() async {
  try {
    // Get Supabase client
    final supabase = Supabase.instance.client;
    
    // Base query - updated to include police_station_id
    var activityQuery = supabase
        .from('incident_activity')
        .select('*, incidents!inner(incident_type, police_station_id)');
    
    // If not central admin, filter activities by station
    if (!_isCentralAdmin && _currentUserStationId != null) {
      activityQuery = activityQuery.eq('incidents.police_station_id', _currentUserStationId as Object);
      
      // Debug print
      print('Filtering activities by station ID: $_currentUserStationId');
    }
    
    // Complete the query - don't reassign
    final response = await activityQuery.order('created_at', ascending: false)
        .limit(5);
    
    if (response != null && response is List) {
      // Process data for activity log display
      recentActivities = response.cast<Map<String, dynamic>>();
      print('Recent activity fetched: ${recentActivities.length} entries');
      
      // Debug logging
      for (var activity in recentActivities) {
        print('Activity for incident ${activity['incident_id']} - police_station_id: ${activity['incidents']['police_station_id']}');
      }
    }
  } catch (e) {
    print('Error fetching recent activity: $e');
  }
}
  // Determine incident priority based on type
  String _getIncidentPriority(String? incidentType) {
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

// Fixed _addAdmin method in the AdminDashboard class

Future<void> _addAdmin() async {
  if (!_formKey.currentState!.validate()) return;
  
  // Check if a station is selected
  if (_selectedStationId == null) {
    setState(() {
      _errorMessage = 'Please select a police station';
    });
    return;
  }
  
  setState(() {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
  });

  try {
    // Create a new admin user
    final userData = {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'role': 'admin', // Set role as admin
    };
    
    print('Creating admin with station assignment to: $_selectedStationId');
    
    // Call the method to create admin account - now returns String? instead of AuthResponse
    final createdUserId = await AuthService.createAdminAccount(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      userData: userData,
    );
    
    // Now assign the admin to the selected police station
    if (createdUserId != null) {
      final supabase = Supabase.instance.client;
      
      print('Getting admin record for user ID: $createdUserId');
      
      // First get the admin ID from the newly created user
      final adminResponse = await supabase
          .from('admins')
          .select('id')
          .eq('user_id', createdUserId)
          .limit(1);
          
      print('Admin query response: $adminResponse');
      
      if (adminResponse != null && adminResponse is List && adminResponse.isNotEmpty) {
        final adminId = adminResponse[0]['id'];
        
        print('Creating station assignment for admin ID: $adminId to station: $_selectedStationId');
        
        // Create the station assignment
        await supabase.from('admin_station_assignments').insert({
          'admin_id': adminId,
          'station_id': _selectedStationId,
          'created_at': DateTime.now().toIso8601String()
        });
        
        print('Station assignment created successfully');

        // Show success message in UI
        setState(() {
          _successMessage = 'Admin account for ${_firstNameController.text} ${_lastNameController.text} created successfully and assigned to station!';
          
          // Clear form fields
          _emailController.clear();
          _passwordController.clear();
          _firstNameController.clear();
          _lastNameController.clear();
          _showAddAdminForm = false; // Return to dashboard view
        });

        // Optional: Show a SnackBar for immediate feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin account created successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      } else {
        print('Could not find admin record for user ID: $createdUserId');
        throw Exception('Admin record not found');
      }
    } else {
      throw Exception('No user ID returned from admin creation');
    }
  } catch (e) {
    print('Error in _addAdmin: $e');
    setState(() {
      _errorMessage = 'Error creating admin account: ${e.toString()}';
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  // Filter reports based on search text
  void _filterReports(String searchText) {
    setState(() {
      if (searchText.isEmpty) {
        filteredReports = List.from(recentReports);
      } else {
        filteredReports = recentReports.where((report) {
          final title = report['title'].toString().toLowerCase();
          final district = report['district'].toString().toLowerCase();
          final query = searchText.toLowerCase();
          return title.contains(query) || district.contains(query);
        }).toList();
      }
    });
  }

  // Logout user
  
  Future<void> _logout() async {
  try {
    setState(() {
      _isLoading = true;
    });
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003366),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final supabase = Supabase.instance.client;
      await supabase.auth.signOut();
      
      // Navigate to login screen
      if (mounted) {
        // Use MaterialPageRoute to navigate directly to the login page
        // Import the login page at the top of your file: import 'path/to/home_page.dart';
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => HomePage(), // Assuming HomePage is your login screen
          ),
          (route) => false, // This removes all previous routes
        );
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error during logout: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
// Helper method to get color based on priority
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


// Helper method to get text color based on priority
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
  
Future<void> _exportDistrictActivityMap() async {
  try {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating district activity report...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Create PDF document
    final pdf = pw.Document();
    
    // Add content to PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'District Activity Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      _buildPdfHeaderCell('District'),
                      _buildPdfHeaderCell('Total Incidents'),
                      _buildPdfHeaderCell('Critical Incidents'),
                    ],
                  ),
                  ..._generateDistrictRows(),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Get temporary directory
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/district_activity_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    
    // Save the PDF
    await file.writeAsBytes(await pdf.save());

    // Share the file using mobile share sheet
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'District Activity Report - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      subject: 'Public Safety Report',
    );

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to export report: ${e.toString()}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

pw.Padding _buildPdfHeaderCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    ),
  );
}

List<pw.TableRow> _generateDistrictRows() {
  // This should be replaced with actual data from your database
  final districtData = recentReports.fold<Map<String, Map<String, int>>>(
    {},
    (map, report) {
      final district = report['district'] ?? 'Unknown';
      map.putIfAbsent(district, () => {'total': 0, 'critical': 0});
      map[district]!['total'] = map[district]!['total']! + 1;
      if ((report['priority'] ?? 'Low').toString().toLowerCase() == 'high') {
        map[district]!['critical'] = map[district]!['critical']! + 1;
      }
      return map;
    },
  );

  return districtData.entries.map((entry) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(entry.key),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(entry.value['total'].toString()),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(entry.value['critical'].toString()),
        ),
      ],
    );
  }).toList();
}
  



// Code to implement notification badge in AppBar

// In your _AdminDashboardState class, modify the build method:
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Admin Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!_isCentralAdmin && _currentPoliceStationName != null)
            Text(
              _currentPoliceStationName!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
        ],
      ),
      backgroundColor: const Color(0xFF003366),
      elevation: 0,
      actions: [
        // Notification button with badge
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.white),
              onPressed: () {
                _showQuickAlertDialog();
              },
            ),
            if (unreadNotifications > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadNotifications.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        // DEBUG button
// Replace existing force check button
            IconButton(
              icon: const Icon(Icons.bug_report, color: Colors.yellow),
              onPressed: () {
                // Force reset ALL tracking
                _notificationService.forceResetTracking();
                
                // Show confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Completely reset notification tracking!'),
                    backgroundColor: Colors.deepPurple,
                    duration: Duration(seconds: 1),
                  ),
                );
                
                // Wait a second then force check
                Future.delayed(Duration(seconds: 1), () {
                  _forceCheckNotifications();
                });
              },
              tooltip: 'Reset & Force Check',
            ),

        // Refresh button with loading indicator
        IconButton(
          icon: _isRefreshing 
              ? SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                )
              : const Icon(Icons.refresh, color: Colors.white),
          onPressed: _isRefreshing ? null : _refreshDashboard,
          tooltip: 'Refresh Dashboard',
        ),
      ],
    ),
    body: _showAddAdminForm ? _buildAddAdminForm() : _buildDashboard(),
    floatingActionButton: !_showAddAdminForm 
    ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'reportBtn',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserManagementScreen(),
                ),
              ).then((_) {
                _fetchDashboardData();
              });
            },
            backgroundColor: Colors.blue,
            child: const Icon(Icons.people),
            tooltip: 'User Management',
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'adminBtn',
            onPressed: () {
              setState(() {
                _showAddAdminForm = true;
              });
            },
            backgroundColor: const Color(0xFF003366),
            child: const Icon(Icons.person_add),
            tooltip: 'Add Admin User',
          ),
        ],
      )
    : null,
    drawer: _buildAppDrawer(),
  );
}
Widget _buildAppDrawer() {
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(
            color: Color(0xFF003366),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Safety Control Center',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (_currentUserName != null)
                Text(
                  'Welcome, $_currentUserName',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              const SizedBox(height: 8),
              if (_currentPoliceStationName != null)
                Text(
                  _currentPoliceStationName!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isCentralAdmin ? Colors.red : Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isCentralAdmin ? 'Central Admin' : 'Station Admin',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dashboard),
          title: const Text('Dashboard'),
          selected: true,
          selectedTileColor: Colors.blue.shade50,
          onTap: () {
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.people),
          title: const Text('User Management'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserManagementScreen(),
              ),
            ).then((_) {
              // Refresh dashboard data when returning
              _fetchDashboardData();
            });
          },
        ),
        ListTile(
          leading: const Icon(Icons.assessment),
          title: const Text('Reports & Analytics'),
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reports & Analytics page coming soon'),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.map),
          title: const Text('District Mapping'),
          onTap: () {
            Navigator.pop(context);
            _exportDistrictActivityMap();
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Settings'),
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Settings page coming soon'),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('Help & Support'),
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Help & Support page coming soon'),
              ),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.red),
          ),
          onTap: () {
            Navigator.pop(context);
            _logout();
          },
        ),
      ],
    ),
  );
}
Widget _buildStatCard(String title, String value, Color valueColor) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.shade300,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
            if (_isRefreshing)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 16, 
                  height: 16, 
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(valueColor.withOpacity(0.5)),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildDashboard() {
  return Container(
    color: Colors.grey.shade100,
    child: _isLoading
        ? const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF003366),
            ),
          )
        : RefreshIndicator(
            onRefresh: _refreshDashboard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Station indicator banner for non-central admins
                if (!_isCentralAdmin && _currentPoliceStationName != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.orange.shade100,
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.orange.shade800, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Viewing reports for: $_currentPoliceStationName',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Emergency Level Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: const Color(0xFF003366),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: emergencyLevel == 'High'
                                ? Colors.red.shade800
                                : emergencyLevel == 'Medium'
                                    ? Colors.orange.shade800
                                    : Colors.green.shade800,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Emergency Level: $emergencyLevel',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_isRefreshing)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isCentralAdmin ? _showQuickAlertDialog : null, // Only central admin can send alerts
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Text('Quick Alert'),
                      ),
                    ],
                  ),
                ),

                // Rest of the dashboard content remains the same
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Public Safety Control Center Section
                        const Padding(
                          padding: EdgeInsets.only(left: 8, bottom: 8),
                          child: Text(
                            'Public Safety Control Center',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        
                        // Rest of the existing content...
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Active Cases',
                                activeCase.toString(),
                                const Color(0xFF003366),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Stack(
                                children: [
                                  _buildStatCard(
                                    'Critical Cases',
                                    criticalCases.toString(),
                                    Colors.red,
                                  ),
                                  // Notification badge for critical cases
                                  if (_hasPendingCriticalCases())
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  _buildStatCard(
                                    'New Reports Today',
                                    newReports.toString(),
                                    const Color(0xFF003366),
                                  ),
                                  // Notification badge for new reports
                                  if (_hasNewUnreadReports())
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // NUCLEAR OPTION: Completely independent Response Rate card
                            // This uses direct calculation in the widget tree with no dependencies
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.shade300,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Response Rate',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Builder(builder: (context) {
                                      // Get data directly from what's displayed in the UI
                                      int pendingCases = 0;
                                      int totalCases = 0;
                                      
                                      // Count directly from filteredReports
                                      totalCases = filteredReports.length;
                                      pendingCases = filteredReports.where((report) => 
                                        report['status'] == 'Pending').length;
                                      
                                      // Add debug print (can remove later)
                                      debugPrint('RESPONSE RATE: Total=$totalCases, Pending=$pendingCases');
                                      
                                      // Prevent division by zero
                                      if (totalCases == 0) {
                                        return const Text(
                                          '0%',
                                          style: TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        );
                                      }
                                      
                                      // Calculate percentage
                                      int rate = ((totalCases - pendingCases) / totalCases * 100).round();
                                      
                                      // Hard cap at 99% if any pending cases
                                      if (pendingCases > 0 && rate == 100) {
                                        rate = 99;
                                      }
                                      
                                      // Debug print the final value (can remove later)
                                      debugPrint('CALCULATED RESPONSE RATE: $rate%');
                                      
                                      // Determine color based on rate
                                      Color color;
                                      if (rate >= 90) {
                                        color = Colors.green;
                                      } else if (rate >= 70) {
                                        color = Colors.orange;
                                      } else {
                                        color = Colors.red;
                                      }
                                      
                                      return Row(
                                        children: [
                                          Text(
                                            '$rate%',
                                            style: TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                          if (_isRefreshing)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 8),
                                              child: SizedBox(
                                                width: 16, 
                                                height: 16, 
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.5)),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),

                        // District Activity Map
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade300,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'District Activity Map',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _exportDistrictActivityMap,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF003366),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    icon: const Icon(Icons.download),
                                    label: const Text('Export PDF'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.map,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Interactive District Map',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade300,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Recent Reports',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (_isRefreshing)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8),
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
                                              ),
                                            ),
                                          ),
                                        // New indicator for unread reports
                                        if (_hasNewUnreadReports())
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'NEW',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Container(
                                      width: 200,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: TextField(
                                        controller: _searchController,
                                        decoration: const InputDecoration(
                                          hintText: 'Search reports...',
                                          prefixIcon: Icon(Icons.search),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        onChanged: _filterReports,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (filteredReports.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                      child: Text(
                                        'No recent reports',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  ...filteredReports.map((report) => _buildReportItem(report)).toList(),
                              ],
                            ),
                          ),

                        // Recent Activities Section
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade300,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Recent Activities',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_isRefreshing)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (recentActivities.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Text(
                                      'No recent activities',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: recentActivities.length,
                                  itemBuilder: (context, index) {
                                    final activity = recentActivities[index];
                                    final DateTime createdAt = DateTime.parse(activity['created_at']);
                                    final String formattedTime = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
                                    
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.blue.shade100,
                                        child: const Icon(Icons.history, color: Color(0xFF003366)),
                                      ),
                                      title: Text(
                                        activity['action'] ?? 'Unknown action',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        'Case: ${activity['incidents']['incident_type']}',
                                      ),
                                      trailing: Text(
                                        formattedTime,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}
Widget _buildAddAdminForm() {
  return GestureDetector(
    onTap: () => FocusScope.of(context).unfocus(),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Add Admin Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _showAddAdminForm = false;
            });
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_successMessage != null)
                  _buildSuccessMessage(),
                if (_errorMessage != null)
                  _buildErrorMessage(),
                const SizedBox(height: 16),
                _buildFormFields(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildSuccessMessage() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.green.shade300),
    ),
    child: Row(
      children: [
        Icon(Icons.check_circle, color: Colors.green.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Success!',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _successMessage!,
                style: TextStyle(color: Colors.green.shade700),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildErrorMessage() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.red.shade300),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline, color: Colors.red.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _errorMessage!,
            style: TextStyle(color: Colors.red.shade800),
          ),
        ),
      ],
    ),
  );
}

Widget _buildFormFields() {
  return Column(
    children: [
      TextFormField(
        controller: _firstNameController,
        decoration: const InputDecoration(
          labelText: 'First Name',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person),
        ),
        textInputAction: TextInputAction.next,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter first name';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _lastNameController,
        decoration: const InputDecoration(
          labelText: 'Last Name',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person_outline),
        ),
        textInputAction: TextInputAction.next,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter last name';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.email),
        ),
        textInputAction: TextInputAction.next,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter email';
          }
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Please enter a valid email';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _passwordController,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Password',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.lock),
        ),
        textInputAction: TextInputAction.done,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter password';
          }
          if (value.length < 8) {
            return 'Password must be at least 8 characters';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        value: _selectedStationId,
        decoration: const InputDecoration(
          labelText: 'Assign to Police Station',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.location_on),
        ),
        items: _policeStations.map<DropdownMenuItem<String>>((station) {
          return DropdownMenuItem<String>(
            value: station['id'],
            child: Text(station['name']),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedStationId = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a police station';
          }
          return null;
        },
      ),
      if (_isCentralAdmin)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'As Central Admin, you can assign to any station',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 12,
            ),
          ),
        ),
      if (!_isCentralAdmin && _currentPoliceStationName != null)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'Assigned to $_currentPoliceStationName',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: 12,
            ),
          ),
        ),
    ],
  );
}

Widget _buildSubmitButton() {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: _isLoading ? null : _addAdmin,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF003366),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : const Text(
              'CREATE ADMIN ACCOUNT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    ),
  );
}

}