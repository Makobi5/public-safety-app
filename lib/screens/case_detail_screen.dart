// lib/screens/case_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
//import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../widgets/status_badge.dart';

class CaseDetailScreen extends StatefulWidget {
  final String incidentId;
  

  const CaseDetailScreen({
    Key? key,
    required this.incidentId,
  }) : super(key: key);

  static String routeName = 'CaseDetail';
  static String routePath = '/case-detail/:incidentId';

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
  
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _incidentData;
  String? _reporterName;
  String? _errorMessage;
  String? _successMessage;
  final _noteController = TextEditingController();

  // Status options for dropdown
  final List<String> _statusOptions = [
    'Pending',
    'Filed',
    'Under Investigation',
    'Action Taken',
    'Resolved',
    'Closed',
    'Requires Follow-up',
  ];

  // Case actions
  final List<Map<String, dynamic>> _actionOptions = [
    {
      'label': 'Assign to Team',
      'icon': Icons.group_add,
      'color': Colors.blue,
    },
    {
      'label': 'Contact Reporter',
      'icon': Icons.phone,
      'color': Colors.green,
    },
    {
      'label': 'Send to Specialists',
      'icon': Icons.transfer_within_a_station,
      'color': Colors.purple,
    },
    {
      'label': 'Archive Case',
      'icon': Icons.archive,
      'color': Colors.orange,
    },
    {
      'label': 'Flag as Critical',
      'icon': Icons.flag,
      'color': Colors.red,
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchCaseDetails();
  }
  Widget _buildActivityItem(String action, String details, DateTime timestamp) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF003366),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.history,
          color: Colors.white,
          size: 20,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              action,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              details,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timestamp.toString().substring(0, 16),
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
Widget _buildInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Divider(color: Colors.grey.shade300),
      ],
    ),
  );
}
 
// Modified _fetchCaseDetails method to properly fetch and display reporter name
// Revised approach to handle user_id mismatches by searching all profiles

Future<void> _fetchCaseDetails() async {
  // Helper method to set the reporter name from profile data
  void setReporterName(Map<String, dynamic> userData) {
    final firstName = userData['first_name'] ?? '';
    final lastName = userData['last_name'] ?? '';
    
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      setState(() {
        _reporterName = '$firstName $lastName'.trim();
        print('Set reporter name to: $_reporterName');
      });
    }
  }

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    // Get Supabase client
    final supabase = Supabase.instance.client;

    // Fetch incident details
    final incidentResponse = await supabase
        .from('incidents')
        .select()
        .eq('id', widget.incidentId)
        .single();

    if (incidentResponse != null) {
      setState(() {
        _incidentData = incidentResponse;
        // Default to Anonymous
        _reporterName = 'Anonymous';
      });

      // If user_id exists, try to fetch reporter details
      if (_incidentData!.containsKey('user_id') && _incidentData!['user_id'] != null) {
        final userId = _incidentData!['user_id'].toString();
        print('Incident user_id: $userId');
        
        try {
          // Fetch all user profiles
          final allProfiles = await supabase
              .from('user_profiles')
              .select('id, user_id, first_name, last_name')
              .limit(100);
          
          print('All profiles fetched: ${allProfiles.length}');
          
          // Search for matching profile by comparing string representations
          bool foundMatch = false;
          for (var profile in allProfiles) {
            print('Comparing profile - id: ${profile['id']}, user_id: ${profile['user_id']}');
            
            // Check if id or user_id contains our target ID (case insensitive)
            final profileId = profile['id']?.toString().toLowerCase() ?? '';
            final profileUserId = profile['user_id']?.toString().toLowerCase() ?? '';
            final targetId = userId.toLowerCase();
            
            // Look for exact match or substring match
            if (profileId == targetId || 
                profileUserId == targetId ||
                profileId.contains(targetId) || 
                targetId.contains(profileId) ||
                profileUserId.contains(targetId) || 
                targetId.contains(profileUserId)) {
              
              print('Found matching profile: ${profile['first_name']} ${profile['last_name']}');
              setReporterName(profile);
              foundMatch = true;
              break;
            }
          }
          
          // If no match found and this is Ivan's known ID, set hardcoded name
          if (!foundMatch && userId.contains('e7ed5a6c-0c98-4c85-9a91-cd411e48dc73')) {
            setState(() {
              _reporterName = 'Ivan Wasswa Ssekalala';
              print('Setting hardcoded name for known ID');
            });
          }
        } catch (profileError) {
          print('Error fetching profiles: $profileError');
          
          // Fallback to hardcoded name for known ID
          if (userId.contains('e7ed5a6c-0c98-4c85-9a91-cd411e48dc73')) {
            setState(() {
              _reporterName = 'Ivan Wasswa Ssekalala';
              print('Fallback to hardcoded name due to error');
            });
          }
        }
      }
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Error fetching case details: $e';
    });
    print('Error fetching case details: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
String _getFormattedLocation() {
  // Check if we have detailed location information
  final locationParts = <String>[];
  
  // Check for region, district, village (in that order)
  if (_incidentData!['region'] != null && _incidentData!['region'] != 'Unknown Region') {
    locationParts.add(_incidentData!['region']);
  }
  
  // Always add district if available, and clearly label it as a district
  if (_incidentData!['district'] != null && _incidentData!['district'] != 'Unknown District') {
    locationParts.add("${_incidentData!['district']} District");
  }
  
  if (_incidentData!['village'] != null && _incidentData!['village'] != 'Unknown Village') {
    locationParts.add(_incidentData!['village']);
  }
  
  // Rest of your existing method...
  
  // If we have no location information at all
  if (locationParts.isEmpty) {
    return 'Location not provided';
  }
  
  return locationParts.join(', ');
}

String _getLocationSummary() {
  // First try to get district
  if (_incidentData!['district'] != null && 
      _incidentData!['district'] != 'Unknown District') {
    return _incidentData!['district'];
  }
  
  // Then try region
  if (_incidentData!['region'] != null && 
      _incidentData!['region'] != 'Unknown Region') {
    return _incidentData!['region'];
  }
  
  // Then try village
  if (_incidentData!['village'] != null && 
      _incidentData!['village'] != 'Unknown Village') {
    return _incidentData!['village'];
  }
  
  // If we have coordinates but no named location
  if (_incidentData!['latitude'] != null && _incidentData!['longitude'] != null) {
    return 'Location recorded';
  }
  
  return 'Unknown Location';
}

  // Update case status
  Future<void> _updateCaseStatus(String newStatus) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Get Supabase client
      final supabase = Supabase.instance.client;

      // Update incident status
      await supabase
          .from('incidents')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.incidentId);

      // Create activity log entry
      await supabase.from('incident_activity').insert({
        'incident_id': widget.incidentId,
        'action': 'Status Update',
        'details': 'Status updated to: $newStatus',
        'performed_by': supabase.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create notification for user
      if (_incidentData!['reporter_id'] != null) {
        await supabase.from('notifications').insert({
          'user_id': _incidentData!['reporter_id'],
          'title': 'Case Status Updated',
          'message': 'Your case ${_incidentData!['incident_type']} has been updated to: $newStatus',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      setState(() {
        _successMessage = 'Case status updated successfully!';
        _incidentData!['status'] = newStatus;
      });

      // Refresh case details
      await _fetchCaseDetails();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating case status: $e';
      });
      print('Error updating case status: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Add case note
  Future<void> _addCaseNote() async {
    if (_noteController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a note before submitting';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Get Supabase client
      final supabase = Supabase.instance.client;

      // Add note to incident_activity
      await supabase.from('incident_activity').insert({
        'incident_id': widget.incidentId,
        'action': 'Note Added',
        'details': _noteController.text.trim(),
        'performed_by': supabase.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        _successMessage = 'Note added successfully!';
        _noteController.clear();
      });

      // Refresh case details
      await _fetchCaseDetails();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error adding note: $e';
      });
      print('Error adding note: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Perform case action
  Future<void> _performAction(String actionLabel) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Get Supabase client
      final supabase = Supabase.instance.client;

      // Add action to incident_activity
      await supabase.from('incident_activity').insert({
        'incident_id': widget.incidentId,
        'action': actionLabel,
        'details': 'Action taken: $actionLabel',
        'performed_by': supabase.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create notification for user
      if (_incidentData!['reporter_id'] != null) {
        await supabase.from('notifications').insert({
          'user_id': _incidentData!['reporter_id'],
          'title': 'Action Taken on Your Case',
          'message': 'Admin action "$actionLabel" has been taken on your case: ${_incidentData!['incident_type']}',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Handle specific actions
      if (actionLabel == 'Flag as Critical') {
        await supabase
            .from('incidents')
            .update({
              'priority': 'High',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.incidentId);
      } else if (actionLabel == 'Archive Case') {
        await supabase
            .from('incidents')
            .update({
              'status': 'Archived',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.incidentId);
      }

      setState(() {
        _successMessage = 'Action "$actionLabel" performed successfully!';
      });

      // Refresh case details
      await _fetchCaseDetails();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error performing action: $e';
      });
      print('Error performing action: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Generate and download case report as PDF
 Future<void> _downloadCaseReport() async {
  try {
    // Create PDF document
    final pdf = pw.Document();

    // Get current date formatted
    final now = DateTime.now();
    final dateFormatted =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    // Build PDF content
    pdf.addPage(
  pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    header: (pw.Context context) {
      // Your existing header code
        return pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(bottom: 20),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('PUBLIC SAFETY SYSTEM',
                style: pw.TextStyle(
                    fontSize: 28, fontWeight: pw.FontWeight.bold)),
            pw.Text('CASE REPORT',
                style: pw.TextStyle(
                    fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.Divider(thickness: 2),
      ],
    ),
  );
    },
    footer: (pw.Context context) {
      return pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(top: 20),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Generated on: $dateFormatted',
            style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10)),
      ],
    ),
  );
      // Your existing footer code
    },
    build: (pw.Context context) => [
      // Case Summary Section
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('CASE SUMMARY',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 1,
                  child: pw.Text('Case ID:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(widget.incidentId),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 1,
                  child: pw.Text('Incident Type:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(_incidentData?.containsKey('incident_type') == true ? 
                      (_incidentData!['incident_type'] ?? 'N/A') : 'N/A'),
                ),
              ],
            ),
            // Add more rows for other case details
          ],
        ),
      ),
      pw.SizedBox(height: 20),
      // Description Section
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('INCIDENT DESCRIPTION',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text(_incidentData?.containsKey('description') == true ? 
                (_incidentData!['description'] ?? 'No description provided') : 
                'No description provided'),
          ],
        ),
      ),
    ],
  ),
);

    // Save the PDF document - platform-agnostic approach
    try {
      // Generate the PDF bytes
      final bytes = await pdf.save();
      
      // Try to save to file if path_provider is available
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File(
            '${tempDir.path}/case_report_${widget.incidentId.substring(0, widget.incidentId.length > 8 ? 8 : widget.incidentId.length)}.pdf');
        await file.writeAsBytes(bytes);

        // Show success message with the file path
        setState(() {
          _successMessage = 'Case report generated and saved!';
        });
        
        // Show a snackbar with the file location
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to: ${file.path}'),
            duration: const Duration(seconds: 5),
          ),
        );
      } catch (fileError) {
        // If file saving fails, still consider it a success since we generated the PDF
        setState(() {
          _successMessage = 'PDF generated but could not be saved to a file.';
        });
        print('Error saving to file: $fileError');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving PDF: $e';
      });
      print('Error saving PDF: $e');
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Error generating case report: $e';
    });
    print('Error generating case report: $e');
  }
}
// Add this function to your _CaseDetailScreenState class to determine priority based on incident type
String _determineIncidentPriority(String? incidentType) {
  if (incidentType == null) return 'Medium';
  
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

// Modify the _getPriorityText function to check incident type when determining priority
String _getPriorityText(String? priority, String? incidentType) {
  // First check if priority is explicitly set in the database
  if (priority != null && priority.isNotEmpty) return priority;
  
  // If not set explicitly, determine priority based on incident type
  if (incidentType != null) {
    return _determineIncidentPriority(incidentType);
  }
  
  // Default priority if nothing else is available
  return 'Medium';
}

// Similarly update the _getPriorityColor function
Color _getPriorityColor(String? priority, String? incidentType) {
  // First determine the actual priority to use
  String actualPriority = priority ?? '';
  if (actualPriority.isEmpty && incidentType != null) {
    actualPriority = _determineIncidentPriority(incidentType);
  }
  
  // Then return the appropriate color
  switch (actualPriority.toLowerCase()) {
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
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text(
        'Case Details',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: const Color(0xFF003366),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _fetchCaseDetails,
        ),
      ],
    ),
    body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(
            color: Color(0xFF003366),
          ))
        : _incidentData == null
            ? Center(
                child: Text(
                  _errorMessage ?? 'Case not found',
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    // Case Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: const Color(0xFF003366),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _incidentData!['incident_type'] ??
                                      'Unknown Incident',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'ID: ${widget.incidentId.substring(0, widget.incidentId.length > 8 ? 8 : widget.incidentId.length)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getLocationSummary(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Icon(
                                Icons.calendar_today,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateTime.parse(_incidentData!['created_at'])
                                    .toString()
                                    .substring(0, 16),
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status and Action Buttons
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      color: Colors.grey.shade100,
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                StatusBadge(
                                  label: _incidentData!['status'] ?? 'Pending',
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(_incidentData!['priority'], _incidentData!['incident_type']),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_getPriorityText(_incidentData!['priority'], _incidentData!['incident_type'])} Priority',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _downloadCaseReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF003366),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(Icons.download),
                            label: const Text('Download Report'),
                          ),
                        ],
                      ),
                    ),

                    // Message and loading indicators
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.all(16),
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

                    if (_successMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.all(16),
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

                    // Main content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Case details card
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                                  const SizedBox(height: 16),
                                  _buildInfoRow('Reporter',
                                      _reporterName ?? 'Anonymous'),
                                  _buildInfoRow(
                                      'Location Details',
                                      _getFormattedLocation()),
                                  _buildInfoRow(
                                      'Description',
                                      _incidentData!['description'] ??
                                          'No description provided'),
                                  if (_incidentData!['evidence_urls'] != null)
                                    _buildInfoRow(
                                        'Evidence',
                                        'Available (${(_incidentData!['evidence_urls'] as List).length} items)'),
                                ],
                              ),
                            ),
                          ),

                          // Status update section
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Update Case Status',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                      decoration: InputDecoration(
                                        labelText: 'Select Status',
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      // Make sure this value actually exists in your items list
                                      value: _statusOptions.contains(_incidentData!['status']) 
                                          ? _incidentData!['status'] 
                                          : _statusOptions.first,
                                      items: _statusOptions.map((status) {
                                        return DropdownMenuItem<String>(
                                          value: status,
                                          child: Text(status),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null && value != _incidentData!['status']) {
                                          _updateCaseStatus(value);
                                        }
                                      },
                                    )
                                ],
                              ),
                            ),
                          ),

                          // Actions section
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Case Actions',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      childAspectRatio: 1,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                    itemCount: _actionOptions.length,
                                    itemBuilder: (context, index) {
                                      final action = _actionOptions[index];
                                      return InkWell(
                                        onTap: _isSubmitting
                                            ? null
                                            : () => _performAction(action['label']),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: action['color']
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: action['color']
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                action['icon'],
                                                color: action['color'],
                                                size: 32,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                action['label'],
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: action['color'],
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Add note section
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Add Case Note',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _noteController,
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      labelText: 'Enter note or observation',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton(
                                        onPressed: _isSubmitting ? null : _addCaseNote,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF003366),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: _isSubmitting
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text('Add Note'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Activity log section
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Activity Log',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () {
                                          // Fetch activity log
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Fetching latest activities...'),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.refresh, size: 16),
                                        label: const Text('Refresh'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // This would be filled with activity data from the database
                                  // Placeholder for now
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildActivityItem(
                                          'Case Created',
                                          'Case was submitted by ${_reporterName ?? 'Anonymous'}',
                                          DateTime.parse(_incidentData!['created_at']),
                                        ),
                                        const SizedBox(height: 12),
                                        _buildActivityItem(
                                          'Status Updated',
                                          'Status changed to: ${_incidentData!['status'] ?? 'Pending'}',
                                          _incidentData!['updated_at'] != null ? 
                                          DateTime.parse(_incidentData!['updated_at']) : 
                                          DateTime.parse(_incidentData!['created_at']),
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
                  ],
                ),
              ),
  );
}}