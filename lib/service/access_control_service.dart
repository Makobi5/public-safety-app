// lib/service/access_control_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class AccessControlService {
  // Singleton instance
  static final AccessControlService _instance = AccessControlService._internal();
  
  // Factory constructor
  factory AccessControlService() => _instance;
  
  // Internal constructor
  AccessControlService._internal();
  
  // Cache to improve performance
  bool? _isAdmin;
  bool? _isCentralAdmin;
  String? _userStationId;
  String? _stationName;
  
  // Check if user is an admin (any police station)
  Future<bool> isUserAdmin() async {
    // Return cached value if available
    if (_isAdmin != null) return _isAdmin!;
    
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) return false;
      
      // Check if user exists in admins table
      final response = await supabase
          .from('admins')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();
      
      _isAdmin = response != null;
      print('User is admin: $_isAdmin');
      return _isAdmin!;
    } catch (e) {
      print('Error checking if user is admin: $e');
      return false;
    }
  }
  
  // Check if user is central admin (Kabale Central Police Station)
  Future<bool> isUserCentralAdmin() async {
    // Return cached value if available
    if (_isCentralAdmin != null) return _isCentralAdmin!;
    
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) return false;
      
      // Step 1: Find the admin record
      final adminResponse = await supabase
          .from('admins')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();
          
      print('Admin DB response: $adminResponse');
      
      if (adminResponse == null) {
        _isCentralAdmin = false;
        return false;
      }
      
      // Step 2: Find the station assignment
      final adminId = adminResponse['id'];
      final assignmentResponse = await supabase
          .from('admin_station_assignments')
          .select('station_id')
          .eq('admin_id', adminId)
          .maybeSingle();
          
      print('Assignment DB response: $assignmentResponse');
      
      if (assignmentResponse == null || assignmentResponse['station_id'] == null) {
        _isCentralAdmin = false;
        return false;
      }
      
      // Step 3: Find the station name
      final stationId = assignmentResponse['station_id'];
      final stationResponse = await supabase
          .from('police_stations')
          .select('name')
          .eq('id', stationId)
          .maybeSingle();
          
      print('Station DB response: $stationResponse');
      
      if (stationResponse == null) {
        _isCentralAdmin = false;
        return false;
      }
      
      // Check if this is Kabale Central Police Station
      final stationName = stationResponse['name'] as String?;
      _isCentralAdmin = stationName == 'Kabale Central Police Station';
      print('User is central admin: $_isCentralAdmin');
      return _isCentralAdmin!;
    } catch (e) {
      print('Error checking if user is central admin: $e');
      _isCentralAdmin = false;
      return false;
    }
  }
  
  // Get user's assigned station ID
  Future<String?> getUserStationId() async {
    // Return cached value if available
    if (_userStationId != null) return _userStationId;
    
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) return null;
      
      // Step 1: Find the admin record
      final adminResponse = await supabase
          .from('admins')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();
          
      if (adminResponse == null) return null;
      
      // Step 2: Find the station assignment
      final adminId = adminResponse['id'];
      final assignmentResponse = await supabase
          .from('admin_station_assignments')
          .select('station_id')
          .eq('admin_id', adminId)
          .maybeSingle();
          
      if (assignmentResponse == null) return null;
      
      _userStationId = assignmentResponse['station_id'] as String?;
      return _userStationId;
    } catch (e) {
      print('Error getting user station ID: $e');
      return null;
    }
  }
  
  // Get user's police station name
  Future<String?> getUserStationName() async {
    // Return cached value if available
    if (_stationName != null) return _stationName;
    
    try {
      final supabase = Supabase.instance.client;
      
      // First get the station ID
      final stationId = await getUserStationId();
      if (stationId == null) return null;
      
      // Then get the station name
      final stationResponse = await supabase
          .from('police_stations')
          .select('name')
          .eq('id', stationId)
          .maybeSingle();
          
      if (stationResponse != null) {
        _stationName = stationResponse['name'] as String?;
        return _stationName;
      }
      
      return null;
    } catch (e) {
      print('Error getting user station name: $e');
      return null;
    }
  }
  
  // Check if user has access to a specific incident
  Future<bool> canAccessIncident(String incidentId) async {
    try {
      // Debug output to help with troubleshooting
      print('Checking access for incident: $incidentId');
      
      // First check if the user is an admin - ALL admins can access ALL cases
      final admin = await isUserAdmin();
      if (admin) {
        print('Access granted: User is an admin');
        return true;
      }
      
      // For non-admins, check if this is the user's own report
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        print('Access denied: No authenticated user');
        return false;
      }
      
      final incidentResponse = await supabase
          .from('incidents')
          .select('user_id')
          .eq('id', incidentId)
          .maybeSingle();
      
      if (incidentResponse != null && user.id == incidentResponse['user_id']) {
        print('Access granted: User owns this report');
        return true;
      }
      
      print('Access denied: User is not admin and does not own this report');
      return false;
    } catch (e) {
      print('Error checking incident access: $e');
      return false;
    }
  }
  
  // Clear cache (useful for logout)
  void clearCache() {
    _isAdmin = null;
    _isCentralAdmin = null;
    _userStationId = null;
    _stationName = null;
  }
}