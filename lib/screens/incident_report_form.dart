// Updated incident_report_form.dart with GPS location

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart'; // Add this package
import 'package:geocoding/geocoding.dart'; // Add this package
import 'dart:convert';
import 'package:http/http.dart' as http;
import '/config/api_keys.dart';
import 'dart:convert';
import '../utils/uganda_regions_mapper.dart';

class IncidentReportFormPage extends StatefulWidget {
  const IncidentReportFormPage({Key? key}) : super(key: key);

  static String routeName = 'IncidentReport';
  static String routePath = '/incident-report';

  @override
  State<IncidentReportFormPage> createState() => _IncidentReportFormPageState();
}

class _IncidentReportFormPageState extends State<IncidentReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedIncidentType;
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _currentStep = 0;
  
  // Location variables
  Position? _currentPosition;
  String _locationAddress = "Location not captured yet";
  bool _isCapturingLocation = false;
  double? _latitude;
  double? _longitude;
  
  // More detailed location information
  String? _detectedRegion;
  String? _detectedDistrict;
  String? _detectedVillage;
  final _additionalLocationController = TextEditingController();
  final _landmarkController = TextEditingController();
  
  @override
  void dispose() {
    _descriptionController.dispose();
    _additionalLocationController.dispose();
    _landmarkController.dispose();
    _witnessInfoController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF003366),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF003366),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep += 1;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
    }
  }

  Widget _buildStepIndicator() {
    final screenSize = MediaQuery.of(context).size;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text(
                'Step ${_currentStep + 1} of 3: ${_getStepTitle(_currentStep)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: screenSize.width * 0.9,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Container(
                width: screenSize.width * 0.9 * ((_currentStep + 1) / 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Incident Details';
      case 1:
        return 'Location Information';
      case 2:
        return 'Evidence & Submission';
      default:
        return '';
    }
  }
  
  // Location permission handling
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are disabled, show dialog to enable
      await _showLocationServiceDialog();
      // Check again after user interaction
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled. Please enable location to continue.')),
        );
        return false;
      }
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied, please enable them in settings')),
      );
      return false;
    }

    return true;
  }

  // Show dialog to prompt user to enable location services
  Future<void> _showLocationServiceDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('To submit your incident report, we need your location.'),
                Text('Please enable location services to continue.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openLocationSettings();
              },
            ),
          ],
        );
      },
    );
  }

 // Update the _getCurrentLocation method to use OSM
Future<void> _getCurrentLocation() async {
  setState(() {
    _isCapturingLocation = true;
  });

  final hasPermission = await _handleLocationPermission();
  if (!hasPermission) {
    setState(() {
      _isCapturingLocation = false;
      // Set default values for required fields
      _detectedRegion = "Unknown Region";
      _detectedDistrict = "Unknown District";
      _detectedVillage = "Unknown Village";
    });
    return;
  }

  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = position;
      _latitude = position.latitude;
      _longitude = position.longitude;
    });

    // Get address from coordinates using OSM
    await _getAddressFromOSM();
  } catch (e) {
    debugPrint('Error getting location: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not get location: $e')),
    );
    
    // Set default values for required fields if location fails
    setState(() {
      _detectedRegion = "Unknown Region";
      _detectedDistrict = "Unknown District";
      _detectedVillage = "Unknown Village";
    });
  } finally {
    setState(() {
      _isCapturingLocation = false;
    });
  }
}

Future<void> _getAddressFromOSM() async {
  try {
    if (_currentPosition != null) {
      setState(() {
        _locationAddress = "Retrieving address...";
        // Initialize with default values for required fields
        _detectedRegion = "Unknown Region";
        _detectedDistrict = "Unknown District";
        _detectedVillage = "Unknown Village";
      });
      
      final lat = _currentPosition!.latitude;
      final lon = _currentPosition!.longitude;
      
      // Using Nominatim API (OpenStreetMap's geocoding service)
      final url = 'https://nominatim.openstreetmap.org/reverse'
          '?format=json'
          '&lat=$lat'
          '&lon=$lon'
          '&zoom=18'
          '&addressdetails=1';
      
      print('Calling OSM Nominatim API: $url');
      
      // Add a user agent as required by Nominatim's usage policy
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'CommunityAppSafeWatch/1.0',
          'Accept-Language': 'en', // Specify language if needed
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('OSM API response: ${response.body}');
        
        // Get the formatted address
        final formattedAddress = data['display_name'];
        
        // Extract more detailed components
        final addressParts = data['address'];
        String? village, district, country;
        
        // Try to extract village or equivalent (most specific)
        village = addressParts['village'] ?? 
                 addressParts['hamlet'] ?? 
                 addressParts['suburb'] ??
                 addressParts['neighbourhood'] ??
                 addressParts['city_district'] ??
                 addressParts['town'] ??
                 addressParts['city'];
                 
        // Try to extract district or equivalent (mid-level admin)
        district = addressParts['county'] ?? 
                  addressParts['district'] ?? 
                  addressParts['state_district'];
                  
        country = addressParts['country'];
        
        // Update state variables
        setState(() {
          _locationAddress = formattedAddress;
          
          // Set village if available
          if (village != null && village.isNotEmpty) {
            _detectedVillage = village;
          }
          
          // Set district if available
          if (district != null && district.isNotEmpty) {
            _detectedDistrict = district;
            
            // Use our Uganda mapping to get the correct region based on district
            if (country == 'Uganda' || _isCoordinateInUganda(lat, lon)) {
              _detectedRegion = UgandaRegionsMapper.getRegionForDistrict(district);
            } else {
              _detectedRegion = addressParts['state'] ?? 
                               addressParts['region'] ?? 
                               'Unknown Region';
            }
          }
          
          // Store coordinates for database
          _latitude = lat;
          _longitude = lon;
        });
        
        print('Address successfully retrieved: $_locationAddress');
        print('Region: $_detectedRegion, District: $_detectedDistrict, Village: $_detectedVillage');
      } else {
        setState(() {
          _locationAddress = "Error retrieving address (HTTP ${response.statusCode})";
          // Keep the default values already set
        });
        print('HTTP error: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    }
  } catch (e) {
    print('Error getting address from OSM: $e');
    print(StackTrace.current); // Print stack trace for debugging
    
    if (_currentPosition != null) {
      setState(() {
        _locationAddress = "Error retrieving address (Coordinates: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)})";
        // Ensure coordinates are still captured even if address lookup fails
        _latitude = _currentPosition!.latitude;
        _longitude = _currentPosition!.longitude;
        // Default values were already set at the beginning
      });
    }
  }
}
// Helper method to determine if coordinates are likely in Uganda
bool _isCoordinateInUganda(double lat, double lon) {
  // Approximate bounding box for Uganda
  const double minLat = -1.5; // Southern border
  const double maxLat = 4.3;  // Northern border
  const double minLon = 29.5; // Western border
  const double maxLon = 35.0; // Eastern border
  
  return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
}
  
  // Evidence and submission data
  List<PlatformFile> _uploadedFiles = [];
  bool _isUploading = false;
  final int _maxFileSizeInMB = 10;
  final int _maxFiles = 5;
  final List<String> _allowedExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', 'avi', 'mp3', 'wav', 'm4a'
  ];
  
  final _witnessInfoController = TextEditingController();
  final _additionalNotesController = TextEditingController();

  // API endpoints
  final String _fileUploadEndpoint = 'https://hkggxkyzyjptapnqbdlc.supabase.co/storage/v1/object/public/incident-files';
  final String _incidentsEndpoint = 'https://hkggxkyzyjptapnqbdlc.supabase.co/rest/v1/incidents';
  final String _authToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhrZ2d4a3l6eWpwdGFwbnFiZGxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE1OTgyNTksImV4cCI6MjA1NzE3NDI1OX0.RSq8Fl40y1PRTl_77UbJWwqbdMIY9mWE7YTH4a-1NsQ';

  // File upload methods
  Future<void> _pickFiles() async {
    try {
      setState(() {
        _isUploading = true;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        allowMultiple: true,
      );

      if (result != null) {
        // Check if adding these files would exceed the limit
        if (_uploadedFiles.length + result.files.length > _maxFiles) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You can upload a maximum of $_maxFiles files'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isUploading = false;
          });
          return;
        }

        // Filter out files that exceed the size limit
        List<PlatformFile> validFiles = [];
        List<String> oversizedFiles = [];

        for (var file in result.files) {
          // Check file size (convert bytes to MB)
          double fileSizeInMB = file.size / (1024 * 1024);
          
          if (fileSizeInMB <= _maxFileSizeInMB) {
            validFiles.add(file);
          } else {
            oversizedFiles.add(file.name);
          }
        }

        // Add valid files to the list
        setState(() {
          _uploadedFiles.addAll(validFiles);
        });

        // Show warning for oversized files
        if (oversizedFiles.isNotEmpty) {
          String fileNames = oversizedFiles.join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Some files exceed the $_maxFileSizeInMB MB limit: $fileNames'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  // Determine the file type icon
  IconData _getFileTypeIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
      return Icons.image;
    } else if (['mp4', 'mov', 'avi'].contains(extension)) {
      return Icons.videocam;
    } else if (['mp3', 'wav', 'm4a'].contains(extension)) {
      return Icons.audio_file;
    }
    
    return Icons.insert_drive_file;
  }

  

  // Get the file type label
  String _getFileTypeLabel(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
      return 'Image';
    } else if (['mp4', 'mov', 'avi'].contains(extension)) {
      return 'Video';
    } else if (['mp3', 'wav', 'm4a'].contains(extension)) {
      return 'Audio';
    }
    
    return 'File';
  }

  // Format the file size
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

Future<String> _uploadFile(PlatformFile file) async {
  try {
    final supabase = Supabase.instance.client;
    final filePath = 'incident-files/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    
    // Use file.bytes directly instead of reading from path
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('File bytes are null');
    }

    await supabase.storage.from('incident-files').uploadBinary(
      filePath,
      bytes,
      fileOptions: FileOptions(
        contentType: _getContentType(file.name),
        upsert: false,
      )
    );

    final publicUrl = supabase.storage.from('incident-files').getPublicUrl(filePath);
    print('File URL: $publicUrl');
    return publicUrl;
  } catch (e) {
    print('Error uploading file: $e');
    throw Exception('Failed to upload file: ${file.name}. Error: $e');
  }
}
  
  // Method to determine content type based on file extension
  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/m4a';
      default:
        return 'application/octet-stream';
    }
  }

  // Build location section (replaced form fields with GPS capture)
  Widget _buildLocationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // GPS location status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _currentPosition != null ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _currentPosition != null ? Colors.green.shade200 : Colors.orange.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _currentPosition != null ? Icons.location_on : Icons.location_off,
                      color: _currentPosition != null ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _currentPosition != null ? 'Location captured' : 'Location not captured',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _currentPosition != null ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_currentPosition != null) ...[
                  Text('Address: $_locationAddress'),
                  const SizedBox(height: 4),
                  Text('Coordinates: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}'),
                ] else ...[
                  const Text('Your location will be automatically captured when you submit the report.'),
                ],
                const SizedBox(height: 12),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _isCapturingLocation ? null : _getCurrentLocation,
                    icon: _isCapturingLocation 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_isCapturingLocation ? 'Capturing...' : _currentPosition != null ? 'Refresh Location' : 'Capture Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          const Text(
            'Additional Location Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _additionalLocationController,
            decoration: InputDecoration(
              hintText: 'Provide any additional details about the location',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 20),
          const Text(
            'Landmark Reference (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _landmarkController,
            decoration: InputDecoration(
              hintText: 'e.g., Near Kabale University',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  // Build file upload section
  Widget _buildFileUploadSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Upload Evidence',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _isUploading ? null : _pickFiles,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: _isUploading ? Colors.grey.shade100 : Colors.white,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isUploading ? Colors.grey : const Color(0xFF003366),
                      shape: BoxShape.circle,
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.cloud_upload,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isUploading
                        ? 'Uploading...'
                        : 'Tap to upload photos, videos, or audio',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Maximum $_maxFiles files, ${_maxFileSizeInMB}MB each',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Supported formats: Images (jpg, png), Videos (mp4, mov), Audio (mp3, wav)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          if (_uploadedFiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _uploadedFiles.length,
              itemBuilder: (context, index) {
                final file = _uploadedFiles[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF003366).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          _getFileTypeIcon(file.name),
                          color: const Color(0xFF003366),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_getFileTypeLabel(file.name)} • ${_formatFileSize(file.size)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _uploadedFiles.removeAt(index);
                          });
                        },
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        padding: EdgeInsets.zero,
                        splashRadius: 24,
                      ),
                    ],
                  ),
                );
              },
            ),
            if (_uploadedFiles.length < _maxFiles) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isUploading ? null : _pickFiles,
                icon: const Icon(Icons.add_circle_outline),
                label: Text('Add more files (${_uploadedFiles.length}/$_maxFiles)'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF003366),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

void _submitReport() async {
  if (_formKey.currentState!.validate()) {
    // Check if location is captured, if not, capture it now
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capturing your location...'), duration: Duration(seconds: 2)),
      );
      
      await _getCurrentLocation();
      
      // If still no location, ask the user if they want to continue
      if (_currentPosition == null) {
        bool continueWithoutLocation = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Not Available'),
            content: const Text('We couldn\'t capture your location. Do you want to continue submitting the report without location data?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ?? false;
        
        if (!continueWithoutLocation) {
          return;
        }
      }
    }
    
    // Show loading indicator
    setState(() {
      _isUploading = true;
    });
    
    try {
      // 1. Upload files to server and get URLs
      List<String> fileUrls = [];
      
      if (_uploadedFiles.isNotEmpty) {
        // Show uploading files progress
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading files...'),
            duration: Duration(seconds: 3),
          ),
        );
        
        for (var file in _uploadedFiles) {
          print('Uploading file: ${file.name} (${_formatFileSize(file.size)})');
          String fileUrl = await _uploadFile(file);
          
          // Check if file upload failed
          if (fileUrl.startsWith('ERROR:')) {
            throw Exception('Failed to upload file: ${file.name}');
          }
          
          fileUrls.add(fileUrl);
          print('Successfully uploaded: ${file.name} to $fileUrl');
        }
      }
        
      // 2. Create incident data object
      final user = Supabase.instance.client.auth.currentUser; // Get current user
      String? userId = user?.id;

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in'), backgroundColor: Colors.red)
        );
        return;
      }
      
      // Fix for the non-final field promotion error in incident_report_form.dart
      // If we have a district but not a correctly mapped region, use our mapper
      String? districtName = _detectedDistrict;
      if (districtName != null && 
          districtName != 'Unknown District' &&
          (_detectedRegion == null || 
          _detectedRegion == 'Unknown Region')) {
        
        // Try to get the correct region from our mapper
        String mappedRegion = UgandaRegionsMapper.getRegionForDistrict(districtName);
        if (mappedRegion != 'Unknown Region') {
          _detectedRegion = mappedRegion;
        }
      }

      // Also update the Kabale special case:
      if (districtName == 'Kabale' || 
          _detectedVillage == 'Ndorwa' || 
          _detectedVillage == 'Hamurwa') {
        _detectedRegion = 'Western Region';
      }

      // Map village to district if district is unknown
      String? villageName = _detectedVillage;
      if ((districtName == null || districtName == 'Unknown District') && 
          villageName != null && villageName != 'Unknown Village') {
        String mappedDistrict = UgandaRegionsMapper.getDistrictForVillage(villageName);
        if (mappedDistrict != 'Unknown District') {
          _detectedDistrict = mappedDistrict;
          
          // Now that we have a district, also ensure we have the right region
          String mappedRegion = UgandaRegionsMapper.getRegionForDistrict(mappedDistrict);
          if (mappedRegion != 'Unknown Region') {
            _detectedRegion = mappedRegion;
          }
        }
      }
      
      // Create incident data object that matches the database schema
      // Make sure all required fields have default values if they're null
      Map<String, dynamic> incidentData = {
        'user_id': userId,
        'title': '${_selectedIncidentType ?? "Incident"} Report',
        'description': _descriptionController.text,
        'incident_type': _selectedIncidentType,
        
        // Location data with proper region mapping
        'region': _detectedRegion ?? "Unknown Region",
        'district': _detectedDistrict ?? "Unknown District",
        'village': _detectedVillage ?? "Unknown Village",
        'latitude': _latitude,
        'longitude': _longitude,
        
        // System fields
        'status': 'submitted',
        'is_anonymous': false, // Default value based on schema
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        
        // Additional fields
        'additional_location': _additionalLocationController.text,
        'additional_notes': _additionalNotesController.text,
        'landmark': _landmarkController.text,
        'file_urls': fileUrls,
        'incident_date': _selectedDate != null ? _selectedDate!.toIso8601String() : null,
        'incident_time': _selectedTime != null ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}' : null,
        'witness_info': _witnessInfoController.text,
      };
      
      // Print incident data for debugging
      print('Sending incident data with location: ${json.encode(incidentData)}');
      
      // 3. Submit the incident data to the API
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saving incident report...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      final response = await http.post(
        Uri.parse(_incidentsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _authToken,
          'Authorization': 'Bearer $_authToken',
          'Prefer': 'return=minimal'
        },
        body: json.encode(incidentData),
      );
      
      // Log the complete response for debugging
      print('Database response status: ${response.statusCode}');
      print('Database response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Add a slight delay to ensure the snackbar is visible
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Navigate to user dashboard
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/user-dashboard', // Use the correct route path
          (route) => false,
        );
        
        // Show persistent success message on dashboard
        Future.delayed(const Duration(milliseconds: 300), () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your safety report has been submitted successfully. Thank you for contributing to community safety.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
        });
      } else {
        throw Exception('Failed to save incident to database. Status: ${response.statusCode}, Response: ${response.body}');
      }
    } catch (e) {
      print('Error submitting report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting report: ${e.toString().length > 100 ? '${e.toString().substring(0, 100)}...' : e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'RETRY',
            onPressed: _submitReport,
          ),
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
}
@override
Widget build(BuildContext context) {
  final screenSize = MediaQuery.of(context).size;
  
  return Scaffold(
    backgroundColor: Colors.grey[100],
    appBar: AppBar(
      title: const Text(
        'Submit Safety Report',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: const Color(0xFF003366),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (_currentStep > 0) {
            _previousStep();
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: _buildStepIndicator(),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentStep == 0) ...[
                      // Incident Details Step
                      const Text(
                        'Incident Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 16),
                              border: InputBorder.none,
                            ),
                            hint: const Text('Select incident type'),
                            value: _selectedIncidentType,
                            onChanged: (value) {
                              setState(() {
                                _selectedIncidentType = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select an incident type';
                              }
                              return null;
                            },
                            items: [
                              'Robbery',
                              'Theft',
                              'Rape',
                              'Defilement',
                              'Sexual Assault',
                              'Demestic Violence',
                              'Murder',
                              'Manslaughter',
                              'Drug Abuse',
                              'Kidnap',
                              'Child Labour',
                              'Cyber Crime',
                              'Fraud and financial crimes',
                              'Accident',
                              'Fire outbreak',
                              'Other'
                            ].map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: 'Provide detailed description of the incident',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Date',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => _selectDate(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          _selectedDate == null 
                                              ? 'Select date' 
                                              : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                          style: TextStyle(
                                            color: _selectedDate == null ? Colors.grey.shade600 : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Time',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => _selectTime(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          _selectedTime == null 
                                              ? 'Select time' 
                                              : _selectedTime!.format(context),
                                          style: TextStyle(
                                            color: _selectedTime == null ? Colors.grey.shade600 : Colors.black,
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
                    ],
                    
                    if (_currentStep == 1) ...[
                      // GPS-Based Location Section
                      _buildLocationSection(),
                    ],
                    
                    if (_currentStep == 2) ...[
                      // Evidence & Submission Step
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFileUploadSection(),
                          
                          const SizedBox(height: 20),
                          
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Additional Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Witness Information (Optional)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _witnessInfoController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter contact details of any witnesses',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                const Text(
                                  'Additional Notes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _additionalNotesController,
                                  decoration: InputDecoration(
                                    hintText: 'Any other relevant information about the incident',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Review Your Report',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Incident Type:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        _selectedIncidentType ?? 'Not specified',
                                        style: const TextStyle(
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Location:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Icon(
                                            _currentPosition != null ? Icons.check_circle : Icons.info,
                                            size: 16,
                                            color: _currentPosition != null ? Colors.green : Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _currentPosition != null 
                                                  ? _locationAddress 
                                                  : 'Will be captured at submission',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: _currentPosition != null ? Colors.black : Colors.orange.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Date & Time:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        _selectedDate != null && _selectedTime != null
                                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} ${_selectedTime!.format(context)}'
                                            : 'Not specified',
                                        style: const TextStyle(
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    // Save as draft functionality
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Report saved as draft')),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: const BorderSide(color: Colors.grey),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Save as Draft',
                                    style: TextStyle(
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    if (_currentStep < 2)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _currentStep == 0 
                                ? () => Navigator.of(context).pop() 
                                : _previousStep,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                                side: const BorderSide(color: Color(0xFF003366)),
                              ),
                            ),
                            child: Text(
                              _currentStep == 0 ? 'Cancel' : 'Back',
                              style: const TextStyle(
                                color: Color(0xFF003366),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              // Validate current step and proceed if valid
                              _nextStep();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF003366),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Next',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    
                    if (_currentStep == 2)
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: _isUploading ? null : _submitReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF003366),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Submit Report',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _previousStep,
                            child: const Text(
                              'Back',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
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
        ),
      ),
    ),
    bottomSheet: Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      color: Colors.white,
      width: double.infinity,
      child: const Text(
        'All information submitted will be handled confidentially in accordance with privacy regulations.',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}
      }
    
    