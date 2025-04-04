// Create a new file: lib/service/access_control_service.dart

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
          .from('admin_tb')
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
          .from('admin_tb')
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
          .from('admin_tb')
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
      final response = await supabase
          .from('incidents')
          .select('station_id')
          .eq('id', incidentId)
          .single();
      
      if (response != null) {
        final incidentStationId = response['station_id'] as String?;
        return incidentStationId == stationId;
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