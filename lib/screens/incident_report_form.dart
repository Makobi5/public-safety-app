// Updated incident_report_form.dart with GPS location
import 'dart:math';
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
import 'package:google_maps_webservice/geocoding.dart';
import 'package:google_maps_webservice/places.dart';
import '/config/api_keys.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/geocoding.dart' as gmaps;

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
  bool _isLoadingStations = false;
  List<Map<String, dynamic>> _policeStations = [];
  String? _selectedPoliceStationId;
  String? _selectedPoliceStationName;
  
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
Future<void> _fetchPoliceStations(String districtName) async {
  setState(() => _isLoadingStations = true);
  
  try {
    final supabase = Supabase.instance.client;
    
    // 1. Get district with location data
    final districtResponse = await supabase
      .from('districts')
      .select('id, lat, lon')
      .eq('name', districtName)
      .maybeSingle();

    if (districtResponse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$districtName district data not found')),
      );
      return;
    }

    // 2. Get all police stations in this district
    final stationsResponse = await supabase
      .from('police_stations')
      .select('id, name, address, lat, lon, coverage_status')
      .eq('district_id', districtResponse['id']);

    // 3. Process stations data
    final stations = (stationsResponse as List).map((station) => {
      'id': station['id'],
      'name': station['name'] ?? 'Unknown Station',
      'address': station['address'] ?? 'Address not available',
      'lat': station['lat'],
      'lon': station['lon'],
      'coverage_status': station['coverage_status'] ?? 0.0,
    }).toList();

    // 4. Calculate distances if we have location data
    if (_latitude != null && _longitude != null) {
      for (final station in stations) {
        if (station['lat'] != null && station['lon'] != null) {
          station['distance'] = _calculateDistance(
            _latitude!,
            _longitude!,
            station['lat'],
            station['lon']
          );
        }
      }
      // Sort by distance if available
      stations.sort((a, b) => (a['distance'] ?? double.infinity)
          .compareTo(b['distance'] ?? double.infinity));
    }

    setState(() {
      _policeStations = stations;
      if (stations.isNotEmpty) {
        _selectedPoliceStationId = stations[0]['id'];
        _selectedPoliceStationName = stations[0]['name'];
      }
    });

  } catch (e) {
    debugPrint('Police station fetch error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error loading stations: ${e.toString().split(':').first}'),
        duration: const Duration(seconds: 3),
      ),
    );
  } finally {
    setState(() => _isLoadingStations = false);
  }
}

// Haversine distance calculation method
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371; // Earth radius in km
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _toRadians(double degree) {
  return degree * pi / 180;
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

// Future<void> _getCurrentLocation() async {
//   setState(() => _isCapturingLocation = true);
  
//   try {
//     Position position = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.bestForNavigation,
//     );
    
//     print('Raw Coordinates: ${position.latitude},${position.longitude}');
    
//     setState(() {
//       _currentPosition = position;
//       _latitude = position.latitude;
//       _longitude = position.longitude;
//     });

//     // First try OSM
//     await _getAddressFromOSM();
    
//     // If still not Kabale, try our local mapping
//     if (!_locationAddress.toLowerCase().contains('kabale')) {
//       _applyUgandaSpecificMapping();
//     }
    
//   } catch (e) {
//     debugPrint('Location error: $e');
//   } finally {
//     setState(() => _isCapturingLocation = false);
//   }
// }
// In _IncidentReportFormPageState class
Future<void> _getCurrentLocation() async {
  // Check location permissions first
  bool hasPermission = await _handleLocationPermission();
  if (!hasPermission) {
    // If no permission, exit early
    return;
  }
  
  setState(() => _isCapturingLocation = true);
  
  try {
    // Make sure to use a reasonable timeout
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: const Duration(seconds: 10)
    );
    setState(() {
      _currentPosition = position;  // Make sure to set this
      _latitude = position.latitude;
      _longitude = position.longitude;
    });

    // Now get the address
    await _getAddressFromGoogleMaps();
    
    // After location is set, fetch police stations for the district
    if (_detectedDistrict != null) {
      await _fetchPoliceStations(_detectedDistrict!);
    }
    
  } catch (e) {
    print('Location error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error capturing location: ${e.toString()}')),
    );
    // Fallback to local mapping
    _applyUgandaSpecificMapping();
  } finally {
    setState(() => _isCapturingLocation = false);
  }
}

void _applyUgandaSpecificMapping() {
  if (_latitude == null || _longitude == null) return;

  setState(() {
    // First check if we're in Kabale area
    if (_latitude! >= -1.35 && _latitude! <= -1.0 && 
        _longitude! >= 29.9 && _longitude! <= 30.3) {
      _detectedRegion = 'Western Region';
      _detectedDistrict = 'Kabale';
      _detectedVillage = _detectedVillage ?? 'Kabale Area';
      _locationAddress = 'Kabale Area, Kabale, Western Region';
      return;
    }

    // Default mapping for other areas
    _detectedRegion = UgandaRegionsMapper.getRegionForCoordinates(
      _latitude!, _longitude!);
    _detectedDistrict = UgandaRegionsMapper.getDistrictForCoordinates(
      _latitude!, _longitude!);
    
    // Update village if not set
    if (_detectedVillage == null || _detectedVillage == 'Unknown Village') {
      _detectedVillage = _detectedDistrict == 'Kabale' 
          ? 'Kabale Area' 
          : 'Unknown Village';
    }
    
    _locationAddress = '$_detectedVillage, $_detectedDistrict, $_detectedRegion';
  });
}

// Future<void> _getAddressFromOSM() async {
//   try {
//     if (_currentPosition != null) {
//       final lat = _currentPosition!.latitude;
//       final lon = _currentPosition!.longitude;

//       // First check Kampala coordinates
//       if (lat >= 0.25 && lat <= 0.4 && lon >= 32.5 && lon <= 32.7) {
//         final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1';
//         final response = await http.get(Uri.parse(url));
        
//         if (response.statusCode == 200) {
//           final data = json.decode(response.body);
//           final addressParts = data['address'] ?? {}; // Properly define addressParts here

//           setState(() {
//             _detectedRegion = 'Central Region';
//             _detectedDistrict = 'Kampala';
//             _detectedVillage = addressParts['neighbourhood'] ?? 'Kampala';
//             _locationAddress = '${_detectedVillage}, Kampala, Central Region';
//             _latitude = lat;
//             _longitude = lon;
//           });
//         }
//         return;
//       }

//       // Rest of your OSM lookup logic...
//     }
//   } catch (e) {
//     // Error handling
//   }
// }

Future<void> _getAddressFromGoogleMaps() async {
  // Guard clause - exit if we don't have coordinates
  if (_latitude == null || _longitude == null) {
    debugPrint('Cannot get address: coordinates are null');
    return;
  }
  
  try {
    debugPrint('Getting address for coordinates: $_latitude, $_longitude');
    
    // 1. Initialize Geocoding with the API key
    final geocoding = GoogleMapsGeocoding(apiKey: ApiKeys.googleMapsApiKey);
    
    // 2. Make API call with proper location object
    final response = await geocoding.searchByLocation(
      gmaps.Location(lat: _latitude!, lng: _longitude!),
      language: 'en', // explicitly set language
      locationType: ['ROOFTOP'], // try to get the most precise result
    );

    // 3. Check if response is successful and has results
    if (response.isOkay && response.results.isNotEmpty) {
      final result = response.results.first;
      final addressComponents = result.addressComponents;
      
      debugPrint('Google Maps returned address: ${result.formattedAddress}');

      // 4. Extract components in a structured way
      String? district, region, village, country, streetName;
      
      for (var component in addressComponents) {
        // Log each component to help with debugging
        debugPrint('Address component: ${component.longName} - Types: ${component.types.join(', ')}');
        
        if (component.types.contains('administrative_area_level_2')) {
          district = component.longName;
        } else if (component.types.contains('administrative_area_level_1')) {
          region = component.longName;
        } else if (component.types.contains('locality')) {
          village = component.longName;
        } else if (component.types.contains('sublocality') && village == null) {
          // Fallback for village if locality not found
          village = component.longName;
        } else if (component.types.contains('country')) {
          country = component.longName;
        } else if (component.types.contains('route')) {
          streetName = component.longName;
        }
      }

      // Check if we're in Uganda (or fallback to coordinates)
      bool isLikelyInUganda = country?.toLowerCase() == 'uganda' || 
                             _isCoordinateInUganda(_latitude!, _longitude!);

      // 5. Update state with the geocoded information
      setState(() {
        _detectedRegion = region ?? 'Unknown Region';
        _detectedDistrict = district ?? 'Unknown District';
        _detectedVillage = village ?? 'Unknown Village';
        
        // Use street name in address if available
        if (streetName != null) {
          _locationAddress = result.formattedAddress ?? 
                           '$streetName, $_detectedVillage, $_detectedDistrict, $_detectedRegion';
        } else {
          _locationAddress = result.formattedAddress ?? 
                           '$_detectedVillage, $_detectedDistrict, $_detectedRegion';
        }
        
        // If we have reason to believe we're in Kabale, force Western Region
        if (_detectedDistrict == 'Kabale' || 
            _detectedVillage == 'Kabale' ||
            (_isCoordinateInKabaleArea(_latitude!, _longitude!))) {
          _detectedRegion = 'Western Region';
          _locationAddress = 'Kabale Area, Kabale, Western Region';
        }
        
        // If not in Uganda, use our Uganda-specific mapping as fallback
        if (!isLikelyInUganda) {
          _applyUgandaSpecificMapping();
        }
      });
      
      debugPrint('Final detected location: $_locationAddress');
      
    } else {
      // Handle empty results
      debugPrint('Google Maps returned no results or error: ${response.status}');
      _applyUgandaSpecificMapping();
    }
  } catch (e) {
    debugPrint('Geocoding error: $e');
    
    // Show error to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error getting location details. Using approximate location.'),
        duration: Duration(seconds: 3),
      ),
    );
    
    // Fallback to our custom mapping logic
    _applyUgandaSpecificMapping();
  }
}

// Helper method to determine if coordinates are in Kabale area
bool _isCoordinateInKabaleArea(double lat, double lon) {
  // Approximate bounding box for Kabale area
  const double minLat = -1.35; 
  const double maxLat = -1.0;
  const double minLon = 29.9;
  const double maxLon = 30.3;
  
  return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
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

// Update your _buildLocationSection method to include police station selection
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
        
        // Location Capture Card
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
                Text('Coordinates: ${_latitude?.toStringAsFixed(6)}, ${_longitude?.toStringAsFixed(6)}'),
              ] else ...[
                const Text('Please capture your location to see nearby police stations'),
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
                  label: Text(_isCapturingLocation ? 'Capturing...' : 'Capture Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Police Station Selection (only shown after location is captured)
        if (_currentPosition != null) ...[
          const SizedBox(height: 20),
          const Text(
            'Forward to Police Station',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _isLoadingStations
              ? const Center(child: CircularProgressIndicator())
              : _policeStations.isEmpty
                  ? const Text('No police stations found in this district')
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedPoliceStationId,
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedPoliceStationId = newValue;
                              _selectedPoliceStationName = _policeStations
                                  .firstWhere((station) => station['id'] == newValue)['name'];
                            });
                          },
                          items: _policeStations.map<DropdownMenuItem<String>>((station) {
                            return DropdownMenuItem<String>(
                              value: station['id'],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(station['name'],
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('${station['address']}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  if (station['distance'] != null)
                                    Text('${station['distance'].toStringAsFixed(1)} km away',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ],
        
        // Additional Location Details
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

        // Landmark Reference
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
  if (!_formKey.currentState!.validate()) return;

  // Check if location is captured
  if (_currentPosition == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Capturing your location...'),
        duration: Duration(seconds: 2),
      ),
    );
    
    await _getCurrentLocation();
    
    if (_currentPosition == null) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Location Not Available'),
          content: const Text('Some features require location. Continue without?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ?? false;
      
      if (!shouldContinue) return;
    }
  }
  
  setState(() => _isUploading = true);
  
  try {
    // 1. Upload files
    final fileUrls = await _uploadFiles();
    
    // 2. Prepare incident data
    final incidentData = await _prepareIncidentData(fileUrls);
    
    // 3. Submit to database - Updated Supabase syntax
    final response = await Supabase.instance.client
        .from('incidents')
        .insert(incidentData);

    // 4. Check for errors
    if (response.error != null) {
      throw Exception(response.error!.message);
    }

    // 5. Handle success
    _handleSubmissionSuccess();
    
  } catch (e) {
    // Handle errors
    if (e.toString().contains('NoSuchMethodError') && 
        e.toString().contains('error')) {
      // False positive case - submission actually worked
      _handleSubmissionSuccess();
    } else {
      _handleSubmissionError(e is Exception ? e : Exception(e.toString()));
    }
  } finally {
    if (mounted) {
      setState(() => _isUploading = false);
    }
  }
}
Future<List<String>> _uploadFiles() async {
  final fileUrls = <String>[];
  if (_uploadedFiles.isEmpty) return fileUrls;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Uploading files...')),
  );

  for (final file in _uploadedFiles) {
    debugPrint('Uploading: ${file.name} (${_formatFileSize(file.size)})');
    final fileUrl = await _uploadFile(file);
    if (fileUrl.startsWith('ERROR')) throw Exception('File upload failed');
    fileUrls.add(fileUrl);
  }
  return fileUrls;
}

Future<Map<String, dynamic>> _prepareIncidentData(List<String> fileUrls) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw Exception('User not logged in');

  // Ensure proper region mapping
  _resolveRegionAndDistrict();

  return {
    'user_id': user.id,
    'title': '${_selectedIncidentType ?? "Incident"} Report',
    'description': _descriptionController.text,
    'incident_type': _selectedIncidentType,
    'region': _detectedRegion ?? "Unknown Region",
    'district': _detectedDistrict ?? "Unknown District",
    'village': _detectedVillage ?? "Unknown Village",
    'latitude': _latitude,
    'longitude': _longitude,
    'status': _selectedPoliceStationId != null ? 'assigned' : 'submitted',
    'is_anonymous': false,
    'additional_location': _additionalLocationController.text,
    'additional_notes': _additionalNotesController.text,
    'landmark': _landmarkController.text,
    'file_urls': fileUrls,
    'incident_date': _selectedDate?.toIso8601String(),
    'incident_time': _selectedTime?.format(context),
    'witness_info': _witnessInfoController.text,
    if (_selectedPoliceStationId != null) ...{
      'police_station_id': _selectedPoliceStationId,
      'police_station_name': _selectedPoliceStationName,
    }
  };
}

void _resolveRegionAndDistrict() {
  final districtName = _detectedDistrict;
  if (districtName != null && districtName != 'Unknown District') {
    if (_detectedRegion == null || _detectedRegion == 'Unknown Region') {
      _detectedRegion = UgandaRegionsMapper.getRegionForDistrict(districtName);
    }
    
    // Special case for Kabale
    if (districtName == 'Kabale' || 
        ['Ndorwa', 'Hamurwa'].contains(_detectedVillage)) {
      _detectedRegion = 'Western Region';
    }
  }

  final villageName = _detectedVillage;
  if ((districtName == null || districtName == 'Unknown District') && 
      villageName != null && villageName != 'Unknown Village') {
    final mappedDistrict = UgandaRegionsMapper.getDistrictForVillage(villageName);
    if (mappedDistrict != 'Unknown District') {
      _detectedDistrict = mappedDistrict;
      _detectedRegion = UgandaRegionsMapper.getRegionForDistrict(mappedDistrict);
    }
  }
}

void _handleSubmissionSuccess() {
  final message = _selectedPoliceStationId != null
      ? 'Report submitted to $_selectedPoliceStationName'
      : 'Report submitted successfully';

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );

  // Add slight delay to ensure smooth transition
  Future.delayed(const Duration(milliseconds: 500), () {
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/user-dashboard',
        (route) => false,
      );
    }
  });
}

void _handleSubmissionError(Exception error) {
  debugPrint('Submission error: ${error.toString()}');
  
  // Check if error is about response format rather than actual failure
  if (error.toString().contains('NoSuchMethodError') && 
      error.toString().contains('error')) {
    // This is likely a false positive - submission actually worked
    _handleSubmissionSuccess();
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Submission status: ${error.toString().split(':').first}'),
      backgroundColor: Colors.orange, // Yellow for warnings
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Retry',
        onPressed: _submitReport,
      ),
    ),
  );
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

      
    
    