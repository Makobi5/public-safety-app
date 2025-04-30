// lib/screens/user_dashboard.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../service/auth_service.dart';
import 'incident_report_form.dart';
import 'report_details_screen.dart'; // New import for report details
import 'package:flutter/widgets.dart' as widgets;
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_sound_web/flutter_sound_web.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';
import 'dart:typed_data';
import 'dart:html' as html;




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
  bool _isRecording = false;
  String? _audioPath;
  final _audioRecorder = Record();
  

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

Future<void> _startRecording() async {
  try {
    // Check and request permissions
    if (!kIsWeb && !(await Permission.microphone.request().isGranted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return;
    }

    // Platform-specific file path handling
    String filePath;
    if (kIsWeb) {
      // Web-specific path
      filePath = 'emergency_recording_${DateTime.now().millisecondsSinceEpoch}.aac';
    } else {
      // Mobile path
      try {
        Directory appDocDir = await getApplicationDocumentsDirectory();
        filePath = '${appDocDir.path}/emergency_recording_${DateTime.now().millisecondsSinceEpoch}.aac';
      } catch (e) {
        print('Error getting application directory: $e');
        Directory tempDir = await getTemporaryDirectory();
        filePath = '${tempDir.path}/emergency_recording_${DateTime.now().millisecondsSinceEpoch}.aac';
      }
    }

    // Check if the recorder is already initialized and can record
    try {
      if (kIsWeb || await _audioRecorder.hasPermission()) {
        setState(() {
          _isRecording = true;
        });

        await _audioRecorder.start(
          path: filePath,
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          samplingRate: 44100,
        );

        setState(() {
          _audioPath = filePath;
        });
        
        // Show recording indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording in progress... Press the button again to stop and submit.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording permission not available')),
        );
      }
    } catch (recorderError) {
      print('Error initializing recorder: $recorderError');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording initialization error: $recorderError')),
      );
      setState(() {
        _isRecording = false;
      });
    }
  } catch (e) {
    print('Recording error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error starting recording: $e')),
    );
    setState(() {
      _isRecording = false;
    });
  }
}

Future<void> _stopRecording() async {
  try {
    if (!_isRecording) return;

    setState(() => _isRecording = false);
    
    // Show a loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Processing recording...'),
        duration: Duration(seconds: 10),
      ),
    );
    
 if (kIsWeb) {
  // Web-specific handling
  final result = await _audioRecorder.stop();
  
  if (result != null) {
    Uint8List? audioBytes;
    
    // Handle different return types for web - with proper type checking
    if (result is Uint8List) {
      // Already in the correct format
      audioBytes = result as Uint8List?;
    } else if (result is List) {
      // More generic List handling
      try {
        final List<int> intList = result.map((item) => item as int).toList();
        audioBytes = Uint8List.fromList(intList);
      } catch (e) {
        print('Error converting List to Uint8List: $e');
        // Fallback to dummy data
        audioBytes = Uint8List(1024);
      }
    } else if (result is String) {
      // For testing in Chrome, just create a dummy audio file
      print('Creating dummy audio data for testing');
      audioBytes = Uint8List(1024); // 1KB of zeros for testing
    }
    
    // If we successfully got audio bytes, submit them
    if (audioBytes != null) {
      await _submitEmergencyReport('web_recording.aac', audioBytes);
    }
  }
}
  } catch (e) {
    print('Stop recording error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error stopping recording: ${e.toString()}')),
    );
  }
}
Future<void> _submitEmergencyReport(String audioPath, [Uint8List? webAudioBytes]) async {
  try {
    setState(() => _isRefreshing = true);
    
    // 1. Get location
    String locationText = "Unknown location";
    try {
      if (!kIsWeb) {
        // Check location permission for mobile
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        
        if (permission != LocationPermission.denied && 
            permission != LocationPermission.deniedForever) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high
          );
          
          // Try to get address from coordinates
          try {
            List<Placemark> placemarks = await placemarkFromCoordinates(
              position.latitude, 
              position.longitude
            );
            
            if (placemarks.isNotEmpty) {
              final place = placemarks.first;
              locationText = '${place.street}, ${place.locality}, ${place.country}';
            } else {
              locationText = 'Lat: ${position.latitude}, Long: ${position.longitude}';
            }
          } catch (e) {
            locationText = 'Lat: ${position.latitude}, Long: ${position.longitude}';
          }
        }
      } else {
        // Web location is handled differently
        locationText = 'Location Services not available in web';
      }
    } catch (e) {
      print('Error getting location: $e');
      locationText = 'Location unavailable';
    }
    
    // 2. Upload audio
    String? audioUrl;
    final supabase = Supabase.instance.client;
    final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.aac';

    if (kIsWeb && webAudioBytes != null) {
      // Convert to List<int> if needed
      final bytes = webAudioBytes is List<int> 
          ? Uint8List.fromList(webAudioBytes) 
          : webAudioBytes;
      
      final uploadResponse = await supabase.storage
          .from('emergency-recordings')
          .uploadBinary(fileName, bytes);
      
      audioUrl = supabase.storage
          .from('emergency-recordings')
          .getPublicUrl(fileName);
    } else if (!kIsWeb) {
      final file = File(audioPath);
      final bytes = await file.readAsBytes();
      await supabase.storage
          .from('emergency-recordings')
          .uploadBinary(fileName, bytes);
      
      audioUrl = supabase.storage
          .from('emergency-recordings')
          .getPublicUrl(fileName);
    }

    // 3. Create report
    final user = AuthService.currentUser;
    if (user != null) {
      // Generate a reference number
      final referenceNum = 'E${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      
      // Create the incident record
            final incidentData = {
            'user_id': user.id,
            'title': 'Emergency Report',
            'description': 'Emergency audio recording submitted',
            'incident_type': 'emergency',
            'status': 'submitted',
            'emergency_audio': audioUrl,
            'is_emergency': true,
            'is_anonymous': false, // Default for emergency reports
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'incident_date': DateTime.now().toIso8601String(),
            'incident_time': '${DateTime.now().hour}:${DateTime.now().minute}',
            
            // Location fields - you should populate these from your location service
            'region': 'Unknown', // Default, should be updated with real data
            'district': 'Unknown', // Default, should be updated with real data
            'village': 'Unknown', // Default, should be updated with real data
            'latitude': 0.0, // Default, should be updated with real GPS data
            'longitude': 0.0, // Default, should be updated with real GPS data
            'location_address': 'Location not specified', // Default
            
            // Optional fields that can be null
            'additional_location': null,
            'additional_notes': null,
            'file_urls': null,
            'witness_info': null,
            'landmark': null,
            'reported_station_id': null,
            'station_id': null,
            'police_station_id': null,
            'police_station_name': null,
            'police_station_assigned_at': null, // Note: You should fix this column name in DB
          };
      
      final response = await supabase
          .from('incidents')
          .insert(incidentData)
          .select('id')
          .single();
      
      if (response != null && response['id'] != null) {
        // Add activity for the emergency submission
        await supabase.from('incident_activity').insert({
          'incident_id': response['id'],
          'action': 'Emergency Recording Submitted',
          'performed_by': user.id,
          'details': 'Emergency audio recording received and submitted for review',
          'created_at': DateTime.now().toIso8601String(),
          
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency report submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the reports list
        await _fetchActiveReports();
      }
    }
  } catch (e) {
    print('Submission error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Emergency submission failed: ${e.toString()}')),
    );
  } finally {
    setState(() => _isRefreshing = false);
  }
}

@override
void dispose() {
  _audioRecorder.dispose();
  super.dispose();
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
Widget _buildEmergencyButton() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Center(
      child: SizedBox(
        height: 44,
        child: ElevatedButton.icon(
          onPressed: () {
            if (_isRecording) {
              _stopRecording();
            } else {
              _startRecording();
            }
          },
          icon: _isRecording 
              ? const Icon(Icons.stop, size: 18)
              : const Icon(Icons.emergency, size: 18),
          label: Text(
            _isRecording ? 'Stop Emergency Recording' : 'Report Emergency',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRecording ? Colors.red.shade700 : Colors.red[800],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
    ),
  );
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
          onPressed: _isRefreshing ? null : _fetchActiveReports,
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
                  
                  // Emergency Recording Button - Added here before Report New Case button
                  _buildEmergencyButton(),
                  
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

extension on String {
  map(int Function(dynamic item) param0) {}
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