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
  bool? _isCentralAdmin;
  String? _userStationId;
  String? _stationName;
  
  // Check if user is central admin (Kabale Central Police Station)
  Future<bool> isUserCentralAdmin() async {
    // Return cached value if available
    if (_isCentralAdmin != null) return _isCentralAdmin!;
    
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) return false;
      
      final response = await supabase
          .from('admins')
          .select('police_station_name')
          .eq('user_id', user.id)
          .single();
      
      if (response != null) {
        final stationName = response['police_station_name'] as String?;
        _isCentralAdmin = stationName == 'Kabale Central Police Station';
        return _isCentralAdmin!;
      }
      
      return false;
    } catch (e) {
      print('Error checking if user is central admin: $e');
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
      
      final response = await supabase
          .from('admins')
          .select('station_id')
          .eq('user_id', user.id)
          .single();
      
      if (response != null) {
        _userStationId = response['station_id'] as String?;
        return _userStationId;
      }
      
      return null;
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
      final user = supabase.auth.currentUser;
      
      if (user == null) return null;
      
      final response = await supabase
          .from('admins')
          .select('police_station_name')
          .eq('user_id', user.id)
          .single();
      
      if (response != null) {
        _stationName = response['police_station_name'] as String?;
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
      // Central admin can access all incidents
      final isCentralAdmin = await isUserCentralAdmin();
      if (isCentralAdmin) return true;
      
      // Get the user's station ID
      final stationId = await getUserStationId();
      if (stationId == null) return false;
      
      // Check if the incident belongs to the user's station
      final supabase = Supabase.instance.client;
      
      // Check both reported_station_id and station_id fields
      final incidentResponse = await supabase
          .from('incidents')
          .select('station_id, police_station_id, reported_station_id')
          .eq('id', incidentId)
          .single();
      
      if (incidentResponse != null) {
        // Try all possible station ID field names
        final incidentStationId = incidentResponse['station_id'] as String?;
        final incidentPoliceStationId = incidentResponse['police_station_id'] as String?;
        final incidentReportedStationId = incidentResponse['reported_station_id'] as String?;
        
        // Debug output to help identify the correct field name
        print('Incident ID: $incidentId');
        print('User station ID: $stationId');
        print('Incident station_id: $incidentStationId');
        print('Incident police_station_id: $incidentPoliceStationId');
        print('Incident reported_station_id: $incidentReportedStationId');
        
        // Check all possible matches
        return stationId == incidentStationId || 
               stationId == incidentPoliceStationId || 
               stationId == incidentReportedStationId;
      }
      
      return false;
    } catch (e) {
      print('Error checking incident access: $e');
      return false;
    }
  }
  
  // Clear cache (useful for logout)
  void clearCache() {
    _isCentralAdmin = null;
    _userStationId = null;
    _stationName = null;
  }
}