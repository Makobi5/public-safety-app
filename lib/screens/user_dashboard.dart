// lib/screens/user_dashboard.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../service/auth_service.dart';
import 'incident_report_form.dart';
import 'report_details_screen.dart'; // New import for report details
import 'package:flutter/widgets.dart' as widgets;

class UserDashboard extends StatefulWidget {
  const UserDashboard({Key? key}) : super(key: key);

  static String routeName = 'UserDashboard';
  static String routePath = '/user-dashboard';

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _userName = 'User';
  List<Map<String, dynamic>> _activeReports = [];
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchActiveReports();
    
    // Listen for auth state changes
    AuthService.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        Navigator.of(context).pushReplacementNamed('/homepage');
      }
    });
  }

  Future<void> _loadUserData() async {
    try {
      final profile = await AuthService.getUserProfile();
      
      if (profile != null) {
        setState(() {
          // Use first_name and last_name from your profile structure
          _userName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}';
          _userName = _userName.trim().isNotEmpty ? _userName : 'User';
          _isLoading = false;
        });
      } else {
        setState(() {
          _userName = 'User';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _userName = 'User';
        _isLoading = false;
      });
    }
  }

Future<void> _fetchActiveReports() async {
  try {
    final user = AuthService.currentUser;
    if (user != null) {
      print('Fetching reports for user: ${user.id}');
      
      // Use the updated query that joins with incident_activity
      final response = await supabase
          .from('incidents')
          .select('''
            *,
            incident_activity(*)
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      
      print('Response received: ${response != null ? response.length : 'null'} reports');
      
      if (response != null) {
        setState(() {
          _activeReports = List<Map<String, dynamic>>.from(response);
          _isRefreshing = false;
        });
        print('Reports set in state: ${_activeReports.length}');
      }
    }
  } catch (e) {
    print('Error fetching active reports: $e');
    setState(() {
      _isRefreshing = false;
    });
  }
}

  @override
Widget build(BuildContext context) {
  return Scaffold(
    key: scaffoldKey,
    appBar: AppBar(
      title: const Text(
        'PSRA',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: const Color(0xFF003366),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
    onPressed: _isRefreshing ? null :  _fetchActiveReports,
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.account_circle),
          onPressed: () {
            Navigator.pushNamed(context, '/profile');
          },
          tooltip: 'Profile',
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            try {
              await AuthService.signOut();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${e.toString()}')),
              );
            }
          },
          tooltip: 'Sign Out',
        ),
      ],
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchActiveReports,
            child: SafeArea(
              child: widgets.ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Welcome banner
                  Container(
                    width: double.infinity,
                    color: const Color(0xFF003366),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Your safety is our priority',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Report New Case button - SMALLER VERSION
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: SizedBox(
                        // Not specifying width makes it wrap content instead of full width
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, 'IncidentReport');
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text(
                            'Report New Case',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Dashboard Cards - with margin that matches UI
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        // Active Reports Card
                        Expanded(
                          child: Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: InkWell(
                              onTap: () {
                                // Scroll to My Reports section
                                Scrollable.ensureVisible(
                                  _myReportsKey.currentContext!,
                                  duration: const Duration(milliseconds: 500),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Active Reports',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${_activeReports.length}',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
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
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade300),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'View all your ongoing cases',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Community Alert Card
                        Expanded(
                          child: Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Community Alert',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Updates for your district',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Divider
                  const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                  
                  // My Reports Section with a key for scrolling and refresh button
                  Padding(
                    key: _myReportsKey,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Reports',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: () {
                            setState(() {
                              _isRefreshing = true;
                            });
                            _fetchActiveReports().then((_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Reports refreshed'),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            });
                          },
                          tooltip: 'Refresh reports',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                  
                  // No Reports Message with debugging information
                  if (_activeReports.isEmpty)
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.only(top: 40, bottom: 40),
                      child: Column(
                        children: [
                          Text(
                            'You have no active reports.',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 15,
                            ),
                          ),
                          // Debug information
                          const SizedBox(height: 20),
                          Text(
                            'Debug Information:',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'User ID: ${AuthService.currentUser?.id ?? 'Not logged in'}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Last refresh: ${DateTime.now().toString().substring(0, 19)}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isRefreshing = true;
                              });
                              _fetchActiveReports().then((_) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Manual data refresh completed'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('Force Refresh Data'),
                          ),
                        ],
                      ),
                    ),
                  
                  // Report List (if there are reports)
                  if (_activeReports.isNotEmpty)
                    widgets.ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _activeReports.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final report = _activeReports[index];
                        return ReportCard(
                          report: report,
                          onTap: () => _openReportDetails(report),
                        );
                      },
                    ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
  );
}
  final GlobalKey _myReportsKey = GlobalKey();

  void _openReportDetails(Map<String, dynamic> report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportDetailsScreen(report: report),
      ),
    ).then((_) {
      // Refresh data when returning from details screen
      _fetchActiveReports();
    });
  }
}

// Enhanced Report Card Widget with tap functionality
class ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onTap;
  
  const ReportCard({
    Key? key,
    required this.report,
    required this.onTap,
  }) : super(key: key);
  
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown date';
    }
  }
  
  String _getTimeSince(String dateString) {
    try {
      final reportDate = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(reportDate);
      
      if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return '$months month${months > 1 ? 's' : ''}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
      } else {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      }
    } catch (e) {
      return 'recently';
    }
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor = Colors.white;
    
    switch (status.toLowerCase()) {
      case 'in progress':
        backgroundColor = Colors.green;
        break;
      case 'pending review':
        backgroundColor = Colors.orange;
        textColor = Colors.black87;
        break;
      case 'resolved':
        backgroundColor = Colors.blue;
        break;
      case 'closed':
        backgroundColor = Colors.grey;
        break;
      case 'submitted':
        backgroundColor = Colors.purple;
        break;
      default:
        backgroundColor = Colors.grey.shade300;
        textColor = Colors.black87;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Get the latest progress info
String _getProgressInfo() {
  final activities = report['incident_activity'];
  if (activities != null && activities is List && activities.isNotEmpty) {
    // Sort by date (newest first)
    final sortedActivities = List.from(activities)
      ..sort((a, b) => DateTime.parse(b['created_at']).compareTo(
          DateTime.parse(a['created_at'])));
    
    // Find status updates
    for (var activity in sortedActivities) {
      if (activity['action'] == 'Status Update') {
        return activity['details'] ?? 'No details available';
      }
    }
  }
  return '';
}

  // Check if there are admin notes
// Check if there are admin notes
bool _hasAdminNotes() {
  final activities = report['incident_activity'];
  if (activities != null && activities is List && activities.isNotEmpty) {
    // Filter for note activities
    return activities.any((activity) => 
      activity['action'] == 'Note Added' || 
      activity['action'] == 'Flag as Critical'
    );
  }
  return false;
}
  
  @override
  Widget build(BuildContext context) {
    final title = report['title'] ?? 'Untitled Report';
    final reference = report['reference'] ?? 'No Reference';
    final status = report['status'] ?? 'Pending';
    final description = report['description'] ?? 'No description provided';
    final createdAt = report['created_at'] ?? '';
    final updatedAt = report['updated_at'] ?? createdAt;
    
    // Get latest progress info
    final progressInfo = _getProgressInfo();
    final hasNotes = _hasAdminNotes();
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Reference: $reference',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              if (description.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (progressInfo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.update, size: 14, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Latest update: $progressInfo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasNotes)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.comment, size: 14, color: Colors.purple[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Admin notes available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Reported: ${_formatDate(createdAt)}' 
                      '${createdAt != updatedAt ? ' • Last Update: ${_getTimeSince(updatedAt)} ago' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}