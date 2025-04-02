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
  // Add this field in your _AdminDashboardState class
final NotificationService _notificationService = NotificationService();
  
  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;
  bool _showAddAdminForm = false;
  String? _currentUserName;
  bool _isRefreshing = false;
Map<String, bool> processedIncidents = {}; // Track processed incidents

  // Dashboard data from database
  int activeCase = 0;
  int criticalCases = 0;
  int newReports = 0;
  String emergencyLevel = 'Low';
  int responseRateValue = 92; // Default fallback value
  // Add right after your existing variables in _AdminDashboardState class
// Notification related variables
List<Map<String, dynamic>> notifications = [];
int unreadNotifications = 0;
DateTime? lastFetchTime;
  
  List<Map<String, dynamic>> recentReports = [];
  List<Map<String, dynamic>> recentActivities = [];
  List<Map<String, dynamic>> filteredReports = [];
  
  @override
void initState() {
  super.initState();
  _fetchDashboardData();
  _getCurrentUser();
   _setupNotificationListener();
     _loadNotificationsState(); 
  
  // Add this to set up a timer to check for new reports periodically
// Initialize notification service - will start listening in initState

}
  // Get current user's name for display
  Future<void> _getCurrentUser() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user != null) {
        // Get user profile data
        // Get user profile data
final response = await supabase
    .from('user_profiles')  // Changed from 'profiles' to 'user_profiles'
    .select('first_name, last_name')
    .eq('user_id', user.id)  // Changed from 'id' to 'user_id'
    .single();
            
        if (response != null) {
          final firstName = response['first_name'] as String? ?? '';
          final lastName = response['last_name'] as String? ?? '';
          setState(() {
            _currentUserName = '$firstName $lastName';
          });
        }
      }
    } catch (e) {
      print('Error getting current user: $e');
    }
  }
  // Add after _getCurrentUser method

  // Show notifications dialog
void _showNotificationsDialog() {
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
                 onTap: () async {
                      // Mark notification as read locally
                      setState(() {
                        notifications[index]['read'] = true;
                        unreadNotifications = notifications.where((n) => n['read'] == false).length;
                      });
                      
                      // Save the updated notification state
                      await _saveNotificationsState();
                      
                      // Close the dialog
                      Navigator.of(context).pop();
                      
                      // Navigate to the case detail
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CaseDetailScreen(
                            incidentId: notification['id'],
                          ),
                        ),
                      ).then((_) {
                        // Just refresh dashboard data when returning, don't reprocess notifications
                        _fetchDashboardData();
                        
                        // Make sure to mark this notification as read again in case of a state reset
                        setState(() {
                          final index = notifications.indexWhere((n) => n['id'] == notification['id']);
                          if (index >= 0) {
                            notifications[index]['read'] = true;
                            unreadNotifications = notifications.where((n) => n['read'] == false).length;
                          }
                        });
                        _saveNotificationsState();
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            // Mark all as read locally
            setState(() {
              for (var i = 0; i < notifications.length; i++) {
                notifications[i]['read'] = true;
              }
              unreadNotifications = 0;
            });
            
            // Save the updated notification state
            await _saveNotificationsState();
            
            // Mark all as read in the database
            try {
              final supabase = Supabase.instance.client;
              final user = supabase.auth.currentUser;
              
              if (user != null) {
                // Update all notifications for this user to mark them as read
                await supabase
                    .from('notifications')
                    .update({'is_read': true})
                    .eq('user_id', user.id);
              }
            } catch (e) {
              print('Error marking all notifications as read: $e');
            }
            
            Navigator.of(context).pop();
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
    
    print('Saved ${notifications.length} notifications to storage');
  } catch (e) {
    print('Error saving notifications state: $e');
  }
}
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
        print('Loaded ${notifications.length} notifications from storage');
      } catch (decodeError) {
        print('Error decoding stored notifications: $decodeError');
        // Reset if there's a decode error
        setState(() {
          notifications = [];
          unreadNotifications = 0;
        });
      }
    }
  } catch (e) {
    print('Error loading notifications state: $e');
  }
}

void _setupNotificationListener() {
  // Start monitoring for new incidents
  _notificationService.startIncidentMonitoring(
    interval: const Duration(seconds: 15), // Check every 15 seconds
    onNewIncidents: (newIncidents) {
      if (newIncidents.isNotEmpty) {
        _processNewIncidents(newIncidents);
      }
    },
  );
}
// Check if there are pending critical cases that need attention
bool _hasPendingCriticalCases() {
  // Check if there are critical cases with 'Pending' status
  return recentReports.any((report) => 
    report['priority'] == 'High' && report['status'] == 'Pending');
}

// Check if there are new reports that haven't been viewed
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
// Enhanced report item with unread indicator
Widget _buildReportItem(Map<String, dynamic> report) {
  final bool isUnread = !processedIncidents.containsKey(report['id'].toString());
  
  return InkWell(
    onTap: () {
      // Navigate to case detail screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CaseDetailScreen(
            incidentId: report['id'],
          ),
        ),
      ).then((_) {
        // Mark as processed when returning from detail screen
        if (mounted) {
          setState(() {
            processedIncidents[report['id'].toString()] = true;
          });
          // Save changes to processed incidents
          _saveProcessedIncidents();
          // Refresh dashboard data
          _fetchDashboardData();
        }
      });
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnread ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isUnread ? Colors.blue.shade200 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          if (isUnread)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
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
                  '${report['district']}   ${report['time']}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getPriorityColor(report['priority']),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${report['priority']} Priority',
                  style: TextStyle(
                    color: _getPriorityTextColor(report['priority']),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
void _processNewIncidents(List<Map<String, dynamic>> newIncidents) async {
  if (newIncidents.isEmpty) return;
  
  bool shouldShowNotification = false;
  Map<String, dynamic>? highestPriorityIncident;

  for (var incident in newIncidents) {
    final String reportId = incident['id'].toString();
    if (processedIncidents[reportId] == true) continue;
    
    processedIncidents[reportId] = true;
    final String priority = _notificationService.getIncidentPriority(incident['incident_type']);
    
    // Track highest priority incident
    if (highestPriorityIncident == null || 
        _isHigherPriority(priority, highestPriorityIncident['priority'])) {
      highestPriorityIncident = {
        ...incident,
        'priority': priority,
        'time': DateFormat('HH:mm').format(DateTime.parse(incident['created_at']))
      };
    }
    
    shouldShowNotification = true;
  }

  if (shouldShowNotification && highestPriorityIncident != null) {
    _showNewIncidentNotification(highestPriorityIncident!);
  }
  
  await _saveProcessedIncidents();
  _fetchDashboardData();
}

bool _isHigherPriority(String newPriority, String currentPriority) {
  const priorityOrder = {'High': 3, 'Medium': 2, 'Low': 1};
  return priorityOrder[newPriority]! > priorityOrder[currentPriority]!;
}

Future<void> _saveProcessedIncidents() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('processed_incidents', jsonEncode(processedIncidents));
}
void _showNewIncidentNotification(Map<String, dynamic> incident) {
  final incidentType = incident['incident_type'];
  final district = incident['district'] ?? 'Unknown District';
  final priority = incident['priority'];
  
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
        );
      },
    ),
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
  
  // Also add to notifications list
  setState(() {
    notifications.insert(0, {
      'id': incident['id'],
      'title': 'New $incidentType',
      'message': 'Reported in $district',
      'time': incident['time'],
      'read': false,
      'priority': priority,
    });
    unreadNotifications++;
  });
}

@override
void dispose() {
  // Stop the notification monitoring when widget is disposed
  _notificationService.stopIncidentMonitoring();
  super.dispose();
}

// Update this part in your _fetchDashboardData method
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
    
    // IMPORTANT FIX: Modify how we fetch incident data
    final responses = await Future.wait([
      supabase.from('incidents').select().order('created_at', ascending: false),
      // This query might be missing some "pending" cases if they have null status
      supabase.from('incidents').select('id').not('status', 'eq', 'Pending'),
    ]);

    if (responses[0] != null && responses[0] is List) {
      final incidents = responses[0].cast<Map<String, dynamic>>();
      final respondedIncidents = responses[1]?.cast<Map<String, dynamic>>() ?? [];
      
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
  
  // Fetch recent activities for the dashboard
  Future<void> _fetchRecentActivity() async {
    try {
      // Get Supabase client
      final supabase = Supabase.instance.client;
      
      // Fetch recent activity from incident_activity table
      final response = await supabase
          .from('incident_activity')
          .select('*, incidents!inner(incident_type)')
          .order('created_at', ascending: false)
          .limit(5);
      
      if (response != null && response is List) {
        // Process data for activity log display
        recentActivities = response.cast<Map<String, dynamic>>();
        print('Recent activity fetched: ${recentActivities.length} entries');
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

  Future<void> _addAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    
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
      
      // Call a special method to create admin account
      await AuthService.createAdminAccount(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        userData: userData,
      );
      
      setState(() {
        _successMessage = 'Admin account created successfully!';
        // Clear form fields
        _emailController.clear();
        _passwordController.clear();
        _firstNameController.clear();
        _lastNameController.clear();
        _showAddAdminForm = false; // Return to dashboard view
      });
    } catch (e) {
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
  
  void _exportDistrictActivityMap() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating district activity report...'),
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
                  'Generated on: ${DateTime.now().toString().substring(0, 16)}',
                  style: const pw.TextStyle(
                    fontSize: 12,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'District',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Total Incidents',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Critical Incidents',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    // Sample data rows - in a real implementation, you would
                    // populate this with data from your database
                    ..._generateDistrictRows(),
                  ],
                ),
              ],
            );
          },
        ),
      );
      
      // Save the PDF document
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/district_activity_report.pdf');
      await file.writeAsBytes(await pdf.save());
      
      // Share the PDF file
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved to: ${file.path}'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('District activity report exported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  List<pw.TableRow> _generateDistrictRows() {
    // In a real implementation, you would aggregate incident data by district
    // This is just sample data
    final districts = [
      {'name': 'Kabale', 'total': 12, 'critical': 4},
      {'name': 'Kampala', 'total': 25, 'critical': 8},
      {'name': 'Entebbe', 'total': 8, 'critical': 2},
      {'name': 'Jinja', 'total': 15, 'critical': 5},
      {'name': 'Mbarara', 'total': 10, 'critical': 3},
    ];
    
    return districts.map((district) {
      return pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(district['name'].toString()),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(district['total'].toString()),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(district['critical'].toString()),
          ),
        ],
      );
    }).toList();
  }

void _showQuickAlertDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.red),
          SizedBox(width: 8),
          Text('Send Emergency Alert'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send an emergency alert to all officers and nearby districts?'),
          SizedBox(height: 16),
          TextField(
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Alert Message (Optional)',
              border: OutlineInputBorder(),
              hintText: 'Enter alert details...',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Emergency alert sent to all active units!'),
                backgroundColor: Colors.red,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          icon: Icon(Icons.send),
          label: Text('Send Alert'),
        ),
      ],
    ),
  );
}

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text(
        'Admin Dashboard',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
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
                _showNotificationsDialog();
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Admin Access',
                    style: TextStyle(
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
                        onPressed: _showQuickAlertDialog,
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

                // Dashboard Content
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

                        // Recent Reports Section
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
                                      // New indicator
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
  return SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 24),
            
            // Add Admin Form
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create New Admin Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Success message
                      if (_successMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            _successMessage!,
                            style: TextStyle(color: Colors.green.shade800),
                          ),
                        ),
                      
                      // Error message
                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),
                      
                      // First Name
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter first name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Last Name
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter last name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
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
                      const SizedBox(height: 24),
                      
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _showAddAdminForm = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _addAdmin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF003366),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'Create Admin Account',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}}