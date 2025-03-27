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
  
  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;
  bool _showAddAdminForm = false;
  String? _currentUserName;

  // Dashboard data from database
  int activeCase = 0;
  int criticalCases = 0;
  int newReports = 0;
  String emergencyLevel = 'Low';
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
  
  // Add this to set up a timer to check for new reports periodically
  Future.delayed(const Duration(seconds: 1), () {
    _checkForNewReports();
  });
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
// Periodically check for new reports
Future<void> _checkForNewReports() async {
  try {
    final supabase = Supabase.instance.client;
    
    // If this is the first check, just record the current time
    if (lastFetchTime == null) {
      lastFetchTime = DateTime.now();
      return;
    }
    
    // Format the lastFetchTime as an ISO string for the Supabase query
    final lastCheckTime = lastFetchTime!.toIso8601String();
    
    // Query for reports created after the last check time
    final newReportsResponse = await supabase
        .from('incidents')
        .select()
        .gt('created_at', lastCheckTime)
        .order('created_at', ascending: false);
    
    if (newReportsResponse != null && newReportsResponse is List && newReportsResponse.isNotEmpty) {
      final newReportsData = newReportsResponse.cast<Map<String, dynamic>>();
      
      // Update lastFetchTime to now
      lastFetchTime = DateTime.now();
      
      // Add new reports to notifications
      for (var report in newReportsData) {
        final DateTime createdAt = DateTime.parse(report['created_at']);
        final String formattedTime = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
        
        notifications.add({
          'id': report['id'],
          'title': 'New ${report['incident_type'] ?? 'Unknown Incident'}',
          'message': 'New incident reported in ${report['district'] ?? 'Unknown Location'}',
          'time': formattedTime,
          'read': false,
          'priority': _getIncidentPriority(report['incident_type']),
        });
      }
      // Add after _checkForNewReports method

      
      // Update unread count
      setState(() {
        unreadNotifications = notifications.where((n) => n['read'] == false).length;
      });
      
      // Refresh the dashboard data to include the new reports
      _fetchDashboardData();
    }
    
    // Schedule the next check
    Future.delayed(const Duration(seconds: 30), () {
      _checkForNewReports();
    });
    
  } catch (e) {
    print('Error checking for new reports: $e');
    
    // Even if there's an error, schedule the next check
    Future.delayed(const Duration(seconds: 30), () {
      _checkForNewReports();
    });
  }
}
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
                    onTap: () {
                      // Mark notification as read
                      setState(() {
                        notifications[index]['read'] = true;
                        unreadNotifications = notifications.where((n) => n['read'] == false).length;
                      });
                      
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
                        // Refresh dashboard data when returning
                        _fetchDashboardData();
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Mark all as read
            setState(() {
              for (var i = 0; i < notifications.length; i++) {
                notifications[i]['read'] = true;
              }
              unreadNotifications = 0;
            });
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
  // Fetch dashboard data from database
  Future<void> _fetchDashboardData() async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Get Supabase client
    final supabase = Supabase.instance.client;
    
    // Fetch all incidents
    final response = await supabase
        .from('incidents')
        .select()
        .order('created_at', ascending: false);
    
    if (response != null && response is List) {
      // Process data for dashboard metrics
      final incidents = response.cast<Map<String, dynamic>>();
      
      // Count total active cases
      activeCase = incidents.length;
      
      // Count critical cases (high priority incidents)
      criticalCases = incidents.where((incident) => 
        _getIncidentPriority(incident['incident_type']) == 'High' ||
        incident['incident_type'] == 'Fire outbreak' || 
        incident['incident_type'] == 'Accident'
      ).length;
      
      // Count new reports today
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      newReports = incidents.where((incident) {
        final createdAt = incident['created_at'] as String;
        return createdAt.startsWith(todayString);
      }).length;
      
      // Determine emergency level based on critical cases percentage
      final criticalPercentage = activeCase > 0 ? (criticalCases / activeCase) * 100 : 0;
      if (criticalPercentage >= 20) {
        emergencyLevel = 'High';
      } else if (criticalPercentage >= 10) {
        emergencyLevel = 'Medium';
      } else {
        emergencyLevel = 'Low';
      }
      
      // Get recent reports (up to 10)
      recentReports = incidents.take(10).map((incident) {
        // Format time
        final DateTime createdAt = DateTime.parse(incident['created_at']);
        final String formattedTime = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
        
        return {
          'id': incident['id'],
          'title': incident['incident_type'] ?? 'Unknown Incident',
          'district': incident['district'] ?? 'Unknown Location',
          'time': formattedTime,
          'priority': _getIncidentPriority(incident['incident_type']),
          'status': incident['status'] ?? 'Pending',
        };
      }).toList();
      
      // Initialize filtered reports
      filteredReports = List.from(recentReports);
      
      // Add this new code for notifications
      // If this is the first fetch, initialize lastFetchTime and create sample notifications
      if (lastFetchTime == null) {
        lastFetchTime = DateTime.now();
        
        // For demo purposes, create some sample notifications
        // In a real app, these would come from backend events
        if (incidents.isNotEmpty && notifications.isEmpty) {
          final sampleIncidents = incidents.take(3).toList();
          for (var incident in sampleIncidents) {
            final DateTime createdAt = DateTime.parse(incident['created_at']);
            final String formattedTime = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
            
            notifications.add({
              'id': incident['id'],
              'title': 'New ${incident['incident_type'] ?? 'Unknown Incident'}',
              'message': 'New incident reported in ${incident['district'] ?? 'Unknown Location'}',
              'time': formattedTime,
              'read': false,
              'priority': _getIncidentPriority(incident['incident_type']),
            });
          }
          
          unreadNotifications = notifications.length;
        }
      }
    }
    
    // Fetch recent activities
    await _fetchRecentActivity();
    
  } catch (e) {
    print('Error fetching dashboard data: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error loading dashboard data: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
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
        // Replace the existing notification button with this Stack
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
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _fetchDashboardData,
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
        Text(
          value,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    ),
  );
}
Widget _buildReportItem(Map<String, dynamic> report) {
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
        // Refresh dashboard data when returning from case detail
        _fetchDashboardData();
      });
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report['title'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
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
  Widget _buildDashboard() {
  return Container(
    color: Colors.grey.shade100,
    child: _isLoading
    ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF003366),
        ),
      )
    : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top header area with emergency level
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: const Color(0xFF003366),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'Emergency Level: $emergencyLevel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
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
        
        // Status Cards
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Public Safety label
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    'Public Safety Control Center',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                // Stats cards in a row for better space usage
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard('Active Cases', activeCase.toString(), Colors.blue.shade800),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard('Critical Cases', criticalCases.toString(), Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard('New Reports Today', newReports.toString(), Colors.blue.shade800),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard('Response Rate', '92%', Colors.green),
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
                      // Simple map visualization placeholder
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
                
                // Recent Reports
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
                          const Text(
                            'Recent Reports',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
                      ...(filteredReports.isEmpty
                          ? [
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
                            ]
                          : filteredReports.map((report) => _buildReportItem(report)).toList()),
                    ],
                  ),
                ),
                
                // Recent Activity Log
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
                      const Text(
                        'Recent Activities',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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