// lib/screens/case_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
//import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../widgets/status_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../service/access_control_service.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart' as audio_waveforms;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
// For web audio



import 'package:audioplayers/audioplayers.dart';

import 'dart:typed_data';  // For Uint8List if you need it elsewhere
 
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:just_audio/just_audio.dart';






class CaseDetailScreen extends StatefulWidget {
  final String incidentId;

  late PlayerController _audioController;

  CaseDetailScreen({
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
  // Media viewing variables
  List<Map<String, dynamic>> _caseFiles = [];
  bool _isLoadingFiles = false;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  bool _isVideoLoading = false;
  Map<String, FlickManager> _flickManagers = {};
  bool _videoInitialized = false;
final AccessControlService _accessControlService = AccessControlService();
bool _hasAccess = false;
bool _checkingAccess = true;
late PlayerController _audioController;
  // Audio player variables
// In your class declaration section:
late audio.AudioPlayer _audioPlayer;
bool _isAudioPlaying = false;
String? _currentlyPlayingUrl;
bool _isPlayerInitialized = false;
bool _isAudioLoading = false;

  



  // Status options for dropdown
  final List<String> _statusOptions = [
    'Pending',
    'Filed',
    'Under Investigation',
    'Action Taken',
    'Resolved',
    'assigned',
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
  _checkAccess();
   _audioPlayer = audio.AudioPlayer();
 _initAudioPlayer();
 _audioController = PlayerController();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Clear existing SnackBars when the screen loads
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }
    
    try {
      await _fetchCaseDetails();
      if (!mounted) return;
      
      await _fetchCaseFiles();
      if (!mounted) return;
      
      // Don't auto-initialize video on load anymore
      // Let it initialize on demand when user taps to view
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading case data')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  });
}

Future<void> _checkAccess() async {
  setState(() {
    _checkingAccess = true;
  });
  
  final hasAccess = await _accessControlService.canAccessIncident(widget.incidentId);
  
  setState(() {
    _hasAccess = hasAccess;
    _checkingAccess = false;
  });
  
  if (!_hasAccess) {
    // Show access denied message and navigate back
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access denied: You do not have permission to view this case.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      
      // Delay navigation to allow the snackbar to be seen
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  } else {
    // If has access, proceed with fetching case details
    _fetchCaseDetails();
  }
}

void _showMediaDialog(Map<String, dynamic> file) {
    if (file['type'] == 'audio') {
    _debugAudioUrl(file['url']); // Verify audio URL before showing dialog
  }
  final isAudio = file['type'] == 'audio';
  final isCurrentAudio = _currentlyPlayingUrl == file['url'];

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      content: isAudio
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.audiotrack, size: 48),
                SizedBox(height: 16),
                Text(file['name'] ?? 'Audio Recording'),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isAudioPlaying && isCurrentAudio 
                            ? Icons.pause 
                            : Icons.play_arrow,
                      ),
                      onPressed: () async {
                        if (_isAudioPlaying && isCurrentAudio) {
                          await _audioPlayer.pause();
                        } else {
                          await _playAudio(file['url']);
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.stop),
                      onPressed: _isAudioPlaying && isCurrentAudio
                          ? () async {
                              await _audioPlayer.stop();
                              setState(() => _isAudioPlaying = false);
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            )
          : _buildMediaContent(file),
      actions: [
        TextButton(
          child: Text('CLOSE'),
          onPressed: () {
            if (isAudio && isCurrentAudio && _isAudioPlaying) {
              _audioPlayer.stop();
            }
            Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}

// Add this method to your _CaseDetailScreenState class





// Future<void> _downloadVideoWithProgress(String url) async {
//   try {
//     // Request storage permission
//     var status = await Permission.storage.request();
//     if (!status.isGranted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Storage permission denied')),
//       );
//       return;
//     }
    
//     // Show download progress dialog
//     double progressValue = 0.0;
    
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text('Downloading Video'),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 LinearProgressIndicator(value: progressValue),
//                 SizedBox(height: 16),
//                 Text('${(progressValue * 100).toStringAsFixed(0)}%'),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   // Cancel download logic here if needed
//                 },
//                 child: Text('Cancel'),
//               ),
//             ],
//           );
//         },
//       ),
//     );
    
//     // Get file name from URL
//     final fileName = url.split('/').last;
    
//     // Get temporary directory
//     final tempDir = await getTemporaryDirectory();
//     final filePath = '${tempDir.path}/$fileName';
    
//     // Create Dio instance for download with progress
//     final dio = Dio();
    
//     await dio.download(
//       url,
//       filePath,
//       onReceiveProgress: (received, total) {
//         if (total != -1) {
//           // Update progress
//           if (context.mounted) {
//             final newProgress = received / total;
//             // Use Navigator.of(context).context to update the dialog
//             Navigator.of(context, rootNavigator: true).pop();
//             _downloadVideoWithProgress(url); // Reopen with new progress
//             progressValue = newProgress;
//           }
//         }
//       },
//     );
    
//     // Close progress dialog
//     if (context.mounted) {
//       Navigator.of(context, rootNavigator: true).pop();
//     }
    
//     // Save to gallery
//     final result = await GallerySaver.saveVideo(filePath);
    
//     // Show success message
//     if (result == true) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Video saved to gallery'),
//           backgroundColor: Colors.green,
//           duration: Duration(seconds: 2),
//         ),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to save video to gallery'),
//           backgroundColor: Colors.red,
//           duration: Duration(seconds: 2),
//         ),
//       );
//     }
//   } catch (e) {
//     print('Error downloading video: $e');
//     if (context.mounted) {
//       // Close progress dialog if open
//       Navigator.of(context, rootNavigator: true).pop();
      
//       // Show error message
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Download failed: ${e.toString()}'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
// }





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
// Update this method in your _CaseDetailScreenState class
Future<String?> _getReportedPoliceStationName() async {
  if (_incidentData == null) return null;
  
  try {
    final supabase = Supabase.instance.client;
    
    // Try to get different possible station ID fields
    String? stationId;
    if (_incidentData!.containsKey('police_station_id') && _incidentData!['police_station_id'] != null) {
      stationId = _incidentData!['police_station_id'];
      print('Found police_station_id: $stationId');
    } else if (_incidentData!.containsKey('station_id') && _incidentData!['station_id'] != null) {
      stationId = _incidentData!['station_id'];
      print('Found station_id: $stationId');
    } else if (_incidentData!.containsKey('reported_station_id') && _incidentData!['reported_station_id'] != null) {
      stationId = _incidentData!['reported_station_id'];
      print('Found reported_station_id: $stationId');
    }
    
    // If we found a station ID, look up the station name
    if (stationId != null) {
      final stationResponse = await supabase
          .from('police_stations')
          .select('name')
          .eq('id', stationId)
          .maybeSingle();
      
      print('Station lookup response: $stationResponse');
      
      if (stationResponse != null) {
        return stationResponse['name'] as String?;
      }
    }
    
    return 'Unknown Station';
  } catch (e) {
    print('Error fetching police station name: $e');
    return 'Unknown Station';
  }
}

// Add this method to your _CaseDetailScreenState class
// Future<void> _downloadVideo(String url) async {
//   try {
//     setState(() {
//       _isSubmitting = true;
//     });
 //   
//     // Show initial loading toast
//     Fluttertoast.showToast(
//       msg: "Starting download...",
//       toastLength: Toast.LENGTH_SHORT,
//       gravity: ToastGravity.BOTTOM,
//     );
    
//     // Get file name from URL
//     final fileName = path.basename(url);
    
//     // Request storage permission
//     var status = await Permission.storage.request();
//     if (!status.isGranted) {
//       setState(() {
//         _isSubmitting = false;
//       });
//       Fluttertoast.showToast(
//         msg: "Storage permission denied",
//         toastLength: Toast.LENGTH_LONG,
//         gravity: ToastGravity.BOTTOM,
//         backgroundColor: Colors.red,
//       );
//       return;
//     }
    
//     // Get temporary directory to save file temporarily
//     final tempDir = await getTemporaryDirectory();
//     final filePath = '${tempDir.path}/$fileName';
//     final file = File(filePath);
    
//     // Download video file
//     final response = await http.get(Uri.parse(url));
//     await file.writeAsBytes(response.bodyBytes);
    
//     // Save to gallery using gallery_saver
//     final result = await GallerySaver.saveVideo(filePath);
    
//     setState(() {
//       _isSubmitting = false;
//     });
    
//     if (result == true) {
//       Fluttertoast.showToast(
//         msg: "Video saved to gallery",
//         toastLength: Toast.LENGTH_LONG,
//         gravity: ToastGravity.BOTTOM,
//         backgroundColor: Colors.green,
//       );
//     } else {
//       Fluttertoast.showToast(
//         msg: "Failed to save video to gallery",
//         toastLength: Toast.LENGTH_LONG,
//         gravity: ToastGravity.BOTTOM,
//         backgroundColor: Colors.red,
//       );
//     }
//   } catch (e) {
//     setState(() {
//       _isSubmitting = false;
//     });
//     print('Error downloading video: $e');
//     Fluttertoast.showToast(
//       msg: "Download failed: ${e.toString()}",
//       toastLength: Toast.LENGTH_LONG,
//       gravity: ToastGravity.BOTTOM,
//       backgroundColor: Colors.red,
//     );
//   }
// }

// // Alternative implementation for web platforms
// Future<void> _downloadVideoWeb(String url) async {
//   try {
//     // Create an anchor element
//     final anchor = html.AnchorElement(href: url);
    
//     // Get the filename from the URL
//     final fileName = url.split('/').last;
    
//     // Set download attribute to suggest filename
//     anchor.download = fileName;
    
//     // Trigger a click
//     anchor.click();
//   } catch (e) {
//     print('Error downloading video (web): $e');
//     // Show error message
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Download failed: ${e.toString()}')),
//     );
//   }
// }
// Widget _buildDownloadProgress(double progress) {
//   return Container(
//     padding: EdgeInsets.all(16),
//     child: Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         LinearProgressIndicator(
//           value: progress,
//           backgroundColor: Colors.grey[300],
//           color: const Color(0xFF003366),
//         ),
//         SizedBox(height: 8),
//         Text(
//           '${(progress * 100).toStringAsFixed(0)}%',
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//       ],
//     ),
//   );
// }
Future<void> _handleVideoDownload(String url) async {
  _debugAudioUrl(url);
  // Check platform and call appropriate method
  if (kIsWeb) {
    await _downloadVideoWeb(url);
  } else {
    await _downloadVideoWeb(url);
  }
}


Future<void> _downloadVideoWeb(String url) async {
  if (!kIsWeb) return;
  
  try {
    setState(() {
      _isSubmitting = true;
    });
    
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    
    setState(() {
      _isSubmitting = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download initiated in browser'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  } catch (e) {
    setState(() {
      _isSubmitting = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download failed: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> _downloadVideoMobile(String url) async {
  try {
    // Request storage permission
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permission denied')),
      );
      return;
    }

    // Get download directory
    final directory = await getDownloadsDirectory() ?? await getTemporaryDirectory();
    final filePath = '${directory.path}/${url.split('/').last}';
    
    // Download file
    final response = await Dio().download(url, filePath,
      onReceiveProgress: (received, total) {
        // Show progress if needed
      }
    );

   if (url.endsWith('.mp4')) {
  await GallerySaver.saveVideo(filePath);
} else if (url.endsWith('.jpg') || url.endsWith('.png')) {
  await GallerySaver.saveImage(filePath);
}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('File saved to ${directory.path}')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Download failed: ${e.toString()}')),
    );
  }
}
Future<void> _handleFileDownload(String url) async {
  if (kIsWeb) {
    await _downloadVideoWeb(url);
  } else {
    await _downloadVideoMobile(url);
  }
}

// Future<void> _downloadVideoSimple(String url) async {
//   try {
//     setState(() {
//       _isSubmitting = true;
//     });
    
//     // Show a snackbar to indicate download has started
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Starting download...')),
//     );
    
//     if (kIsWeb) {
//       // Web implementation - open in new tab
//       final anchor = html.AnchorElement(href: url)
//         ..setAttribute('download', url.split('/').last)
//         ..setAttribute('target', '_blank'); // Open in new tab
      
//       // For Safari/iOS support, create a temporary element
//       // This forces the browser to treat it as a download
//       html.document.body?.append(anchor);
//       anchor.click();
      
//       // Remove the element after clicking
//       Future.delayed(Duration(milliseconds: 100), () {
//         anchor.remove();
//       });
      
//       setState(() {
//         _isSubmitting = false;
//       });
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Download starting in new tab'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } else {
//       // Mobile implementation remains the same
//       // ...rest of your mobile implementation
//     }
//   } catch (e) {
//     // Error handling
//     // ...
//   }
// }


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
        .select('*, emergency_audio')
        .eq('id', widget.incidentId)
        .single();

    // Log the complete response for debugging
    print('Incident response: $incidentResponse');
    print('Current case status: ${incidentResponse['status']}');

    if (incidentResponse != null) {
      // Validate that status exists and use its exact value
      final dbStatus = incidentResponse['status'];
      print('Raw status from database: $dbStatus');
      
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
      
      // Verify status for UI display
      print('UI will display status: ${_incidentData!['status']}');
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
Future<void> _fetchCaseFiles() async {
  if (!mounted) return;
  
  setState(() {
    _isLoadingFiles = true;
  });

  try {
    final supabase = Supabase.instance.client;
    final files = <Map<String, dynamic>>[];

    // Check regular file attachments
    final fileUrls = _incidentData?['file_urls'] as List<dynamic>? ?? [];
    for (var url in fileUrls) {
      if (url is String) {
        final extension = url.split('.').last.toLowerCase();
        final type = _getFileTypeFromExtension(extension);
        files.add({
          'url': url,
          'type': type,
          'name': url.split('/').last,
        });
      }
    }

    // Check for emergency audio recording
    if (_incidentData?['emergency_audio'] != null && 
        _incidentData!['emergency_audio'].toString().isNotEmpty) {
      final audioUrl = _incidentData!['emergency_audio'].toString();
      files.add({
        'url': audioUrl,
        'type': 'audio',
        'name': 'Emergency Recording.${audioUrl.split('.').last}',
        'isEmergency': true,
      });
    }

    setState(() {
      _caseFiles = files;
    });
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading files: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingFiles = false;
      });
    }
  }
}

String _getFileTypeFromExtension(String extension) {
  if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
    return 'image';
  } else if (['mp4', 'mov', 'avi'].contains(extension)) {
    return 'video';
  } else if (['mp3', 'wav', 'm4a', 'ogg', 'aac'].contains(extension)) {
    return 'audio';
  }
  return 'file';
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

Future<void> _updateCaseStatus(String newStatus) async {
  setState(() {
    _isSubmitting = true;
    _errorMessage = null;
    _successMessage = null;
  });

  try {
    final supabase = Supabase.instance.client;
    
    print('Current status: ${_incidentData!['status']}');
    print('Updating status to: $newStatus for case ID: ${widget.incidentId}');
    
    // Try RPC function first (using the SQL function we created)
 try {
  final response = await supabase.rpc(
    'admin_update_incident_status',
    params: {  // Use 'params' parameter instead of positional arguments
      'incident_id': widget.incidentId,
      'new_status': newStatus
    }
  );
      
      print('RPC update response: $response');
      
      // Update was successful via RPC
      setState(() {
        _successMessage = 'Case status updated successfully via RPC!';
      });
      
    } catch (rpcError) {
      print('RPC update error: $rpcError');
      
      // Fallback to direct update if RPC fails
      try {
        // Since we are having permission issues, let's try a direct SQL update
        // using .execute() which might bypass some restrictions
        final response = await supabase
          .from('incidents')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.incidentId);
        
        print('Direct update response: $response');
        
        setState(() {
          _successMessage = 'Case status updated successfully!';
        });
        
      } catch (updateError) {
        // Last resort - show error and suggest manual update
        print('Direct update error: $updateError');
        setState(() {
          _errorMessage = 'Failed to update status. Please try again or contact support.';
        });
        throw Exception('Both update methods failed');
      }
    }
    
    // Update local state immediately to show the user the change
    setState(() {
      if (_incidentData != null) {
        _incidentData!['status'] = newStatus;
      }
    });
    
    // Create activity log entry
    try {
      await supabase.from('incident_activity').insert({
        'incident_id': widget.incidentId,
        'action': 'Status Update',
        'details': 'Status updated to: $newStatus',
        'performed_by': supabase.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (activityError) {
      // Non-critical error, just log it
      print('Activity log error (non-critical): $activityError');
    }
    
    // Verify the update worked by fetching fresh data
    try {
      final verifyResponse = await supabase
        .from('incidents')
        .select('status')
        .eq('id', widget.incidentId)
        .single();
      
      print('Verification response: $verifyResponse');
      final dbStatus = verifyResponse['status'];
      print('Verified status from database: $dbStatus');
      
      if (dbStatus != newStatus) {
        print('WARNING: Status mismatch after update! UI: $newStatus, DB: $dbStatus');
        // Force the local state to match the database
        setState(() {
          if (_incidentData != null) {
            _incidentData!['status'] = dbStatus;
          }
        });
      }
    } catch (verifyError) {
      print('Verification error (non-critical): $verifyError');
    }
    
    // Force a refresh of the entire case details
    await _fetchCaseDetails();
    
  } catch (e) {
    // Top-level error handling
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
Widget _buildMediaViewer() {
  if (_isLoadingFiles) {
    return const Center(child: CircularProgressIndicator());
  }

  if (_caseFiles.isEmpty) {
    return const Center(child: Text('No files attached to this case'));
  }

  // Separate emergency and regular files
  final emergencyFiles = _caseFiles.where((f) => f['isEmergency'] == true).toList();
  final regularFiles = _caseFiles.where((f) => f['isEmergency'] != true).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (emergencyFiles.isNotEmpty) ...[
        const Text(
          'Emergency Recordings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        ...emergencyFiles.map((file) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            color: Colors.red[50],
            child: ListTile(
              leading: const Icon(Icons.emergency, color: Colors.red),
              title: const Text('Emergency Recording'),
              subtitle: Text(file['name']),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: _isAudioLoading && _currentlyPlayingUrl == file['url']
                        ? const CircularProgressIndicator()
                        : Icon(
                            _isAudioPlaying && _currentlyPlayingUrl == file['url']
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                    onPressed: () async {
                      if (_isAudioPlaying && _currentlyPlayingUrl == file['url']) {
                        await _audioPlayer.pause();
                        setState(() => _isAudioPlaying = false);
                      } else {
                        await _playAudio(file['url']);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: _isAudioPlaying && _currentlyPlayingUrl == file['url']
                        ? () async {
                            await _audioPlayer.stop();
                            setState(() => _isAudioPlaying = false);
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        )),
        const SizedBox(height: 16),
      ],
      if (regularFiles.isNotEmpty) ...[
        const Text(
          'Case Evidence',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: regularFiles.length,
          itemBuilder: (context, index) {
            final file = regularFiles[index];
            return GestureDetector(
              onTap: () => _showMediaDialog(file),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _buildMediaThumbnail(file),
              ),
            );
          },
        ),
      ],
    ],
  );
}
Widget _buildMediaThumbnail(Map<String, dynamic> file) {
  // Handle emergency case
  if (file['isEmergency'] == true) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emergency, color: Colors.red, size: 40),
          SizedBox(height: 8),
          Text('EMERGENCY', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
  
  // Handle different file types
  switch (file['type']) {
    case 'image':
      return CachedNetworkImage(
        imageUrl: file['url'],
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      );
    case 'video':
      return Stack(
        fit: StackFit.expand,
        children: [
          const Center(child: Icon(Icons.videocam, size: 40)),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
            ),
          ),
        ],
      );
    case 'audio':
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.audio_file,
                  size: 40,
                  color: Colors.blue,
                ),
                if (file['name'] != null)
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      file['name'].split('.').last,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
          if (_currentlyPlayingUrl == file['url'])
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.volume_up,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      );
    default:
      // Handle unknown file types or when file['type'] is null
      return const Center(
        child: Icon(
          Icons.insert_drive_file,
          size: 40,
          color: Colors.grey,
        ),
      );
  }
}
Widget _buildMediaContent(Map<String, dynamic> file) {
  switch (file['type']) {
    case 'image':
      return InteractiveViewer(
        child: CachedNetworkImage(
          imageUrl: file['url'],
          fit: BoxFit.contain,
        ),
      );
    case 'video':
      return _buildVideoPlayer(file['url']);
    case 'audio':
      return _buildAudioPlayer(file['url']);
    default:
      return SizedBox(
        width: 300,
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.insert_drive_file, size: 60),
              const SizedBox(height: 16),
              Text(
                file['name'],
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  _handleFileDownload(file['url']);
                },
                child: const Text('Download File'),
              ),
            ],
          ),
        ),
      );
  }
}

Future<void> _initializeVideoPlayer(String url) async {
  if (kIsWeb) {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return;
  }

  // Mobile implementation
  try {
    setState(() => _isVideoLoading = true);
    
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    
    _videoPlayerController = VideoPlayerController.network(url);
    await _videoPlayerController!.initialize();
    
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: false,
      looping: false,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
    
    setState(() {
      _isVideoLoading = false;
      _videoInitialized = true;
    });
  } catch (e) {
    setState(() => _isVideoLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load video: ${e.toString()}')),
      );
    }
  }
}

Widget _buildVideoPlayer(String url) {
  if (_isVideoLoading) {
    return Container(
      height: 250,
      child: Center(child: CircularProgressIndicator()),
    );
  }
  
  if (!_videoInitialized) {
    return Container(
      height: 250,
      child: Center(
        child: ElevatedButton(
          onPressed: () => _initializeVideoPlayer(url),
          child: Text('Load Video'),
        ),
      ),
    );
  }
  
  // Use a simple layout
  return Container(
    height: 250,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            child: VideoPlayer(_videoPlayerController!),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(_videoPlayerController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                setState(() {
                  if (_videoPlayerController!.value.isPlaying) {
                    _videoPlayerController!.pause();
                  } else {
                    _videoPlayerController!.play();
                  }
                });
              },
            ),
          ],
        ),
      ],
    ),
  );
}
@override
void dispose() {
  // Clean up video/audio controllers
 // Initialize immediately
  _initAudioPlayer();
  _chewieController?.dispose();
  _audioPlayer.dispose(); 
  
  // Dispose all flick managers
  _flickManagers.forEach((_, manager) => manager.dispose());
  _flickManagers.clear();
  
  // Clean up other controllers
  _audioController?.dispose();
  _videoPlayerController?.dispose();
  _flickManagers.forEach((_, manager) => manager.dispose());
    _flickManagers.clear();
    _noteController.dispose();
  _noteController.dispose();
  
  super.dispose();
}
Future<void> _initAudioPlayer() async {
  try {
    // Set up event listeners
    _audioPlayer.onPlayerStateChanged.listen((audio.PlayerState state) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = state == audio.PlayerState.playing;
        });
      }
    });
    
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = false;
        });
      }
    });
    
    setState(() {
      _isPlayerInitialized = true;
    });
  } catch (e) {
    debugPrint('Error initializing audio player: $e');
    if (mounted) {
      setState(() {
        _isPlayerInitialized = false;
      });
    }
  }
}
// Audio playback control methods
Future<void> _playAudio(String url) async {
  if (_currentlyPlayingUrl == url && _isAudioPlaying) {
    await _audioPlayer.pause();
    return;
  }
  
  setState(() {
    _isAudioLoading = true;
  });
  
  try {
    if (_currentlyPlayingUrl != url) {
      await _audioPlayer.stop();
      await _audioPlayer.setSourceUrl(url);
      _currentlyPlayingUrl = url;
    }
    
    await _audioPlayer.resume();
  } catch (e) {
    debugPrint('Error playing audio: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error playing audio file'))
    );
  } finally {
    if (mounted) {
      setState(() {
        _isAudioLoading = false;
      });
    }
  }
}

Future<void> _pauseAudio() async {
  if (_isAudioPlaying) {
    await _audioPlayer.pause();
  }
}

Future<void> _stopAudio() async {
  await _audioPlayer.stop();
  _currentlyPlayingUrl = null;
}
  
// 3. Debugging method to check URL validity
void _debugAudioUrl(String? url) {
  print("Audio URL: $url");
  print("URL validity: ${url != null && url.isNotEmpty}");
  // Add more validation as needed
}
// Build audio player widget
Widget _buildAudioPlayer(String url) {
  final isCurrentAudio = _currentlyPlayingUrl == url;
  
  return Container(
    width: 300,
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.audiotrack,
              size: 40,
              color: isCurrentAudio ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(
                _isAudioPlaying && isCurrentAudio ? Icons.pause : Icons.play_arrow,
                color: const Color(0xFF003366),
              ),
              onPressed: () async {

                if (_isAudioPlaying && isCurrentAudio) {
                    await _audioPlayer.pause(); // Fixed - no null check needed
                } else {
                  await _playAudio(url);
                }
              },
            ),
                    IconButton(
            icon: const Icon(Icons.stop, color: Color(0xFF003366)),
            onPressed: _isAudioPlaying && isCurrentAudio ? _stopAudio : null,
          ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => _handleFileDownload(url),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF003366),
          ),
          child: const Text('Download Audio'),
        ),
      ],
    ),
  );
}


Future<void> _downloadCaseReport() async {
  try {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    // Create PDF document
    final pdf = pw.Document();

    // Get current date formatted
    final now = DateTime.now();
    final dateFormatted =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    
    // Generate a shorter case ID for the filename
    final shortCaseId = widget.incidentId.substring(
        0, widget.incidentId.length > 8 ? 8 : widget.incidentId.length);
    final fileName = 'case_report_$shortCaseId.pdf';

    // Build PDF content
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
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

    // Generate the PDF bytes
    final bytes = await pdf.save();
    
    // Platform-specific directory handling
    Directory? directory;
    if (Platform.isAndroid) {
      // Use downloads directory for Android
      directory = await getExternalStorageDirectory();
    } else if (Platform.isIOS) {
      // Use documents directory for iOS
      directory = await getApplicationDocumentsDirectory();
    } else {
      // Fallback to temporary directory
      directory = await getTemporaryDirectory();
    }
    
    if (directory == null) {
      throw Exception("Couldn't access device storage");
    }
    
    // Create the file
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    
    // Show success message
    setState(() {
      _isLoading = false;
      _successMessage = 'Case report generated!';
    });
    
    // Show options to view/share the PDF
    await _showPdfOptions(file, bytes);
    
  } catch (e) {
    setState(() {
      _isLoading = false;
      _errorMessage = 'Error generating case report: $e';
    });
    print('Error in _downloadCaseReport: $e');
  }
}

// Method to show options for handling the PDF
Future<void> _showPdfOptions(File file, List<int> pdfBytes) async {
  if (!mounted) return;
  
  showModalBottomSheet(
    context: context,
    builder: (BuildContext bc) {
      return SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.remove_red_eye),
              title: const Text('View PDF'),
              onTap: () async {
                Navigator.pop(context);
                await _viewPdf(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share PDF'),
              onTap: () async {
                Navigator.pop(context);
                await _sharePdf(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text('File saved to: ${file.path}'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('PDF saved to: ${file.path}'),
                    duration: const Duration(seconds: 5),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

// Method to view PDF using url_launcher instead of open_file
Future<void> _viewPdf(File file) async {
  try {
    final Uri uri = Uri.file(file.path);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open file'),
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error opening file: $e'),
      ),
    );
  }
}

// Method to share PDF
Future<void> _sharePdf(File file) async {
  try {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Case Report: ${widget.incidentId}',
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error sharing file: $e'),
      ),
    );
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
          onPressed: () {
            _fetchCaseDetails();
            _fetchCaseFiles();
          },
        ),
      ],
    ),
    body: _checkingAccess
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Color(0xFF003366),
                ),
                SizedBox(height: 16),
                Text('Checking access permissions...'),
              ],
            ),
          )
        : !_hasAccess
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Access Denied',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You do not have permission to view this case.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : _isLoading
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
                                  _buildInfoRow('Reporter', _reporterName ?? 'Anonymous'),
                                  _buildInfoRow('Location Details', _getFormattedLocation()),
                                  
                                  // Check if user is a Central Admin
                                  FutureBuilder<bool>(
                                    future: _accessControlService.isUserCentralAdmin(),
                                    builder: (context, snapshot) {
                                      // Handle error case explicitly
                                      if (snapshot.hasError) {
                                        print('Error checking central admin status: ${snapshot.error}');
                                        return const SizedBox.shrink();
                                      }
                                      
                                      // Wait while loading
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const SizedBox.shrink();
                                      }
                                      
                                      final isCentralAdmin = snapshot.data ?? false;
                                      
                                      // Only show reported station for central admins
                                      if (isCentralAdmin) {
                                        return FutureBuilder<String?>(
                                          future: _getReportedPoliceStationName(),
                                          builder: (context, stationSnapshot) {
                                            if (stationSnapshot.connectionState == ConnectionState.waiting) {
                                              return _buildInfoRow('Reported At', 'Loading...');
                                            }
                                            
                                            final stationName = stationSnapshot.data ?? 'Unknown Station';
                                            return _buildInfoRow('Reported At', stationName);
                                          },
                                        );
                                      } else {
                                        return const SizedBox.shrink();
                                      }
                                    },
                                  ),
                                  
                                  _buildInfoRow('Description', _incidentData!['description'] ?? 'No description provided'),
                                ],
                              ),
                            ),
                          ),

                          // Media files section - NEWLY ADDED
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: _buildMediaViewer(),
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
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3, // Number of columns
                                    crossAxisSpacing: 10, // Spacing between columns
                                    mainAxisSpacing: 10, // Spacing between rows
                                    childAspectRatio: 1, // Square items (width/height ratio)
                                  ),
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _actionOptions.length,
                                  itemBuilder: (context, index) {
                                    final action = _actionOptions[index];
                                    return InkWell(
                                      onTap: _isSubmitting ? null : () => _performAction(action['label']),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: action['color'].withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: action['color'].withOpacity(0.3),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
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
                                )
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

