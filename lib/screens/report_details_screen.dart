// lib/screens/report_details_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../service/auth_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class ReportDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const ReportDetailsScreen({
    Key? key,
    required this.report,
  }) : super(key: key);

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _progressUpdates = [];
  List<Map<String, dynamic>> _adminNotes = [];
  final supabase = Supabase.instance.client;

@override
void initState() {
  super.initState();
  _tabController = TabController(length: 3, vsync: this);
  _loadReportDetails();
  
  // Initialize admin notes
  _adminNotes = [];
  if (widget.report['admin_notes'] != null) {
    _adminNotes = List<Map<String, dynamic>>.from(widget.report['admin_notes']);
    // Sort by date (newest first)
    _adminNotes.sort((a, b) => 
      DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
  }
}

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load progress updates
      if (widget.report['incident_progress'] != null) {
        _progressUpdates = List<Map<String, dynamic>>.from(widget.report['incident_progress']);
        // Sort by date (newest first)
        _progressUpdates.sort((a, b) => 
          DateTime.parse(b['updated_at']).compareTo(DateTime.parse(a['updated_at'])));
      }

      // Load admin notes
      if (widget.report['admin_notes'] != null) {
        _adminNotes = List<Map<String, dynamic>>.from(widget.report['admin_notes']);
        // Sort by date (newest first)
        _adminNotes.sort((a, b) => 
          DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report details: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

String getFormattedLocation(Map<String, dynamic> report) {
  // Extract location data
  final locationParts = <String>[];
  
  // Check for structured location data (region, district, village)
  if (report['region'] != null && report['region'] != 'Unknown Region') {
    locationParts.add(report['region']);
  }
  
  // Always add district if available, and clearly label it as a district
  if (report['district'] != null && report['district'] != 'Unknown District') {
    locationParts.add("${report['district']} District");
  }
  
  if (report['village'] != null && report['village'] != 'Unknown Village') {
    locationParts.add(report['village']);
  }
  
  // Rest of your existing method...
  
  // If we have no location information at all
  if (locationParts.isEmpty) {
    return report['location'] ?? 'Unknown location';
  }
  
  return locationParts.join(', ');
}

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final title = report['title'] ?? 'Untitled Report';
    final reference = report['reference'] ?? 'No Reference';
    final status = report['status'] ?? 'Pending';
    final description = report['description'] ?? 'No description provided';
    final createdAt = report['created_at'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Report Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF003366),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Progress'),
            Tab(text: 'Admin Notes'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Details Tab
                _buildDetailsTab(report),
                
                // Progress Tab
                _buildProgressTab(),
                
                // Admin Notes Tab
                _buildAdminNotesTab(),
              ],
            ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF003366),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Status: ',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
        ),
      ),
    );
  }
Widget _buildDetailsTab(Map<String, dynamic> report) {
  final title = report['title'] ?? 'Untitled Report';
  final reference = report['reference'] ?? 'No Reference';
  final description = report['description'] ?? 'No description provided';
  final createdAt = report['created_at'] ?? '';
  final updatedAt = report['updated_at'] ?? createdAt;
  final location = report['location'] ?? 'Unknown location';
  final category = report['category'] ?? 'Uncategorized';

  // Create detail widgets
  List<Widget> detailWidgets = [
    // Case Information Card
    Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
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
              'Case Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            _buildInfoRow('Title:', title),
            _buildInfoRow('Reference:', reference),
            _buildInfoRow('Category:', category),
            _buildInfoRow('Location:', getFormattedLocation(report)),
            _buildInfoRow('Reported on:', _formatDate(createdAt)),
            if (createdAt != updatedAt)
              _buildInfoRow('Last update:', _formatDate(updatedAt)),
          ],
        ),
      ),
    ),

    // Description Card
    Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
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
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  ];

  // Add additional details card if available
  if (report['additional_details'] != null && report['additional_details'].toString().isNotEmpty) {
    detailWidgets.add(
      Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
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
                'Additional Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 24),
              Text(
                report['additional_details'].toString(),
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Return the widgets wrapped in SingleChildScrollView
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: detailWidgets,
    ),
  );
}
Widget _buildProgressTab() {
  // Filter activities for status updates
  final progressUpdates = widget.report['incident_activity'] != null 
      ? List<Map<String, dynamic>>.from(widget.report['incident_activity'])
          .where((activity) => 
            activity['action'] == 'Status Update')
          .toList()
      : [];
  
  if (progressUpdates.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No progress updates yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for updates on your case',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // Sort by date (newest first)
  progressUpdates.sort((a, b) => 
    DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
  
  // Create update widgets
  List<Widget> updateWidgets = [];
  
  for (var update in progressUpdates) {
    final details = update['details'] ?? 'No details provided';
    final createdAt = update['created_at'] ?? '';
    final updatedBy = update['performed_by'] ?? 'Staff';
    
    updateWidgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
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
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.update,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status Update',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Updated by Administrator • ${_getTimeSince(createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  details,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Return the widgets wrapped in SingleChildScrollView
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: updateWidgets,
    ),
  );
}
  // Helper methods
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown date';
    }
  }
  
  String _getTimeSince(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return timeago.format(date);
    } catch (e) {
      return 'Unknown time';
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
    
Widget _buildAdminNotesTab() {
  // Filter activities for admin notes
  final adminNotes = widget.report['incident_activity'] != null 
      ? List<Map<String, dynamic>>.from(widget.report['incident_activity'])
          .where((activity) => 
            activity['action'] == 'Note Added' || 
            activity['action'] == 'Flag as Critical')
          .toList()
      : [];
  
  if (adminNotes.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_alt_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No admin notes available',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Admin notes will appear here when added',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
  
  // Sort by date (newest first)
  adminNotes.sort((a, b) => 
    DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
  
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: adminNotes.map((note) {
        final noteText = note['details'] ?? 'No content';
        final createdAt = note['created_at'] ?? '';
        final adminName = note['performed_by_name'] ?? 'Administrator';
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
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
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.person_outline,
                          color: Colors.purple.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              adminName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getTimeSince(createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    noteText,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

}
    
